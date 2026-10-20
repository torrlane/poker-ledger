import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_ANON_KEY

// False until .env (local) or the repository variables (GitHub Pages) are set.
export const configured = Boolean(url && key)

// createClient throws on empty values, so use placeholders when unconfigured.
// App.vue shows setup instructions instead of the pages in that case.
export const supabase = createClient(url || 'http://localhost', key || 'not-configured')
