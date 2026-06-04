// Supabase REST API client for JJ Insurance Knowledge Base
const SUPABASE_URL = 'https://jmzemnxdsijwdnmtyylj.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImptemVtbnhkc2lqd2RubXR5eWxqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1NjcwNDIsImV4cCI6MjA5NjE0MzA0Mn0.nm3TiAy26lkW4FSvB6a16ccpwTACmx2eRX3FOBnDxYg'

const HEADERS = {
  apikey: SUPABASE_ANON_KEY,
  Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
}

async function sbFetch(path) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { headers: HEADERS })
  if (!res.ok) throw new Error(`Supabase error ${res.status}: ${await res.text()}`)
  return res.json()
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function slugify(str) {
  return (str || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
}

function formatDate(ts) {
  if (!ts) return ''
  return new Date(ts).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

function relativeTime(ts) {
  if (!ts) return ''
  const diff = Date.now() - new Date(ts).getTime()
  const mins = Math.floor(diff / 60000)
  const hours = Math.floor(mins / 60)
  const days = Math.floor(hours / 24)
  if (mins < 60) return `${mins}m ago`
  if (hours < 24) return `${hours}h ago`
  if (days === 1) return 'Yesterday'
  return formatDate(ts).replace(/,\s*\d{4}$/, '')
}

function standfirst(body) {
  if (!body) return ''
  const first = body.split(/[.!?]/)[0]
  return (first.length > 160 ? first.slice(0, 157) + '...' : first).trim()
}

function readTime(body) {
  if (!body) return 1
  return Math.ceil(body.split(/\s+/).length / 200)
}

function extractVersion(tags) {
  if (!tags) return 'v1.0'
  const v = tags.find(t => /^v\d/.test(t))
  return v || 'v1.0'
}

function deriveStatus(tags) {
  if (!tags) return 'live'
  const t = tags.map(x => x.toLowerCase())
  if (t.includes('hot')) return 'hot'
  if (t.includes('draft')) return 'draft'
  if (t.includes('review')) return 'review'
  return 'live'
}

function deriveChange(tags) {
  if (!tags) return 'minor'
  const t = tags.map(x => x.toLowerCase())
  if (t.includes('draft')) return 'draft'
  if (t.includes('major')) return 'major'
  return 'minor'
}

function extractSections(bodyHtml) {
  if (!bodyHtml) return []
  const matches = [...bodyHtml.matchAll(/<h2[^>]*>(.*?)<\/h2>/gi)]
  return matches.map(m => ({
    id: slugify(m[1].replace(/<[^>]+>/g, '')),
    label: m[1].replace(/<[^>]+>/g, ''),
  }))
}

function buildDocId(doc) {
  return `${doc.doc_type || 'DOC'}-${(doc.domain || '').replace(/[^A-Z]/gi, '').toUpperCase().slice(0, 3)}-${doc.confluence_id}`
}

// ── Public API ────────────────────────────────────────────────────────────────

async function getCategories() {
  const rows = await sbFetch('categories?select=*&order=num.asc')
  return rows.map(r => ({
    id: r.id,
    num: r.num,
    title: r.title,
    titleEm: r.title_em,
    sub: r.sub,
    count: r.count || 0,
    items: r.items || [],
  }))
}

async function getArticle(id) {
  const rows = await sbFetch(`documents?confluence_id=eq.${encodeURIComponent(id)}&select=*&limit=1`)
  if (!rows.length) return null
  const d = rows[0]

  const related = await sbFetch(
    `documents?domain=eq.${encodeURIComponent(d.domain)}&confluence_id=neq.${encodeURIComponent(id)}&select=confluence_id&limit=5`
  )

  return {
    id: d.confluence_id,
    title: d.title,
    standfirst: standfirst(d.body),
    category: d.domain,
    categoryId: slugify(d.domain),
    owner: d.owner || '',
    ownerInit: (d.owner || ' ')[0].toUpperCase(),
    version: extractVersion(d.tags),
    docId: buildDocId(d),
    status: deriveStatus(d.tags),
    updated: formatDate(d.last_updated),
    readTime: readTime(d.body),
    tags: d.tags || [],
    body: d.body_html || '',
    sections: extractSections(d.body_html),
    related: related.map(r => r.confluence_id),
  }
}

async function getDocumentIndex() {
  const rows = await sbFetch(
    'documents?select=confluence_id,title,domain,owner,last_updated,tags,doc_type&order=last_updated.desc'
  )
  return rows.map(d => ({
    _id: d.confluence_id,
    doc: buildDocId(d),
    title: d.title,
    cat: d.domain,
    owner: d.owner || '',
    ver: extractVersion(d.tags),
    updated: formatDate(d.last_updated),
    status: deriveStatus(d.tags),
  }))
}

async function getRecent(days = 30) {
  const since = new Date(Date.now() - days * 86400000).toISOString()
  let rows = await sbFetch(
    `documents?select=*&last_updated=gte.${since}&order=last_updated.desc`
  )
  // Fall back to the 10 most recently updated docs if nothing in the window
  if (!rows.length) {
    rows = await sbFetch('documents?select=*&order=last_updated.desc&limit=10')
  }
  return rows.map(d => ({
    _id: d.confluence_id,
    when: relativeTime(d.last_updated),
    title: d.title,
    note: (d.body || '').slice(0, 80),
    cat: d.domain,
    author: d.owner || '',
    authorInit: (d.owner || ' ')[0].toUpperCase(),
    change: deriveChange(d.tags),
  }))
}

async function search(query, category = '') {
  if (!query.trim()) return []

  let rows
  try {
    let path = `documents?select=confluence_id,title,body,domain,doc_type,tags,last_updated&fts=body.fts.${encodeURIComponent(query)}`
    if (category && category !== 'All') path += `&domain=ilike.*${encodeURIComponent(category)}*`
    rows = await sbFetch(path)
  } catch {
    let path = `documents?select=confluence_id,title,body,domain,doc_type,tags,last_updated&or=(title.ilike.*${encodeURIComponent(query)}*,body.ilike.*${encodeURIComponent(query)}*)`
    if (category && category !== 'All') path += `&domain=ilike.*${encodeURIComponent(category)}*`
    rows = await sbFetch(path)
  }

  const re = new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi')

  return rows.slice(0, 20).map((d, i) => {
    const bodyText = d.body || ''
    const idx = bodyText.toLowerCase().indexOf(query.toLowerCase())
    const start = Math.max(0, idx === -1 ? 0 : idx - 40)
    const snippet = bodyText.slice(start, start + 120)

    return {
      idx: String(i + 1).padStart(2, '0'),
      title: d.title.replace(re, '<mark>$1</mark>'),
      snippet: snippet.replace(re, '<mark>$1</mark>'),
      crumbs: `${d.domain} · ${d.doc_type} · ${buildDocId(d)}`,
      meta: `${extractVersion(d.tags)} · ${formatDate(d.last_updated)}`,
      score: `${Math.max(50, 99 - i * 7)}%`,
      _id: d.confluence_id,
    }
  })
}

window.SupabaseAPI = { getCategories, getArticle, getDocumentIndex, getRecent, search }
