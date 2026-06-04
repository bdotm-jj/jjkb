// Static constants — not fetched from Supabase
const MARQUEE_WORDS = [
  'procedure', 'standard', 'version', 'reviewed', 'approved',
  'archived', 'indexed', 'current', 'filed', 'revised', 'noted', 'actioned',
]

const WEIRD_QUOTES = [
  '"Procedure is the couture of operations." — a memo, 2026',
  '"Every SOP is a love letter to the next person on call."',
  '"We make the boring legible. That is the whole discipline."',
]

// Runtime KB_DATA — null until loadKBData() resolves
let KB_DATA = null

async function loadKBData() {
  const { getCategories, getDocumentIndex, getRecent } = window.SupabaseAPI
  const [categories, table_index, recent] = await Promise.all([
    getCategories(),
    getDocumentIndex(),
    getRecent(30),
  ])
  KB_DATA = {
    categories,
    table_index,
    recent,
    marquee_words: MARQUEE_WORDS,
    weird_quotes: WEIRD_QUOTES,
  }
  window.KB_DATA = KB_DATA
}

window.KB_DATA = null
window.KB_STATIC = { MARQUEE_WORDS, WEIRD_QUOTES }
window.KB_Loader = { loadKBData }
