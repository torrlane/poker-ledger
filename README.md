# Poker Ledger

A small Vue app for tracking poker nights with friends: enter games, see a leaderboard over 3 months, 6 months, a year and all time, and see who is owed money and who owes it. It runs on GitHub Pages for free and stores everything in your Supabase database.

## How the money works

- **Games stay as you have them.** `buy_ins` holds each player's number of buy-ins, `winners` holds each player's gross payout, and `games.default_buy_in` sets the price of a buy-in.
- **Results are calculated, not stored.** A player's net for a game is their payout minus `number_of_buyins * default_buy_in`.
- **The new `payments` table records real transfers.** One row per payment: who paid whom, how much, when, and an optional note. It isn't tied to a game, so you can settle one night or a running balance.
- **Balances are calculated too.** Balance = all game results + payments you sent − payments you received. Positive means you are owed money, negative means you owe it, zero means settled.
- **Each game is checked.** The pot (all buy-ins) should equal the payouts. If it doesn't, the game shows as unbalanced on the Games and Balances pages.

## Setup

### 1. Update the database

1. Open `supabase/001_payments_views_access.sql`.
2. Replace `you@example.com` with the email addresses of the people who may enter data. Add more rows to the `insert` if needed.
3. Paste the file into the Supabase SQL Editor and run it. It is safe to run again.

This adds the `payments` and `editors` tables, the views the app reads (`game_results`, `game_checks`, `player_balances`, `player_stats`, `leaderboard_periods`), two functions for saving and deleting a whole game in one step, and row level security: anyone can read, only editors can write.

It assumes `players.id` and `games.id` are `bigint` and `games.date` is a `date`. If your ids are `uuid`, change those types in the file before running it.

### 2. Allow sign-in links

In Supabase, go to **Authentication > URL Configuration** and add these under **Redirect URLs**:

- `http://localhost:5173/` for local development
- `https://YOUR-USERNAME.github.io/YOUR-REPO/` for the live site

The sign-in link also works on a phone, because it doesn't depend on the browser that requested it.

### 3. Run it locally

```
npm install
cp .env.example .env     # then fill in the two values
npm run dev
```

Both values are in Supabase under **Project Settings > API**: the project URL and the anon (or publishable) key.

### 4. Publish on GitHub Pages

1. Push this folder to a GitHub repository with a `main` branch.
2. In the repository, go to **Settings > Pages** and set **Source** to **GitHub Actions**.
3. Go to **Settings > Secrets and variables > Actions > Variables** and add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
4. Push to `main`, or run the workflow from the **Actions** tab. The site appears at `https://YOUR-USERNAME.github.io/YOUR-REPO/`.

If the repository is named `YOUR-USERNAME.github.io`, change `VITE_BASE` in `.github/workflows/deploy.yml` to `/`.

## Day to day

- **After a game:** sign in, choose **Add game**, set the date and buy-in, tap + for each buy-in, and type each payout. The page shows whether payouts match the pot.
- **When someone pays:** go to **Payments** and record who paid whom. The Balances page updates straight away.
- **Adding an editor:** insert their email (lowercase) into the `editors` table in the Supabase SQL Editor: `insert into editors (email) values ('friend@example.com');`
- **Currency:** the app uses pounds. To change it, edit `src/format.js` and the "(£)" labels in the form pages.

## Things to know

- The Supabase anon key is visible in the published site. That is normal; the row level security policies are what protect your data. Because the site is public, anyone who finds the address can **read** names and results. Writing needs a sign-in from an email on the editors list.
- The app uses the plain GitHub Actions versions `v4`. If GitHub shows a deprecation warning, bump them in the workflow file.
