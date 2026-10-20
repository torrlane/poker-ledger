<script setup>
import { computed } from 'vue'
import { signedMoney, tone } from '../format'

// Running total over time. points: [{ label, value }]
const props = defineProps({ points: { type: Array, required: true } })

const W = 640
const H = 240
const PAD = { left: 56, right: 16, top: 16, bottom: 30 }

function niceStep(raw) {
  const mag = 10 ** Math.floor(Math.log10(raw))
  const n = raw / mag
  return (n < 1.5 ? 1 : n < 3.5 ? 2 : n < 7.5 ? 5 : 10) * mag
}

const geo = computed(() => {
  const pts = props.points
  if (pts.length < 2) return null

  const values = pts.map((p) => p.value)
  let min = Math.min(0, ...values)
  let max = Math.max(0, ...values)
  if (min === max) max = min + 1
  const pad = (max - min) * 0.08
  min -= pad
  max += pad

  const x = (i) => PAD.left + (i / (pts.length - 1)) * (W - PAD.left - PAD.right)
  const y = (v) => PAD.top + (1 - (v - min) / (max - min)) * (H - PAD.top - PAD.bottom)

  const coords = pts.map((p, i) => ({ ...p, x: x(i), y: y(p.value) }))
  const line = coords.map((c, i) => `${i ? 'L' : 'M'}${c.x.toFixed(1)} ${c.y.toFixed(1)}`).join(' ')
  const last = coords[coords.length - 1]
  const zeroY = y(0)
  const area = `${line} L${last.x.toFixed(1)} ${zeroY.toFixed(1)} L${coords[0].x.toFixed(1)} ${zeroY.toFixed(1)} Z`

  const step = niceStep((max - min) / 4)
  const ticks = []
  for (let t = Math.ceil(min / step) * step; t <= max; t += step) {
    ticks.push({ value: Math.round(t * 100) / 100, y: y(t) })
  }

  return { coords, line, area, ticks, zeroY, last, showDots: pts.length <= 60 }
})

const description = computed(() => {
  const g = geo.value
  if (!g) return ''
  return `Running total across ${props.points.length} games, now ${signedMoney(g.last.value)}`
})
</script>

<template>
  <p v-if="!geo" class="muted">The chart appears after this player's second game.</p>
  <svg v-else class="chart" :viewBox="`0 0 ${W} ${H}`" role="img" :aria-label="description">
    <g v-for="t in geo.ticks" :key="t.value">
      <line class="gridline" :x1="PAD.left" :x2="W - PAD.right" :y1="t.y" :y2="t.y" />
      <text :x="PAD.left - 8" :y="t.y + 4" text-anchor="end">
        {{ t.value < 0 ? '−' : '' }}£{{ Math.abs(t.value) }}
      </text>
    </g>
    <line class="zero-line" :x1="PAD.left" :x2="W - PAD.right" :y1="geo.zeroY" :y2="geo.zeroY" />
    <path class="area" :d="geo.area" />
    <path class="line" :d="geo.line" />

    <template v-if="geo.showDots">
      <circle
        v-for="(c, i) in geo.coords.slice(0, -1)"
        :key="i"
        class="dot"
        :cx="c.x"
        :cy="c.y"
        r="3.5"
      >
        <title>{{ c.label }}: {{ signedMoney(c.value) }}</title>
      </circle>
    </template>
    <circle class="dot last" :class="tone(geo.last.value)" :cx="geo.last.x" :cy="geo.last.y" r="5.5">
      <title>{{ geo.last.label }}: {{ signedMoney(geo.last.value) }}</title>
    </circle>

    <text :x="PAD.left" :y="H - 8" text-anchor="start">{{ geo.coords[0].label }}</text>
    <text :x="W - PAD.right" :y="H - 8" text-anchor="end">{{ geo.last.label }}</text>
  </svg>
</template>
