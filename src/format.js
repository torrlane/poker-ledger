// To change currency, edit the two values in this formatter.
const gbp = new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'GBP' })
const SYMBOL = '£'

export const num = (v) => Number(v) || 0
export const round2 = (n) => Math.round(n * 100) / 100

export const money = (v) => gbp.format(num(v))

export function signedMoney(v) {
  const n = num(v)
  if (Math.abs(n) < 0.005) return gbp.format(0)
  return (n > 0 ? '+' : '−') + gbp.format(Math.abs(n))
}

// Drops the pence on whole amounts (£20, £20.50). Used where space is tight.
export function chipMoney(v) {
  const cents = Math.round(Math.abs(num(v)) * 100)
  return cents % 100 === 0 ? `${SYMBOL}${cents / 100}` : `${SYMBOL}${(cents / 100).toFixed(2)}`
}

// 'pos', 'neg' or 'zero', for colouring amounts.
export const tone = (v) => (num(v) > 0.005 ? 'pos' : num(v) < -0.005 ? 'neg' : 'zero')

function toDate(d) {
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(`${d}T00:00:00`) : new Date(d)
}

export const formatDate = (d) =>
  toDate(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })

export const formatShortDate = (d) =>
  toDate(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: '2-digit' })

// Today's date as YYYY-MM-DD in the browser's own time zone.
export const todayISO = () => new Date().toLocaleDateString('en-CA')

export const plural = (n, word) => `${n} ${word}${n === 1 ? '' : 's'}`
