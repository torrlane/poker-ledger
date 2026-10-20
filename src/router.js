import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  { path: '/', name: 'leaderboard', component: () => import('./views/LeaderboardView.vue') },
  { path: '/balances', name: 'balances', component: () => import('./views/BalancesView.vue') },
  { path: '/games', name: 'games', component: () => import('./views/GamesView.vue') },
  { path: '/games/new', name: 'game-new', component: () => import('./views/GameFormView.vue') },
  {
    path: '/games/:id(\\d+)/edit',
    name: 'game-edit',
    component: () => import('./views/GameFormView.vue'),
  },
  { path: '/players', name: 'players', component: () => import('./views/PlayersView.vue') },
  {
    path: '/players/:id(\\d+)',
    name: 'player',
    component: () => import('./views/PlayerDetailView.vue'),
  },
  { path: '/payments', name: 'payments', component: () => import('./views/PaymentsView.vue') },
  { path: '/login', name: 'login', component: () => import('./views/LoginView.vue') },
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

export default createRouter({
  // BASE_URL is "/" locally and "/<repo>/" on GitHub Pages.
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})
