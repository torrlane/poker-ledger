<script setup>
import { RouterLink, RouterView, useRoute } from 'vue-router'
import { configured } from './supabase'
import { authReady, isEditor, session, signOut } from './auth'

const route = useRoute()

const nav = [
  { to: '/', label: 'Leaderboard' },
  { to: '/balances', label: 'Balances' },
  { to: '/games', label: 'Games' },
  { to: '/players', label: 'Players' },
  { to: '/payments', label: 'Payments' },
]

const isCurrent = (to) => (to === '/' ? route.path === '/' : route.path.startsWith(to))
</script>

<template>
  <header class="site-header">
    <div class="shell">
      <RouterLink to="/" class="brand">
        <span class="chip sm" aria-hidden="true" style="--face: var(--chip-red)"></span>
        Poker Ledger
      </RouterLink>

      <nav class="nav" aria-label="Main">
        <RouterLink
          v-for="item in nav"
          :key="item.to"
          :to="item.to"
          :class="{ current: isCurrent(item.to) }"
          :aria-current="isCurrent(item.to) ? 'page' : undefined"
        >
          {{ item.label }}
        </RouterLink>
      </nav>

      <div class="account">
        <RouterLink v-if="isEditor" to="/games/new" class="btn small primary">Add game</RouterLink>
        <button v-if="session" type="button" class="link-button" @click="signOut">Sign out</button>
        <RouterLink v-else-if="authReady" to="/login" class="link-button">Sign in</RouterLink>
      </div>
    </div>
  </header>

  <main class="shell">
    <div v-if="!configured" class="notice">
      <strong>The database connection isn't set up yet.</strong>
      Copy <code>.env.example</code> to <code>.env</code>, fill in your Supabase URL and anon key,
      then restart the dev server. On GitHub Pages, add them as repository variables. The README has
      the steps.
    </div>
    <RouterView v-else v-slot="{ Component }">
      <component :is="Component" :key="route.fullPath" />
    </RouterView>
  </main>
</template>
