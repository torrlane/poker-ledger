<script setup>
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { addPlayer, getPlayerStats } from '../api'
import { isEditor } from '../auth'
import { money, num, signedMoney, tone } from '../format'

const stats = ref([])
const loading = ref(true)
const error = ref('')
const name = ref('')
const busy = ref(false)

async function load() {
  stats.value = await getPlayerStats()
}

onMounted(async () => {
  try {
    await load()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})

async function add() {
  busy.value = true
  error.value = ''
  try {
    await addPlayer(name.value)
    name.value = ''
    await load()
  } catch (e) {
    error.value = e.message
  } finally {
    busy.value = false
  }
}

const rate = (v) => (v === null || v === undefined ? '–' : `${num(v)}%`)
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <h1>Players</h1>
        <p>Lifetime figures. A win is a night finished in profit.</p>
      </div>
    </div>

    <p v-if="error" class="error">{{ error }}</p>
    <p v-if="loading" class="loading">Loading…</p>
    <p v-else-if="!stats.length" class="empty">No players yet. Add the first one below.</p>

    <div v-else class="table-wrap">
      <table class="data">
        <thead>
          <tr>
            <th>Player</th>
            <th class="num">Games</th>
            <th class="num">Win rate</th>
            <th class="num">Per game</th>
            <th class="num">Net</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in stats" :key="s.player_id">
            <td>
              <RouterLink :to="`/players/${s.player_id}`">{{ s.player_name }}</RouterLink>
            </td>
            <td class="num">{{ s.games_played }}</td>
            <td class="num">{{ rate(s.win_rate_pct) }}</td>
            <td class="num" :class="tone(s.avg_net_per_game)">
              {{ s.games_played ? signedMoney(s.avg_net_per_game) : '–' }}
            </td>
            <td class="num" :class="tone(s.net)">{{ signedMoney(s.net) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <form v-if="isEditor" class="panel inline-form section" @submit.prevent="add">
      <label class="field">
        <span>Add a player</span>
        <input v-model.trim="name" required maxlength="40" placeholder="Name" />
      </label>
      <button type="submit" class="btn primary" :disabled="!name || busy">
        {{ busy ? 'Adding…' : 'Add player' }}
      </button>
    </form>
  </div>
</template>
