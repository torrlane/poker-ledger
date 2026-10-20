<script setup>
import { RouterLink } from 'vue-router'
import { authReady, isEditor, session } from '../auth'
</script>

<template>
  <slot v-if="isEditor" />
  <p v-else-if="!authReady" class="loading">Checking your access…</p>
  <div v-else-if="session" class="notice">
    <strong>{{ session.user.email }} can view but not edit.</strong>
    Add this email to the <code>editors</code> table in Supabase to let it add games and payments.
  </div>
  <div v-else class="notice">
    <strong>Sign in to add or change data.</strong>
    <RouterLink to="/login">Get a sign-in link by email</RouterLink>
  </div>
</template>
