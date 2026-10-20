-- =====================================================================
-- Poker Ledger: database additions
--
-- Run this once in the Supabase dashboard (SQL Editor). It is safe to re-run.
--
-- Assumptions about your existing tables (adjust the types below if wrong):
--   players.id and games.id are bigint, games.date is a date.
--
-- BEFORE RUNNING: replace you@example.com in section 3 with the email
-- address(es) of the people who may enter data.
-- =====================================================================


-- 1. One buy-in row and one winners row per player per game -------------
create unique index if not exists buy_ins_player_game_key
  on public.buy_ins (player_id, game_id);
create unique index if not exists winners_player_game_key
  on public.winners (player_id, game_id);


-- 2. Payments ledger: one row per real-world transfer --------------------
-- Not tied to a game, so you can settle a single game or a running balance.
create table if not exists public.payments (
  id           bigint generated always as identity primary key,
  from_player  bigint not null references public.players (id),
  to_player    bigint not null references public.players (id),
  amount       numeric(10, 2) not null check (amount > 0),
  paid_at      date not null default current_date,
  notes        text,
  created_at   timestamptz not null default now(),
  constraint payments_different_players check (from_player <> to_player)
);

create index if not exists payments_from_player_idx on public.payments (from_player);
create index if not exists payments_to_player_idx   on public.payments (to_player);


-- 3. Who is allowed to write -------------------------------------------
-- Anyone can request a sign-in link, so being logged in is not enough.
-- Only emails listed here can add or change data. Keep them lowercase.
create table if not exists public.editors (
  email text primary key check (email = lower(email))
);

insert into public.editors (email) values ('you@example.com')
on conflict do nothing;

create or replace function public.is_editor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.editors e
    where e.email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function public.is_editor() from public;
grant execute on function public.is_editor() to anon, authenticated;


-- 4. Views --------------------------------------------------------------
-- security_invoker makes the views respect the row level security below.

-- One row per player per game they were in.
--   total_buy_in = number_of_buyins * the game's default_buy_in
--   net          = winnings (gross payout) - total_buy_in
create or replace view public.game_results
with (security_invoker = true) as
select
  g.id                                   as game_id,
  g.date                                 as game_date,
  p.id                                   as player_id,
  p.name                                 as player_name,
  coalesce(b.number_of_buyins, 0)        as buy_ins,
  coalesce(b.number_of_buyins, 0) * g.default_buy_in as total_buy_in,
  coalesce(w.amount, 0)                  as winnings,
  coalesce(w.amount, 0) - coalesce(b.number_of_buyins, 0) * g.default_buy_in as net
from public.games g
join (
  select player_id, game_id from public.buy_ins
  union
  select player_id, game_id from public.winners
) gp on gp.game_id = g.id
join public.players p on p.id = gp.player_id
left join public.buy_ins b on b.game_id = g.id and b.player_id = p.id
left join public.winners w on w.game_id = g.id and w.player_id = p.id;


-- One row per game: does the money paid out match the money put in?
create or replace view public.game_checks
with (security_invoker = true) as
select
  g.id                                              as game_id,
  g.date                                            as game_date,
  g.default_buy_in                                  as default_buy_in,
  count(r.player_id)                                as players,
  coalesce(sum(r.buy_ins), 0)                       as total_buy_ins,
  coalesce(sum(r.total_buy_in), 0)                  as pot,
  coalesce(sum(r.winnings), 0)                      as paid_out,
  coalesce(sum(r.winnings), 0) - coalesce(sum(r.total_buy_in), 0) as difference,
  coalesce(sum(r.winnings), 0) = coalesce(sum(r.total_buy_in), 0) as balanced
from public.games g
left join public.game_results r on r.game_id = g.id
group by g.id, g.date, g.default_buy_in;


-- What each player still owes or is owed.
--   balance > 0  the player is owed money
--   balance < 0  the player owes money
--   balance = 0  settled
-- balance = all game results + payments they sent - payments they received
create or replace view public.player_balances
with (security_invoker = true) as
select
  p.id                                  as player_id,
  p.name                                as player_name,
  coalesce(r.net, 0)                    as net_results,
  coalesce(s.total, 0)                  as payments_sent,
  coalesce(rc.total, 0)                 as payments_received,
  coalesce(r.net, 0) + coalesce(s.total, 0) - coalesce(rc.total, 0) as balance
from public.players p
left join (
  select player_id, sum(net) as net from public.game_results group by player_id
) r on r.player_id = p.id
left join (
  select from_player, sum(amount) as total from public.payments group by from_player
) s on s.from_player = p.id
left join (
  select to_player, sum(amount) as total from public.payments group by to_player
) rc on rc.to_player = p.id;


-- Lifetime statistics per player. A "win" is a night finished in profit.
create or replace view public.player_stats
with (security_invoker = true) as
select
  p.id                                                  as player_id,
  p.name                                                as player_name,
  count(r.game_id)                                      as games_played,
  coalesce(sum(r.buy_ins), 0)                           as total_buy_ins,
  coalesce(sum(r.total_buy_in), 0)                      as total_staked,
  coalesce(sum(r.winnings), 0)                          as total_winnings,
  coalesce(sum(r.net), 0)                               as net,
  count(r.game_id) filter (where r.net > 0)             as games_won,
  round(100.0 * count(r.game_id) filter (where r.net > 0)
        / nullif(count(r.game_id), 0), 1)               as win_rate_pct,
  round(coalesce(sum(r.net), 0) / nullif(count(r.game_id), 0), 2) as avg_net_per_game,
  round(100.0 * coalesce(sum(r.net), 0)
        / nullif(sum(r.total_buy_in), 0), 1)            as roi_pct,
  max(r.net)                                            as best_game,
  min(r.net)                                            as worst_game
from public.players p
left join public.game_results r on r.player_id = p.id
group by p.id, p.name;


-- Net winnings per player over the last 3 months, 6 months, 12 months, and ever.
create or replace view public.leaderboard_periods
with (security_invoker = true) as
select
  p.id   as player_id,
  p.name as player_name,
  count(r.game_id) filter (where r.game_date >= current_date - interval '3 months')  as games_3m,
  coalesce(sum(r.net) filter (where r.game_date >= current_date - interval '3 months'), 0)  as net_3m,
  count(r.game_id) filter (where r.game_date >= current_date - interval '6 months')  as games_6m,
  coalesce(sum(r.net) filter (where r.game_date >= current_date - interval '6 months'), 0)  as net_6m,
  count(r.game_id) filter (where r.game_date >= current_date - interval '12 months') as games_12m,
  coalesce(sum(r.net) filter (where r.game_date >= current_date - interval '12 months'), 0) as net_12m,
  count(r.game_id)               as games_all,
  coalesce(sum(r.net), 0)        as net_all
from public.players p
left join public.game_results r on r.player_id = p.id
group by p.id, p.name;


-- 5. Functions the app uses to save a whole game in one step ------------
-- p_players is a JSON array like:
--   [{"player_id": 1, "buy_ins": 2, "winnings": 0},
--    {"player_id": 2, "buy_ins": 1, "winnings": 30}]
-- Pass p_game_id = null to create a game, or an id to replace that game's rows.
create or replace function public.save_game(
  p_game_id        bigint,
  p_date           date,
  p_default_buy_in numeric,
  p_players        jsonb
)
returns bigint
language plpgsql
as $$
declare
  v_id bigint;
begin
  if not public.is_editor() then
    raise exception 'Your account is not allowed to edit games';
  end if;

  if p_game_id is null then
    insert into public.games (date, default_buy_in)
    values (p_date, p_default_buy_in)
    returning id into v_id;
  else
    update public.games
       set date = p_date, default_buy_in = p_default_buy_in
     where id = p_game_id
    returning id into v_id;

    if v_id is null then
      raise exception 'Game % does not exist', p_game_id;
    end if;
  end if;

  delete from public.buy_ins where game_id = v_id;
  delete from public.winners where game_id = v_id;

  insert into public.buy_ins (player_id, game_id, number_of_buyins)
  select (x ->> 'player_id')::bigint, v_id, (x ->> 'buy_ins')::int
  from jsonb_array_elements(p_players) as x
  where coalesce((x ->> 'buy_ins')::int, 0) > 0;

  insert into public.winners (player_id, game_id, amount)
  select (x ->> 'player_id')::bigint, v_id, (x ->> 'winnings')::numeric
  from jsonb_array_elements(p_players) as x
  where coalesce((x ->> 'winnings')::numeric, 0) > 0;

  return v_id;
end;
$$;

create or replace function public.delete_game(p_game_id bigint)
returns void
language plpgsql
as $$
begin
  if not public.is_editor() then
    raise exception 'Your account is not allowed to delete games';
  end if;

  delete from public.buy_ins where game_id = p_game_id;
  delete from public.winners where game_id = p_game_id;
  delete from public.games   where id = p_game_id;
end;
$$;

revoke all on function public.save_game(bigint, date, numeric, jsonb) from public, anon;
revoke all on function public.delete_game(bigint) from public, anon;
grant execute on function public.save_game(bigint, date, numeric, jsonb) to authenticated;
grant execute on function public.delete_game(bigint) to authenticated;


-- 6. Row level security: everyone can read, only editors can write -------
-- The Supabase anon key ships inside the website, so these policies are what
-- actually protect your data.
do $$
declare
  t text;
begin
  foreach t in array array['players', 'games', 'buy_ins', 'winners', 'payments'] loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists "anyone can read" on public.%I', t);
    execute format(
      'create policy "anyone can read" on public.%I for select to anon, authenticated using (true)', t);

    execute format('drop policy if exists "editors can write" on public.%I', t);
    execute format(
      'create policy "editors can write" on public.%I for all to authenticated
         using (public.is_editor()) with check (public.is_editor())', t);
  end loop;
end $$;

-- No policies on editors on purpose: it can only be changed from the SQL editor.
alter table public.editors enable row level security;

grant select on
  public.game_results, public.game_checks, public.player_balances,
  public.player_stats, public.leaderboard_periods
to anon, authenticated;
