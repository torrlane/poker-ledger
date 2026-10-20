import { ref } from 'vue'
import { supabase } from './supabase'

export const session = ref(null)
export const isEditor = ref(false)
// True once the first session check, and the editor check that follows it, are done.
export const authReady = ref(false)

async function refreshEditor() {
  if (!session.value) {
    isEditor.value = false
    return
  }
  const { data, error } = await supabase.rpc('is_editor')
  isEditor.value = !error && data === true
}

supabase.auth.getSession().then(async ({ data }) => {
  session.value = data.session
  await refreshEditor()
  authReady.value = true
})

supabase.auth.onAuthStateChange((_event, newSession) => {
  session.value = newSession
  // Calling Supabase from inside this callback can deadlock, so defer it.
  setTimeout(async () => {
    await refreshEditor()
    authReady.value = true
  }, 0)
})

export async function sendMagicLink(email) {
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: window.location.origin + import.meta.env.BASE_URL },
  })
  if (error) throw error
}

export function signOut() {
  return supabase.auth.signOut()
}
