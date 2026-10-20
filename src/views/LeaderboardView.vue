<script setup>
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { getLeaderboard } from '../api'
import { plural, signedMoney, tone, num } from '../format'

const periods = [
  { key: '3m', label: '3 months' },
  { key: '6m', label: '6 months' },
  { key: '12m', label: '1 year' },
  { key: 'all', label: 'All time' },
]

const period = ref('all')
const rows = ref([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  try {
    rows.value = await getLeaderboard()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})

const ranked = computed(() => {
  const key = period.value
  return rows.value
    .map((r) => ({
      id: r.player_id,
      name: r.player_name,
      games: num(r[`games_${key}`]),
      net: num(r[`net_${key}`]),
    }))
    .filter((r) => r.games > 0)
    .sort((a, b) => b.net - a.net || a.name.localeCompare(b.name))
})

const biggest = computed(() => Math.max(1, ...ranked.value.map((r) => Math.abs(r.net))))
const barWidth = (net) => `${Math.max(1, (Math.abs(net) / biggest.value) * 100)}%`
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <h1>Leaderboard</h1>
        <p>Net winnings: what each player took home minus what they put in.</p>
      </div>
    </div>

    <div class="tabs" role="tablist" aria-label="Time period">
      <button
        v-for="p in periods"
        :key="p.key"
        type="button"
        role="tab"
        :aria-selected="period === p.key"
        @click="period = p.key"
      >
        {{ p.label }}
      </button>
    </div>

    <p v-if="error" class="error">Couldn't load the leaderboard: {{ error }}</p>
    <p v-else-if="loading" class="loading">Loading…</p>
    <p v-else-if="!ranked.length" class="empty">
      No games in this period yet. <RouterLink to="/games">See all games</RouterLink>
    </p>

    <ol v-else class="ranking">
      <li v-for="(r, i) in ranked" :key="r.id">
        <span class="rank">{{ i + 1 }}</span>
        <div class="who">
          <RouterLink :to="`/players/${r.id}`">{{ r.name }}</RouterLink>
          <small>{{ plural(r.games, 'game') }}</small>
          <div class="bar" :class="{ neg: r.net < 0 }" :style="{ width: barWidth(r.net) }"></div>
        </div>
        <span class="amount" :class="tone(r.net)">{{ signedMoney(r.net) }}</span>
      </li>
    </ol>
  </div>
</template>
