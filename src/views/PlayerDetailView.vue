<script setup>
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { getPlayerPage } from '../api'
import BalanceChip from '../components/BalanceChip.vue'
import LineChart from '../components/LineChart.vue'
import {
  formatDate,
  formatShortDate,
  money,
  num,
  plural,
  round2,
  signedMoney,
  tone,
} from '../format'

const route = useRoute()
const data = ref(null)
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  try {
    data.value = await getPlayerPage(route.params.id)
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})

const stats = computed(() => data.value?.stats)
const balance = computed(() => num(data.value?.balance?.balance))
const names = computed(() => Object.fromEntries((data.value?.players ?? []).map((p) => [p.id, p.name])))

const balanceLine = computed(() => {
  if (balance.value > 0.005) return `Owed ${money(balance.value)}`
  if (balance.value < -0.005) return `Owes ${money(-balance.value)}`
  return 'Settled up'
})

const periods = computed(() => {
  const p = data.value?.periods
  if (!p) return []
  return [
    { label: 'Last 3 months', net: p.net_3m },
    { label: 'Last 6 months', net: p.net_6m },
    { label: 'Last year', net: p.net_12m },
    { label: 'All time', net: p.net_all },
  ]
})

const series = computed(() => {
  let total = 0
  return (data.value?.results ?? []).map((r) => {
    total += num(r.net)
    return { label: formatShortDate(r.game_date), value: round2(total) }
  })
})

const history = computed(() => [...(data.value?.results ?? [])].reverse())

const rate = (v) => (v === null || v === undefined ? '–' : `${num(v)}%`)

function describe(payment) {
  return payment.from_player === data.value.id
    ? `Paid ${names.value[payment.to_player] ?? 'someone'}`
    : `Received from ${names.value[payment.from_player] ?? 'someone'}`
}
</script>

<template>
  <div>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-else-if="loading" class="loading">Loading…</p>
    <p v-else-if="!stats" class="empty">
      That player doesn't exist. <RouterLink to="/players">Back to players</RouterLink>
    </p>

    <template v-else>
      <div class="page-head">
        <div>
          <h1>{{ stats.player_name }}</h1>
          <p>{{ balanceLine }}, {{ plural(num(stats.games_played), 'game') }} played.</p>
        </div>
        <BalanceChip :amount="balance" :size="88" />
      </div>

      <dl class="stats">
        <div v-for="p in periods" :key="p.label">
          <dt>{{ p.label }}</dt>
          <dd :class="tone(p.net)">{{ signedMoney(p.net) }}</dd>
        </div>
      </dl>

      <section class="section">
        <h2>Record</h2>
        <dl class="stats">
          <div>
            <dt>Win rate</dt>
            <dd>{{ rate(stats.win_rate_pct) }}</dd>
          </div>
          <div>
            <dt>Average per game</dt>
            <dd :class="tone(stats.avg_net_per_game)">
              {{ stats.games_played ? signedMoney(stats.avg_net_per_game) : '–' }}
            </dd>
          </div>
          <div>
            <dt>Best night</dt>
            <dd :class="tone(stats.best_game)">
              {{ stats.games_played ? signedMoney(stats.best_game) : '–' }}
            </dd>
          </div>
          <div>
            <dt>Worst night</dt>
            <dd :class="tone(stats.worst_game)">
              {{ stats.games_played ? signedMoney(stats.worst_game) : '–' }}
            </dd>
          </div>
          <div>
            <dt>Total bought in</dt>
            <dd>{{ money(stats.total_staked) }}</dd>
          </div>
          <div>
            <dt>Return on buy-ins</dt>
            <dd :class="tone(stats.roi_pct)">{{ stats.roi_pct === null ? '–' : `${num(stats.roi_pct)}%` }}</dd>
          </div>
        </dl>
      </section>

      <section class="section">
        <h2>Running total</h2>
        <LineChart :points="series" />
      </section>

      <section class="section">
        <h2>Games</h2>
        <p v-if="!history.length" class="empty">No games yet.</p>
        <div v-else class="table-wrap">
          <table class="data">
            <thead>
              <tr>
                <th>Date</th>
                <th class="num">Buy-ins</th>
                <th class="num">Put in</th>
                <th class="num">Paid out</th>
                <th class="num">Net</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in history" :key="r.game_id">
                <td>{{ formatDate(r.game_date) }}</td>
                <td class="num">{{ r.buy_ins }}</td>
                <td class="num">{{ money(r.total_buy_in) }}</td>
                <td class="num">{{ money(r.winnings) }}</td>
                <td class="num" :class="tone(r.net)">{{ signedMoney(r.net) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="section">
        <h2>Payments</h2>
        <p v-if="!data.payments.length" class="empty">No payments recorded for this player.</p>
        <div v-else class="table-wrap">
          <table class="data">
            <thead>
              <tr>
                <th>Date</th>
                <th>Payment</th>
                <th>Note</th>
                <th class="num">Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in data.payments" :key="p.id">
                <td>{{ formatDate(p.paid_at) }}</td>
                <td>{{ describe(p) }}</td>
                <td class="muted">{{ p.notes }}</td>
                <td class="num">{{ money(p.amount) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </template>
  </div>
</template>
