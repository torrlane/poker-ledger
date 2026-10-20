<script setup>
import { ref } from 'vue'
import { authReady, isEditor, sendMagicLink, session, signOut } from '../auth'

const email = ref('')
const sent = ref(false)
const busy = ref(false)
const error = ref('')

async function submit() {
  busy.value = true
  error.value = ''
  try {
    await sendMagicLink(email.value)
    sent.value = true
  } catch (e) {
    error.value = `Couldn't send the link: ${e.message}`
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div class="narrow">
    <div class="page-head">
      <div>
        <h1>Sign in</h1>
        <p>Anyone can view results. Only people on the editors list can add or change games and payments.</p>
      </div>
    </div>

    <div v-if="session" class="panel">
      <p>
        Signed in as <strong>{{ session.user.email }}</strong
        >.
      </p>
      <p v-if="authReady && !isEditor" class="notice">
        This email isn't on the editors list, so you can view but not edit. Add it to the
        <code>editors</code> table in Supabase to change that.
      </p>
      <button type="button" class="btn" @click="signOut">Sign out</button>
    </div>

    <form v-else-if="!sent" class="panel" @submit.prevent="submit">
      <label class="field">
        <span>Email address</span>
        <input v-model.trim="email" type="email" autocomplete="email" required />
      </label>
      <p v-if="error" class="error" style="margin-top: 16px">{{ error }}</p>
      <div class="form-actions">
        <button type="submit" class="btn primary" :disabled="busy || !email">
          {{ busy ? 'Sending…' : 'Send sign-in link' }}
        </button>
      </div>
    </form>

    <div v-else class="panel">
      <h2>Check your email</h2>
      <p style="margin-top: 12px">
        We sent a sign-in link to <strong>{{ email }}</strong
        >. Open it to finish signing in. It can take a minute to arrive.
      </p>
      <button type="button" class="btn" @click="sent = false">Use a different email</button>
    </div>
  </div>
</template>
