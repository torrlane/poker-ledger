<script setup>
import { computed } from 'vue'
import { chipMoney, num } from '../format'

// A poker chip showing what someone owes (red), is owed (green) or has settled (blue).
const props = defineProps({
  amount: { type: [Number, String], required: true },
  size: { type: Number, default: 96 },
})

const state = computed(() => {
  const n = num(props.amount)
  return n > 0.005 ? 'owed' : n < -0.005 ? 'owes' : 'even'
})

const text = computed(() => (state.value === 'even' ? '£0' : chipMoney(props.amount)))

const label = computed(() =>
  state.value === 'owed'
    ? `Owed ${text.value}`
    : state.value === 'owes'
      ? `Owes ${text.value}`
      : 'Settled up',
)

// Longer amounts get smaller type so they stay inside the chip's inner ring.
const scale = computed(() => (text.value.length > 6 ? 0.155 : text.value.length > 4 ? 0.19 : 0.23))
</script>

<template>
  <span
    class="chip"
    :class="state"
    :style="{ '--size': size + 'px', '--fs': scale }"
    role="img"
    :aria-label="label"
  >
    <span class="chip-value" aria-hidden="true">{{ text }}</span>
  </span>
</template>
