<script setup>
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { getBalances, getGameChecks } from '../api'
import { isEditor } from '../auth'
import BalanceChip from '../components/BalanceChip.vue'
import { formatDate, money, num, plural } from '../format'

const balances = ref([])
const checks = ref([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  try {
    ;[balances.value, checks.value] = await Promise.all([getBalances(), getGameChecks()])
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})

const owed = computed(() =>
  balances.value.filter((b) => num(b.balance) > 0.005).sort((a, b) => num(b.balance) - num(a.balance)),
)
const owing = computed(() =>
  balances.value.filter((b) => num(b.balance) < -0.005).sort((a, b) => num(a.balance) - num(b.balance)),
)
const settled = computed(() => balances.value.filter((b) => Math.abs(num(b.balance)) <= 0.005))

const totalOwed = computed(() => owed.value.reduce((sum, b) => sum + num(b.balance), 0))
const totalOwing = computed(() => owing.value.reduce((sum, b) => sum - num(b.balance), 0))

const unbalanced = computed(() => checks.value.filter((c) => !c.balanced))
const gameLink = (g) => (isEditor.value ? `/games/${g.game_id}/edit` : '/games')
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <h1>Balances</h1>
        <p>Who is still owed money and who still owes it, after the payments recorded so far.</p>
      </div>
      <RouterLink to="/payments" class="btn">Record payment</RouterLink>
    </div>

    <p v-if="error" class="error">Couldn't load balances: {{ error }}</p>
    <p v-else-if="loading" class="loading">Loading…</p>

    <template v-else>
      <div v-if="unbalanced.length" class="notice">
        <strong>
          {{ plural(unbalanced.length, 'game') }}
          {{ unbalanced.length === 1 ? "has" : "have" }} payouts that don't match the buy-ins.
        </strong>
        The amounts owed below won't add up until they're fixed.
        <ul>
          <li v-for="g in unbalanced" :key="g.game_id">
            <RouterLink :to="gameLink(g)">{{ formatDate(g.game_date) }}</RouterLink>
            had {{ money(Math.abs(num(g.difference))) }}
            {{ num(g.difference) < 0 ? 'less' : 'more' }} paid out than put in
          </li>
        </ul>
      </div>

      <section v-if="owed.length" class="section">
        <h2>Owed money</h2>
        <p class="muted">{{ money(totalOwed) }} still to be paid to these players.</p>
        <div class="chip-board">
          <div v-for="(b, i) in owed" :key="b.player_id" class="chip-slot">
            <BalanceChip class="drop" :style="{ '--i': i }" :amount="b.balance" />
            <RouterLink :to="`/players/${b.player_id}`">{{ b.player_name }}</RouterLink>
          </div>
        </div>
      </section>

      <section v-if="owing.length" class="section">
        <h2>Owe money</h2>
        <p class="muted">{{ money(totalOwing) }} still to be paid in by these players.</p>
        <div class="chip-board">
          <div v-for="(b, i) in owing" :key="b.player_id" class="chip-slot">
            <BalanceChip class="drop" :style="{ '--i': i + owed.length }" :amount="b.balance" />
            <RouterLink :to="`/players/${b.player_id}`">{{ b.player_name }}</RouterLink>
          </div>
        </div>
      </section>

      <p v-if="!owed.length && !owing.length" class="empty">
        Everyone is settled up. New games and payments will show here.
      </p>

      <p v-if="settled.length && (owed.length || owing.length)" class="section muted">
        Settled up: {{ settled.map((b) => b.player_name).join(', ') }}.
      </p>
    </template>
  </div>
</template>
