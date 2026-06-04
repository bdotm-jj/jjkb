/**
 * confluence-sync.js
 * Syncs scoped Confluence pages into Supabase with taxonomy classification.
 * Runs as a GitHub Actions cron job (daily at 6am UTC).
 *
 * Required environment variables:
 *   CONFLUENCE_BASE_URL   e.g. https://jjconnect.atlassian.net
 *   CONFLUENCE_EMAIL      your Atlassian account email
 *   CONFLUENCE_API_TOKEN  Atlassian API token (not your password)
 *   SUPABASE_URL          e.g. https://xxxx.supabase.co
 *   SUPABASE_SERVICE_KEY  service role key (not the anon key)
 */

const https = require('https')

// ─── CONFIG ──────────────────────────────────────────────────────────────────

const CONFLUENCE_BASE_URL = process.env.CONFLUENCE_BASE_URL
const CONFLUENCE_AUTH = Buffer.from(
  `${process.env.CONFLUENCE_EMAIL}:${process.env.CONFLUENCE_API_TOKEN}`
).toString('base64')

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY

// ─── SYNC SCOPE ──────────────────────────────────────────────────────────────
// Explicit page IDs to sync. Add new pages here as scope expands.

const PERSONAL_SPACE_PAGES = [
  '3219259513', // PMO SOP Unified v15.1 Draft
  '3696164868', // Smartsheet Project Status Update Standards
  '3697377281', // Smartsheet RAID Log Standards
  '3700719618', // Data Reporting Team — PM SOP
  '3704619009', // LOB Pod Structure — Team Directory
  '3705470978', // QA Operating Model — QA Guide
]

// DEV space: hub + governance only (no sprint records, no indexes, no templates)
const DEV_SPACE_PAGES = [
  '3709304833', // Dev Ops Sprint & Institutional Memory Hub
  '3708485667', // Sprint Captain Rotation Schedule
  '3710615576', // Sprint Captain Quick Reference
  '3708551209', // MSCR Log — All Pods
  '3708715010', // CL Pod Hub (Commercial Lines)
  '3709337601', // Flood Pod Hub
  '3708551171', // Motion Pod Hub
  '3709370369', // PL Pod Hub (Personal Lines)
  '3708485648', // Program Pod Hub
  '3708321794', // New Market Capacity Pod Hub
  '3709435905', // Stabilization and Compliance Pod Hub
  '3709468673', // Architecture and Tech Initiatives Hub
]

const ALL_PAGE_IDS = [...PERSONAL_SPACE_PAGES, ...DEV_SPACE_PAGES]

// ─── EXCLUDE PATTERNS ────────────────────────────────────────────────────────
// Safety net — if a page ID ever produces one of these titles, skip it.

const EXCLUDE_PATTERNS = [
  title => title.includes('TEMPLATE'),
  title => title.includes('Sprint Index'),
  title => title.includes('PTO Calendar'),
  title => /Sprint \d+.*\d{4}-\d{2}-\d{2}/.test(title),
  title => title.includes('[Pod Name]'),
]

function shouldExclude(title) {
  return EXCLUDE_PATTERNS.some(fn => fn(title))
}

// ─── TAXONOMY ────────────────────────────────────────────────────────────────

const DOMAIN_MAP = {
  '~7120201b68ac6b3ece484297ce13489a5f9603': 'PMO', // personal space
  'DEV': 'Engineering',
  'DIT': 'PMO',
  'DP':  'Data & Product',
  'PL1': 'PL Pod',
}

const POD_KEYWORDS = {
  'data reporting': 'Data Reporting',
  'architecture':   'Architecture',
  'flood':          'Flood',
  'motion':         'Motion',
  'cl pod':         'CL',
  'commercial':     'CL',
  'pl pod':         'PL',
  'personal lines': 'PL',
  'program':        'Program',
  'new market':     'New Market Capacity',
  'stabilization':  'Stabilization',
}

function classifyDocument(page) {
  const title  = page.title.toLowerCase()
  const labels = (page.metadata?.labels?.results || []).map(l => l.name.toLowerCase())
  const spaceKey = page.space?.key || ''

  // doc_type
  let doc_type = null

  if (title.includes('sop') || labels.includes('sop'))
    doc_type = 'SOP'
  else if (title.includes('how to') || title.includes('guide') || labels.includes('how-to'))
    doc_type = 'How To'
  else if (title.includes('standard') || labels.includes('standard'))
    doc_type = 'Standard'
  else if (
    title.includes('hub') ||
    title.includes('index') ||
    title.includes('directory') ||
    title.includes('log') ||
    title.includes('rotation') ||
    title.includes('reference') ||
    labels.includes('reference')
  )
    doc_type = 'Reference'
  else if (labels.includes('training'))
    doc_type = 'Training'

  // domain
  const domain = DOMAIN_MAP[spaceKey] || null

  // pod
  let pod = null
  for (const [keyword, podName] of Object.entries(POD_KEYWORDS)) {
    if (title.includes(keyword)) {
      pod = podName
      break
    }
  }

  // sub_type (DEV-specific granularity)
  let sub_type = null
  if (title.includes('hub'))                  sub_type = 'Pod Hub'
  else if (title.includes('mscr'))            sub_type = 'MSCR Log'
  else if (title.includes('sprint captain'))  sub_type = 'Sprint Operations'
  else if (title.includes('rotation'))        sub_type = 'Sprint Operations'

  return { doc_type, domain, pod, sub_type }
}

function buildFlagReason(doc_type, domain) {
  const reasons = []
  if (!doc_type) reasons.push('doc_type could not be determined')
  if (!domain)   reasons.push('domain could not be determined')
  return reasons.join('; ')
}

// ─── HTML STRIPPING ──────────────────────────────────────────────────────────

function stripHtml(html) {
  if (!html) return ''
  return html
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

// ─── HTTP HELPERS ─────────────────────────────────────────────────────────────

function request(url, options = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, options, res => {
      let data = ''
      res.on('data', chunk => data += chunk)
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) })
        } catch {
          resolve({ status: res.statusCode, body: data })
        }
      })
    })
    req.on('error', reject)
    if (options.body) req.write(options.body)
    req.end()
  })
}

function confluenceGet(path) {
  const url = `${CONFLUENCE_BASE_URL}/wiki/rest/api${path}`
  return request(url, {
    method: 'GET',
    headers: {
      'Authorization': `Basic ${CONFLUENCE_AUTH}`,
      'Accept': 'application/json',
    },
  })
}

function supabaseUpsert(table, rows) {
  const url = `${SUPABASE_URL}/rest/v1/${table}`
  const body = JSON.stringify(Array.isArray(rows) ? rows : [rows])
  return request(url, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    },
    body,
  })
}

function supabaseInsert(table, row) {
  const url = `${SUPABASE_URL}/rest/v1/${table}`
  const body = JSON.stringify(row)
  return request(url, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    },
    body,
  })
}

// ─── FETCH CONFLUENCE PAGE ────────────────────────────────────────────────────

async function fetchPage(pageId) {
  const res = await confluenceGet(
    `/content/${pageId}?expand=body.storage,space,metadata.labels,version,history`
  )
  if (res.status !== 200) {
    throw new Error(`Confluence API error ${res.status} for page ${pageId}`)
  }
  return res.body
}

// ─── MAIN SYNC ────────────────────────────────────────────────────────────────

async function sync() {
  const startedAt = new Date().toISOString()
  console.log(`\n── Confluence → Supabase Sync ──────────────────────────`)
  console.log(`Started: ${startedAt}`)
  console.log(`Pages in scope: ${ALL_PAGE_IDS.length}`)

  const stats = {
    synced: 0,
    flagged: 0,
    skipped: 0,
    failed: 0,
    errors: [],
  }

  for (const pageId of ALL_PAGE_IDS) {
    try {
      console.log(`\nFetching page ${pageId}...`)
      const page = await fetchPage(pageId)
      const title = page.title

      // Exclude check
      if (shouldExclude(title)) {
        console.log(`  SKIPPED (exclude pattern): ${title}`)
        stats.skipped++
        continue
      }

      const { doc_type, domain, pod, sub_type } = classifyDocument(page)
      const bodyHtml  = page.body?.storage?.value || ''
      const bodyText  = stripHtml(bodyHtml)
      const tags      = (page.metadata?.labels?.results || []).map(l => l.name)
      const owner     = page.history?.createdBy?.displayName || null
      const spaceKey  = page.space?.key || null
      const lastUpdated = page.version?.when || null
      const webUrl    = `${CONFLUENCE_BASE_URL}/wiki${page._links?.webui || ''}`

      // Can't classify — send to review queue
      if (!doc_type || !domain) {
        const flagReason = buildFlagReason(doc_type, domain)
        console.log(`  FLAGGED: ${title} — ${flagReason}`)

        await supabaseUpsert('sync_review_queue', {
          confluence_id: pageId,
          space_key:     spaceKey,
          title,
          url:           webUrl,
          reason:        flagReason,
          flagged_at:    new Date().toISOString(),
          resolved:      false,
        })

        stats.flagged++
        continue
      }

      // Full upsert into documents
      const doc = {
        confluence_id: pageId,
        space_key:     spaceKey,
        title,
        body:          bodyText,
        body_html:     bodyHtml,
        url:           webUrl,
        parent_id:     page.ancestors?.[page.ancestors.length - 1]?.id || null,
        doc_type,
        domain,
        pod:           pod || null,
        sub_type:      sub_type || null,
        tags,
        owner,
        last_updated:  lastUpdated,
        synced_at:     new Date().toISOString(),
      }

      const result = await supabaseUpsert('documents', doc)

      if (result.status >= 200 && result.status < 300) {
        console.log(`  ✓ Synced [${doc_type}/${domain}]: ${title}`)
        stats.synced++
      } else {
        throw new Error(`Supabase upsert failed: ${JSON.stringify(result.body)}`)
      }

      // Small delay to avoid rate limiting
      await new Promise(r => setTimeout(r, 200))

    } catch (err) {
      console.error(`  ✗ FAILED (${pageId}): ${err.message}`)
      stats.failed++
      stats.errors.push({ pageId, error: err.message })
    }
  }

  // Write sync log
  const completedAt = new Date().toISOString()
  const status = stats.failed > 0 && stats.synced === 0
    ? 'failed'
    : stats.failed > 0 || stats.flagged > 0
      ? 'partial'
      : 'success'

  await supabaseInsert('sync_log', {
    space_key:     'ALL',
    started_at:    startedAt,
    completed_at:  completedAt,
    pages_synced:  stats.synced,
    pages_flagged: stats.flagged,
    pages_failed:  stats.failed,
    status,
    error:         stats.errors.length > 0 ? JSON.stringify(stats.errors) : null,
  })

  console.log(`\n── Summary ─────────────────────────────────────────────`)
  console.log(`  Synced:  ${stats.synced}`)
  console.log(`  Flagged: ${stats.flagged}`)
  console.log(`  Skipped: ${stats.skipped}`)
  console.log(`  Failed:  ${stats.failed}`)
  console.log(`  Status:  ${status}`)
  console.log(`  Completed: ${completedAt}\n`)

  if (stats.failed > 0) process.exit(1)
}

sync().catch(err => {
  console.error('Fatal sync error:', err)
  process.exit(1)
})
