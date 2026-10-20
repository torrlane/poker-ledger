<script setup>
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import {
  addPlayer,
  deleteGame,
  getGameForEdit,
  getLatestBuyIn,
  getPlayers,
  saveGame,
} from '../api'
import EditorGate from '../components/EditorGate.vue'
import { money, num, round2, signedMoney, todayISO, tone } from '../format'

const route = useRoute()
const router = useRouter()

const gameId = computed(() => (route.params.id ? Number(route.params.id) : null))
const editing = computed(() => gameId.value !== null)

const loading = ref(true)
const saving = ref(false)
const error = ref('')

const date = ref(todayISO())
const buyIn = ref(10)
// One row per player: buyins is a count, winnings is the gross payout as typed.
const rows = ref([])

const newName = ref('')
const addingPlayer = ref(false)
const allowMismatch = ref(false)

onMounted(async () => {
  try {
    const players = await getPlayers()
    let buyIns = []
    let winners = []

    if (editing.value) {
      const existing = await getGameForEdit(gameId.value)
      date.value = String(existing.game.date).slice(0, 10)
      buyIn.value = num(existing.game.default_buy_in)
      buyIns = existing.buyIns
      winners = existing.winners
    } else {
      // Start from the buy-in used last time.
      const latest = await getLatestBuyIn()
      if (latest) buyIn.value = num(latest)
    }

    const stakes = new Map(buyIns.map((b) => [b.player_id, b.number_of_buyins]))
    const payouts = new Map(winners.map((w) => [w.player_id, w.amount]))
    rows.value = players.map((p) => ({
      player_id: p.id,
      name: p.name,
      buyins: stakes.get(p.id) ?? 0,
      winnings: payouts.has(p.id) ? String(payouts.get(p.id)) : '',
    }))
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})

const isIn = (r) => r.buyins > 0 || num(r.winnings) > 0
const rowNet = (r) => round2(num(r.winnings) - r.buyins * num(buyIn.value))
const bump = (r, by) => (r.buyins = Math.max(0, r.buyins + by))

const pot = computed(() => round2(rows.value.reduce((s, r) => s + r.buyins, 0) * num(buyIn.value)))
const paidOut = computed(() => round2(rows.value.reduce((s, r) => s + num(r.winnings), 0)))
const difference = computed(() => round2(paidOut.value - pot.value))
const balanced = computed(() => Math.abs(difference.value) < 0.005)

const problems = computed(() => {
  const list = []
  if (!date.value) list.push('Choose the date of the game.')
  if (!(num(buyIn.value) > 0)) list.push('Enter the buy-in amount.')
  if (!rows.value.some((r) => r.buyins > 0)) list.push('Add at least one buy-in.')
  const stray = rows.value.filter((r) => num(r.winnings) > 0 && r.buyins === 0).map((r) => r.name)
  if (stray.length) {
    list.push(`${stray.join(', ')} ${stray.length === 1 ? 'has' : 'have'} a payout but no buy-in.`)
  }
  return list
})

const canSave = computed(
  () => !saving.value && problems.value.length === 0 && (balanced.value || allowMismatch.value),
)

async function createPlayer() {
  if (!newName.value || addingPlayer.value) return
  addingPlayer.value = true
  error.value = ''
  try {
    const player = await addPlayer(newName.value)
    rows.value.push({ player_id: player.id, name: player.name, buyins: 1, winnings: '' })
    rows.value.sort((a, b) => a.name.localeCompare(b.name))
    newName.value = ''
  } catch (e) {
    error.value = e.message
  } finally {
    addingPlayer.value = false
  }
}

async function submit() {
  if (!canSave.value) return
  saving.value = true
  error.value = ''
  try {
    await saveGame({
      id: gameId.value,
      date: date.value,
      defaultBuyIn: num(buyIn.value),
      players: rows.value.filter(isIn).map((r) => ({
        player_id: r.player_id,
        buy_ins: r.buyins,
        winnings: num(r.winnings),
      })),
    })
    router.push({ name: 'games' })
  } catch (e) {
    error.value = e.message
    saving.value = false
  }
}

async function remove() {
  if (!window.confirm('Delete this game and its buy-ins and payouts? This cannot be undone.')) return
  saving.value = true
  error.value = ''
  try {
    await deleteGame(gameId.value)
    router.push({ name: 'games' })
  } catch (e) {
    error.value = e.message
    saving.value = false
  }
}
</script>

<template>
  <EditorGate>
    <div class="page-head">
      <div>
        <h1>{{ editing ? 'Edit game' : 'New game' }}</h1>
        <p>Add each player's buy-ins and what they were paid. Payouts should add up to the pot.</p>
      </div>
    </div>

    <p v-if="loading" class="loading">Loading players…</p>
    <p v-else-if="error && !rows.length" class="error">{{ error }}</p>

    <form v-else @submit.prevent="submit">
      <div class="form-grid">
        <label class="field">
          <span>Date</span>
          <input v-model="date" type="date" required />
        </label>
        <label class="field">
          <span>Buy-in (£)</span>
          <input
            v-model.number="buyIn"
            type="number"
            inputmode="decimal"
            step="0.01"
            min="0"
            required
          />
        </label>
      </div>

      <h2 class="section">Players</h2>
      <ul class="entry">
        <li v-for="r in rows" :key="r.player_id" class="entry-row" :class="{ out: !isIn(r) }">
          <span class="name">{{ r.name }}</span>

          <div class="stepper" role="group" :aria-label="`${r.name} buy-ins`">
            <button type="button" :disabled="r.buyins === 0" aria-label="Remove a buy-in" @click="bump(r, -1)">
              &minus;
            </button>
            <output>{{ r.buyins }}</output>
            <button type="button" aria-label="Add a buy-in" @click="bump(r, 1)">+</button>
          </div>

          <label class="pay">
            <span class="sr-only">{{ r.name }} payout in pounds</span>
            <input
              v-model="r.winnings"
              type="number"
              inputmode="decimal"
              step="0.01"
              min="0"
              placeholder="Payout"
            />
          </label>

          <span class="net" :class="tone(rowNet(r))">{{ isIn(r) ? signedMoney(rowNet(r)) : '' }}</span>
        </li>
      </ul>

      <div class="inline-form add-player">
        <label class="field">
          <span>Someone new?</span>
          <input
            v-model.trim="newName"
            maxlength="40"
            placeholder="Name"
            @keydown.enter.prevent="createPlayer"
          />
        </label>
        <button type="button" class="btn" :disabled="!newName || addingPlayer" @click="createPlayer">
          {{ addingPlayer ? 'Adding…' : 'Add player' }}
        </button>
      </div>

      <div class="check" aria-live="polite">
        <span>
          Pot <strong>{{ money(pot) }}</strong>
        </span>
        <span>
          Paid out <strong>{{ money(paidOut) }}</strong>
        </span>
        <span class="state" :class="balanced ? 'pos' : 'neg'">
          {{
            balanced
              ? 'Payouts match the pot'
              : `Payouts are ${money(Math.abs(difference))} ${difference < 0 ? 'short of' : 'over'} the pot`
          }}
        </span>
      </div>

      <label v-if="!balanced" class="checkbox-line">
        <input v-model="allowMismatch" type="checkbox" />
        <span>Save anyway. The game will show as unbalanced.</span>
      </label>

      <p v-if="problems.length" class="hints">{{ problems.join(' ') }}</p>
      <p v-if="error" class="error" style="margin-top: 16px">{{ error }}</p>

      <div class="form-actions">
        <button type="submit" class="btn primary" :disabled="!canSave">
          {{ saving ? 'Saving…' : 'Save game' }}
        </button>
        <RouterLink to="/games" class="btn">Cancel</RouterLink>
        <button v-if="editing" type="button" class="btn danger" :disabled="saving" @click="remove">
          Delete game
        </button>
      </div>
    </form>
  </EditorGate>
</template>
