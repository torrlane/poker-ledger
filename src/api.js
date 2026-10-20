import { supabase } from './supabase'

// Runs a Supabase query and returns its data, or throws a readable error.
async function run(query) {
  const { data, error } = await query
  if (error) throw new Error(error.message)
  return data
}

// ---------- Reading ----------

export const getPlayers = () => run(supabase.from('players').select('id, name').order('name'))

export const getPlayerStats = () =>
  run(supabase.from('player_stats').select('*').order('net', { ascending: false }))

export const getLeaderboard = () => run(supabase.from('leaderboard_periods').select('*'))

export const getBalances = () => run(supabase.from('player_balances').select('*'))

export const getGameChecks = () =>
  run(
    supabase
      .from('game_checks')
      .select('*')
      .order('game_date', { ascending: false })
      .order('game_id', { ascending: false }),
  )

export const getGameResults = (gameId) =>
  run(
    supabase
      .from('game_results')
      .select('*')
      .eq('game_id', gameId)
      .order('net', { ascending: false }),
  )

export const getPayments = () =>
  run(
    supabase
      .from('payments')
      .select('*')
      .order('paid_at', { ascending: false })
      .order('id', { ascending: false }),
  )

export async function getLatestBuyIn() {
  const rows = await run(
    supabase.from('games').select('default_buy_in').order('date', { ascending: false }).limit(1),
  )
  return rows[0]?.default_buy_in ?? null
}

export async function getGameForEdit(id) {
  const [game, buyIns, winners] = await Promise.all([
    run(supabase.from('games').select('id, date, default_buy_in').eq('id', id).single()),
    run(supabase.from('buy_ins').select('player_id, number_of_buyins').eq('game_id', id)),
    run(supabase.from('winners').select('player_id, amount').eq('game_id', id)),
  ])
  return { game, buyIns, winners }
}

export async function getPlayerPage(rawId) {
  const id = Number(rawId)
  if (!Number.isInteger(id)) throw new Error('That player link is not valid.')

  const [stats, periods, balance, results, payments, players] = await Promise.all([
    run(supabase.from('player_stats').select('*').eq('player_id', id).maybeSingle()),
    run(supabase.from('leaderboard_periods').select('*').eq('player_id', id).maybeSingle()),
    run(supabase.from('player_balances').select('*').eq('player_id', id).maybeSingle()),
    run(
      supabase
        .from('game_results')
        .select('*')
        .eq('player_id', id)
        .order('game_date')
        .order('game_id'),
    ),
    run(
      supabase
        .from('payments')
        .select('*')
        .or(`from_player.eq.${id},to_player.eq.${id}`)
        .order('paid_at', { ascending: false })
        .order('id', { ascending: false }),
    ),
    run(supabase.from('players').select('id, name')),
  ])
  return { id, stats, periods, balance, results, payments, players }
}

// ---------- Writing (editors only; the database enforces this) ----------

export const addPlayer = (name) =>
  run(supabase.from('players').insert({ name }).select('id, name').single())

export const addPayment = (payment) => run(supabase.from('payments').insert(payment))

export const deletePayment = (id) => run(supabase.from('payments').delete().eq('id', id))

export const saveGame = ({ id, date, defaultBuyIn, players }) =>
  run(
    supabase.rpc('save_game', {
      p_game_id: id,
      p_date: date,
      p_default_buy_in: defaultBuyIn,
      p_players: players,
    }),
  )

export const deleteGame = (id) => run(supabase.rpc('delete_game', { p_game_id: id }))
