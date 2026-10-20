<script setup>
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { getGameChecks, getGameResults } from '../api'
import { isEditor } from '../auth'
import { formatDate, money, num, plural, signedMoney, tone } from '../format'

const checks = ref([])
const results = ref({})
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  try {
    checks.value = await getGameChecks()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})

// Player rows are fetched the first time a game is opened.
async function onToggle(event, gameId) {
  if (!event.target.open || results.value[gameId]) return
  try {
    results.value[gameId] = await getGameResults(gameId)
  } catch (e) {
    error.value = e.message
  }
}
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <h1>Games</h1>
        <p>Open a game to see who bought in and who was paid.</p>
      </div>
      <RouterLink v-if="isEditor" to="/games/new" class="btn primary">Add game</RouterLink>
    </div>

    <p v-if="error" class="error">{{ error }}</p>
    <p v-if="loading" class="loading">Loading…</p>
    <p v-else-if="!checks.length" class="empty">
      No games yet.
      <RouterLink v-if="isEditor" to="/games/new">Add the first game</RouterLink>
      <template v-else>Sign in as an editor to add the first one.</template>
    </p>

    <div v-else>
      <details
        v-for="g in checks"
        :key="g.game_id"
        class="game"
        @toggle="onToggle($event, g.game_id)"
      >
        <summary>
          <span class="game-date">{{ formatDate(g.game_date) }}</span>
          <span class="game-meta">
            {{ plural(num(g.players), 'player') }}, {{ money(g.default_buy_in) }} buy-in, pot
            {{ money(g.pot) }}
          </span>
          <span class="badge" :class="g.balanced ? 'ok' : 'off'">
            {{ g.balanced ? 'Balanced' : `Off by ${money(Math.abs(num(g.difference)))}` }}
          </span>
        </summary>

        <div class="game-body">
          <p v-if="!results[g.game_id]" class="loading">Loading…</p>
          <div v-else class="table-wrap">
            <table class="data">
              <thead>
                <tr>
                  <th>Player</th>
                  <th class="num">Buy-ins</th>
                  <th class="num">Put in</th>
                  <th class="num">Paid out</th>
                  <th class="num">Net</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="r in results[g.game_id]" :key="r.player_id">
                  <td>
                    <RouterLink :to="`/players/${r.player_id}`">{{ r.player_name }}</RouterLink>
                  </td>
                  <td class="num">{{ r.buy_ins }}</td>
                  <td class="num">{{ money(r.total_buy_in) }}</td>
                  <td class="num">{{ money(r.winnings) }}</td>
                  <td class="num" :class="tone(r.net)">{{ signedMoney(r.net) }}</td>
                </tr>
              </tbody>
              <tfoot>
                <tr>
                  <td>Total</td>
                  <td class="num">{{ g.total_buy_ins }}</td>
                  <td class="num">{{ money(g.pot) }}</td>
                  <td class="num">{{ money(g.paid_out) }}</td>
                  <td class="num" :class="tone(g.difference)">{{ signedMoney(g.difference) }}</td>
                </tr>
              </tfoot>
            </table>
          </div>
          <p v-if="isEditor" style="margin: 16px 0 0">
            <RouterLink :to="`/games/${g.game_id}/edit`" class="btn small">Edit game</RouterLink>
          </p>
        </div>
      </details>
    </div>
  </div>
</template>
