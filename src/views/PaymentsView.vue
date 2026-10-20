<script setup>
import { computed, onMounted, ref } from 'vue'
import { addPayment, deletePayment, getBalances, getPayments, getPlayers } from '../api'
import { isEditor } from '../auth'
import EditorGate from '../components/EditorGate.vue'
import { formatDate, money, num, todayISO } from '../format'

const players = ref([])
const payments = ref([])
const balances = ref([])
const loading = ref(true)
const busy = ref(false)
const error = ref('')

const form = ref({ from: '', to: '', amount: '', paid_at: todayISO(), notes: '' })

async function load() {
  ;[players.value, payments.value, balances.value] = await Promise.all([
    getPlayers(),
    getPayments(),
    getBalances(),
  ])
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

const names = computed(() => Object.fromEntries(players.value.map((p) => [p.id, p.name])))
const payees = computed(() => players.value.filter((p) => p.id !== form.value.from))

const canSubmit = computed(
  () =>
    form.value.from !== '' &&
    form.value.to !== '' &&
    form.value.from !== form.value.to &&
    num(form.value.amount) > 0 &&
    form.value.paid_at,
)

// Reminds the person entering the payment where each side currently stands.
const hints = computed(() =>
  [form.value.from, form.value.to].filter((id) => id !== '').map((id) => {
    const balance = num(balances.value.find((b) => b.player_id === id)?.balance)
    const name = names.value[id]
    if (balance > 0.005) return `${name} is owed ${money(balance)}.`
    if (balance < -0.005) return `${name} owes ${money(-balance)}.`
    return `${name} is settled up.`
  }),
)

async function submit() {
  if (!canSubmit.value) return
  busy.value = true
  error.value = ''
  try {
    await addPayment({
      from_player: form.value.from,
      to_player: form.value.to,
      amount: num(form.value.amount),
      paid_at: form.value.paid_at,
      notes: form.value.notes.trim() || null,
    })
    form.value.amount = ''
    form.value.notes = ''
    await load()
  } catch (e) {
    error.value = e.message
  } finally {
    busy.value = false
  }
}

async function remove(payment) {
  const text = `${names.value[payment.from_player]} paid ${names.value[payment.to_player]} ${money(payment.amount)}`
  if (!window.confirm(`Delete this payment? ${text}`)) return
  error.value = ''
  try {
    await deletePayment(payment.id)
    await load()
  } catch (e) {
    error.value = e.message
  }
}
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <h1>Payments</h1>
        <p>Record each transfer when it happens. Balances update straight away.</p>
      </div>
    </div>

    <p v-if="error" class="error">{{ error }}</p>

    <EditorGate>
      <form class="panel" @submit.prevent="submit">
        <div class="form-grid">
          <label class="field">
            <span>Paid by</span>
            <select v-model="form.from" required>
              <option value="" disabled>Choose a player</option>
              <option v-for="p in players" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
          </label>
          <label class="field">
            <span>Paid to</span>
            <select v-model="form.to" required>
              <option value="" disabled>Choose a player</option>
              <option v-for="p in payees" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
          </label>
          <label class="field">
            <span>Amount (£)</span>
            <input
              v-model="form.amount"
              type="number"
              inputmode="decimal"
              step="0.01"
              min="0.01"
              required
            />
          </label>
          <label class="field">
            <span>Date</span>
            <input v-model="form.paid_at" type="date" required />
          </label>
        </div>

        <label class="field stack-top">
          <span>Note (optional)</span>
          <input v-model="form.notes" maxlength="200" placeholder="For example: bank transfer, 3 Oct game" />
        </label>

        <div v-if="hints.length" class="hints">
          <p v-for="line in hints" :key="line">{{ line }}</p>
        </div>

        <div class="form-actions">
          <button type="submit" class="btn primary" :disabled="!canSubmit || busy">
            {{ busy ? 'Saving…' : 'Record payment' }}
          </button>
        </div>
      </form>
    </EditorGate>

    <section class="section">
      <h2>History</h2>
      <p v-if="loading" class="loading">Loading…</p>
      <p v-else-if="!payments.length" class="empty">No payments recorded yet.</p>
      <div v-else class="table-wrap">
        <table class="data">
          <thead>
            <tr>
              <th>Date</th>
              <th>Payment</th>
              <th>Note</th>
              <th class="num">Amount</th>
              <th v-if="isEditor"><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in payments" :key="p.id">
              <td>{{ formatDate(p.paid_at) }}</td>
              <td>{{ names[p.from_player] }} paid {{ names[p.to_player] }}</td>
              <td class="muted">{{ p.notes }}</td>
              <td class="num">{{ money(p.amount) }}</td>
              <td v-if="isEditor" class="num">
                <button type="button" class="btn small danger" @click="remove(p)">Delete</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>
</template>
