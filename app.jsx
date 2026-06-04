/* global React, ReactDOM */
const { useState, useEffect, useMemo, useRef } = React;

// ============================================================
// HELPERS
// ============================================================
const cx = (...a) => a.filter(Boolean).join(" ");

function useBookmarks() {
  const [ids, setIds] = useState(() => {
    try { return JSON.parse(localStorage.getItem("jj_kb_bookmarks") || "[]"); }
    catch { return []; }
  });
  useEffect(() => {
    localStorage.setItem("jj_kb_bookmarks", JSON.stringify(ids));
  }, [ids]);
  const toggle = (id) => setIds(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);
  const has = (id) => ids.includes(id);
  return { ids, toggle, has };
}

const Icon = {
  search: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <circle cx="11" cy="11" r="7"/><path d="m21 21-4.35-4.35"/>
    </svg>
  ),
  bookmark: (filled) => (
    <svg width="14" height="16" viewBox="0 0 24 24" fill={filled ? "currentColor" : "none"} stroke="currentColor" strokeWidth="1.8">
      <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
    </svg>
  ),
  arrow: () => (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <path d="M5 12h14M13 6l6 6-6 6"/>
    </svg>
  ),
  bell: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
      <path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>
    </svg>
  ),
  plus: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <path d="M12 5v14M5 12h14"/>
    </svg>
  ),
  sliders: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
      <path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>
    </svg>
  ),
};

// ============================================================
// LOADING SCREEN
// ============================================================
function LoadingScreen() {
  return (
    <div style={{
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      height: "100vh",
      fontFamily: "var(--grotesk)",
      color: "var(--ink-3)",
      fontSize: 13,
      letterSpacing: "0.08em",
    }}>
      <span className="mono">Loading archive…</span>
    </div>
  );
}

// ============================================================
// CHROME: TOPBAR + SIDEBAR
// ============================================================
function TopBar({ onSearchNav, onOpenTweaks, currentScreen }) {
  return (
    <header className="topbar">
      <div className="brand">
        <img src="assets/jj-logo.png" alt="Johnson & Johnson" className="brand-logo"/>
        <small>Knowledge Base</small>
      </div>
      <div className="topbar-search" onClick={onSearchNav}>
        <span className="sicon"><Icon.search/></span>
        <input
          readOnly
          placeholder="Search the archive — SOPs, runbooks, role charters…"
          onFocus={onSearchNav}
        />
        <span className="kbd">⌘K</span>
      </div>
      <div className="topbar-right">
        <button className="icon-btn" title="Notifications"><Icon.bell/></button>
        <button className="icon-btn" title="Tweaks" onClick={onOpenTweaks}><Icon.sliders/></button>
        <div className="avatar" title="Jin"><em>J</em></div>
      </div>
    </header>
  );
}

function Sidebar({ screen, setScreen, bookmarks }) {
  const cats = window.KB_DATA ? window.KB_DATA.categories : [];
  return (
    <aside className="sidebar">
      <div className="nav-group">
        <h4>Library</h4>
        <div className={cx("nav-item", screen === "home" && "active")} onClick={() => setScreen("home")}>
          <span className="dot"/> Home
        </div>
        <div className={cx("nav-item", screen === "browse" && "active")} onClick={() => setScreen("browse")}>
          <span className="dot"/> Categories
        </div>
        <div className={cx("nav-item", screen === "recent" && "active")} onClick={() => setScreen("recent")}>
          <span className="dot"/> Recently updated
        </div>
        <div className={cx("nav-item", screen === "search" && "active")} onClick={() => setScreen("search")}>
          <span className="dot"/> Search
        </div>
      </div>

      <div className="nav-group">
        <h4>Personal</h4>
        <div className={cx("nav-item")}>
          <span className="dot"/> Bookmarks
          <span className="count">{String(bookmarks.ids.length).padStart(2, "0")}</span>
        </div>
        <div className="nav-item"><span className="dot"/> My drafts <span className="count">03</span></div>
        <div className="nav-item"><span className="dot"/> Assigned to me <span className="count">02</span></div>
      </div>

      <div className="nav-group">
        <h4>Categories</h4>
        {cats.map(c => (
          <div key={c.id} className="nav-item" onClick={() => setScreen("category:" + c.id)}>
            <span className="dot"/> {c.title}
            <span className="count">{c.count}</span>
          </div>
        ))}
      </div>

      <div className="nav-group">
        <h4>Admin</h4>
        <div className={cx("nav-item", screen === "edit" && "active")} onClick={() => setScreen("edit")}>
          <span className="dot"/> Edit an article
        </div>
      </div>
    </aside>
  );
}

// ============================================================
// BOOKMARK BUTTON
// ============================================================
function BookmarkBtn({ id, bookmarks, className }) {
  const saved = bookmarks.has(id);
  return (
    <button
      className={cx("bookmark-btn", saved && "saved", className)}
      onClick={(e) => { e.stopPropagation(); bookmarks.toggle(id); }}
      title={saved ? "Remove bookmark" : "Bookmark"}
    >
      {Icon.bookmark(saved)}
    </button>
  );
}

// ============================================================
// HERO (HOME)
// ============================================================
function HomeHero() {
  const today = new Date().toLocaleDateString("en-US", { weekday: "long", year: "numeric", month: "long", day: "numeric" });
  return (
    <div className="hero">
      <div className="hero-top">
        <div className="eyebrow">
          <span>Vol. XII</span>
          <span>No. 04</span>
          <span>Q2 — 2026</span>
        </div>
        <div className="dateline">{today} · Newark, NJ</div>
      </div>
      <h1>An archive <em>of</em>  the work,<br/>for the people doing the work.</h1>
      <p className="deck">
        One source of truth for standard operating procedures across Claims, Underwriting, Product, Engineering,
        Quality and People. Indexed, versioned, and quietly opinionated.
      </p>
    </div>
  );
}

// ============================================================
// CARDS
// ============================================================
function FeaturedCard({ bookmarks, onOpen }) {
  const id = "sop-fnol-2026";
  return (
    <div className="card feature" onClick={onOpen}>
      <BookmarkBtn id={id} bookmarks={bookmarks} />
      <div className="cat">Featured · Claims · SOP-CLM-0041</div>
      <h3>The First Notice of Loss procedure, revised for Q2.</h3>
      <p>
        A canonical re-read of the front door of every claim — now with updated cat-event windows,
        channel-parity compliance, and new escalation paths for injury-involved reports.
      </p>
      <div className="meta-row">
        <span>8 min read · v4.2</span>
        <span>Updated Apr 18, 2026</span>
      </div>
    </div>
  );
}

function ArticleCard({ card, bookmarks, onOpen }) {
  return (
    <div className="card" onClick={onOpen}>
      <BookmarkBtn id={card.id} bookmarks={bookmarks} />
      <div className="cat">{card.cat}</div>
      <h3>{card.title}</h3>
      <p>{card.blurb}</p>
      <div className="meta-row">
        <span>{card.read}</span>
        <span>{card.date}</span>
      </div>
    </div>
  );
}

// ============================================================
// SCREEN: HOME
// ============================================================
function HomeScreen({ bookmarks, setScreen, weirdness }) {
  const data = window.KB_DATA;
  const cards = [
    { id: "c1", cat: "Engineering · Runbooks", title: "Sev 1 incident response, end to end.", blurb: "Declaration, commander assignment, comms cadence, post-mortem. For any platform event with customer impact.", read: "12 min read · v6.0", date: "Apr 07, 2026" },
    { id: "c2", cat: "Underwriting · Appetite", title: "Commercial Auto, revised appetite.", blurb: "Three class codes retired. Hazmat haulers routed through specialty intake. Effective immediately.", read: "6 min read · v2.4", date: "Apr 09, 2026" },
    { id: "c3", cat: "Quality · Release", title: "Post-release regression — the short version.", blurb: "The weekly QA gate: E2E coverage, performance thresholds, and the rollback ladder.", read: "5 min read · v1.8", date: "Apr 03, 2026" },
  ];

  // First row in the index becomes the article-reader target
  const firstDocId = data && data.table_index.length ? data.table_index[0].doc : null;
  const openFirst = () => {
    if (firstDocId) {
      // strip prefix to get confluence_id — stored as last segment after final dash pair
      // We stored the raw confluence_id in _id; fall back to table row lookup
      const row = data.table_index[0];
      setScreen("article:" + row._id);
    }
  };

  return (
    <div className="screen">
      <HomeHero/>

      <div className="section-head">
        <h2 className="section-title">Featured this week</h2>
        <div className="meta">Curated · Editors</div>
      </div>
      <div className="grid-3" style={{ marginBottom: 56 }}>
        <FeaturedCard bookmarks={bookmarks} onOpen={openFirst}/>
        <ArticleCard card={cards[0]} bookmarks={bookmarks} onOpen={openFirst}/>
      </div>

      <div className="section-head">
        <h2 className="section-title">Recently revised</h2>
        <div className="meta">Last 30 days · <a href="#" onClick={(e)=>{e.preventDefault(); setScreen("recent");}}>See all →</a></div>
      </div>
      <div className="grid-3" style={{ marginBottom: 56 }}>
        {cards.map(c => (
          <ArticleCard key={c.id} card={c} bookmarks={bookmarks} onOpen={openFirst}/>
        ))}
      </div>

      <div className="section-head">
        <h2 className="section-title">The index</h2>
        <div className="meta">All SOPs · <a href="#" onClick={(e)=>{e.preventDefault(); setScreen("browse");}}>Browse categories →</a></div>
      </div>
      <table className="index-table">
        <thead>
          <tr>
            <th style={{ width: 130 }}>Doc ID</th>
            <th>Title</th>
            <th style={{ width: 140 }}>Owner</th>
            <th style={{ width: 80 }}>Version</th>
            <th style={{ width: 120 }}>Updated</th>
            <th style={{ width: 100 }}>Status</th>
          </tr>
        </thead>
        <tbody>
          {data && data.table_index.map(r => (
            <tr key={r.doc} onClick={() => r._id && setScreen("article:" + r._id)}>
              <td className="mono-cell">{r.doc}</td>
              <td className="doc">{r.title}<small>{r.cat}</small></td>
              <td>{r.owner}</td>
              <td className="mono-cell num">{r.ver}</td>
              <td className="mono-cell">{r.updated}</td>
              <td><span className={cx("pill", r.status)}>{r.status}</span></td>
            </tr>
          ))}
        </tbody>
      </table>

      <MarqueeFooter weirdness={weirdness}/>
    </div>
  );
}

// ============================================================
// SCREEN: CATEGORIES BROWSE
// ============================================================
function BrowseScreen({ setScreen, weirdness }) {
  const [hovered, setHovered] = useState(null);
  const data = window.KB_DATA;
  return (
    <div className="screen">
      <div className="crumbs-nav">
        <a href="#" onClick={(e)=>{e.preventDefault(); setScreen("home");}}>Home</a>
        <span className="sep">/</span>
        <span>Categories</span>
      </div>

      <div className="hero" style={{ paddingBottom: 28, marginBottom: 32 }}>
        <div className="hero-top">
          <div className="eyebrow"><span>Browse</span><span>All departments</span><span>{data ? data.categories.length : 0} categories</span></div>
        </div>
        <h1 style={{ fontSize: "clamp(40px, 5vw, 68px)" }}>The department <em>index</em>.</h1>
        <p className="deck">Six departments, six languages, one shared operating system. Open any shelf.</p>
      </div>

      <div className="cat-grid">
        {data && data.categories.map(c => (
          <div
            key={c.id}
            className="cat-tile"
            onClick={() => setScreen("category:" + c.id)}
            onMouseEnter={() => setHovered(c.id)}
            onMouseLeave={() => setHovered(null)}
          >
            <div className="cat-num">{c.num} — {c.count.toString().padStart(3, "0")} documents</div>
            <h3>{c.title} <em>{c.titleEm}</em></h3>
            <p className="cat-sub">{c.sub}</p>
            <ul className="cat-items">
              {c.items.filter(Boolean).map(i => <li key={i}>{i}</li>)}
            </ul>
            <div className="arrow"><Icon.arrow/></div>
          </div>
        ))}
      </div>

      <MarqueeFooter weirdness={weirdness}/>
    </div>
  );
}

// ============================================================
// SCREEN: CATEGORY DETAIL
// ============================================================
function CategoryScreen({ categoryId, setScreen, bookmarks, weirdness }) {
  const data = window.KB_DATA;
  if (!data) return null;
  const cat = data.categories.find(c => c.id === categoryId);
  if (!cat) return null;
  const rows = data.table_index.filter(r => (r.cat || '').toLowerCase().includes(cat.title.toLowerCase()));

  return (
    <div className="screen">
      <div className="crumbs-nav">
        <a href="#" onClick={(e)=>{e.preventDefault(); setScreen("home");}}>Home</a>
        <span className="sep">/</span>
        <a href="#" onClick={(e)=>{e.preventDefault(); setScreen("browse");}}>Categories</a>
        <span className="sep">/</span>
        <span>{cat.title}</span>
      </div>

      <div className="hero">
        <div className="hero-top">
          <div className="eyebrow">
            <span>Department {cat.num}</span>
            <span>{cat.count} documents</span>
            <span>Updated daily</span>
          </div>
        </div>
        <h1>{cat.title} <em>{cat.titleEm}</em></h1>
        <p className="deck">{cat.sub}</p>
      </div>

      <div className="section-head">
        <h2 className="section-title">All {cat.title.toLowerCase()} documents</h2>
        <div className="meta">{rows.length} showing · Sorted by recent</div>
      </div>

      {rows.length > 0 ? (
        <table className="index-table">
          <thead>
            <tr>
              <th style={{ width: 130 }}>Doc ID</th>
              <th>Title</th>
              <th style={{ width: 140 }}>Owner</th>
              <th style={{ width: 80 }}>Version</th>
              <th style={{ width: 120 }}>Updated</th>
              <th style={{ width: 100 }}>Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(r => (
              <tr key={r.doc} onClick={() => r._id && setScreen("article:" + r._id)}>
                <td className="mono-cell">{r.doc}</td>
                <td className="doc">{r.title}</td>
                <td>{r.owner}</td>
                <td className="mono-cell num">{r.ver}</td>
                <td className="mono-cell">{r.updated}</td>
                <td><span className={cx("pill", r.status)}>{r.status}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      ) : (
        <div className="empty-state">
          <h3>Nothing filed yet in {cat.title.toLowerCase()}.</h3>
          <p>When a document is published, it arrives here. Until then, this shelf is deliberate about its emptiness.</p>
        </div>
      )}

      <MarqueeFooter weirdness={weirdness}/>
    </div>
  );
}

// ============================================================
// SCREEN: ARTICLE (async)
// ============================================================
function ArticleScreen({ articleId, bookmarks, setScreen, weirdness }) {
  const [article, setArticle] = useState(null);
  const [loading, setLoading] = useState(true);
  const [helpful, setHelpful] = useState(null);

  useEffect(() => {
    setLoading(true);
    setArticle(null);
    window.SupabaseAPI.getArticle(articleId)
      .then(a => { setArticle(a); setLoading(false); })
      .catch(() => setLoading(false));
  }, [articleId]);

  if (loading) {
    return (
      <div className="screen" style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: 300 }}>
        <span className="mono ink-3">Loading document…</span>
      </div>
    );
  }

  if (!article) {
    return (
      <div className="screen">
        <div className="empty-state">
          <h3>Document not found.</h3>
          <p>This document may have been moved or removed from the archive.</p>
        </div>
      </div>
    );
  }

  const weirdQuote = window.KB_STATIC.WEIRD_QUOTES[0];

  return (
    <div className="screen">
      <div className="crumbs-nav">
        <a href="#" onClick={(e)=>{e.preventDefault(); setScreen("home");}}>Home</a>
        <span className="sep">/</span>
        <a href="#" onClick={(e)=>{e.preventDefault(); setScreen("category:" + article.categoryId);}}>{article.category}</a>
        <span className="sep">/</span>
        <span>{article.docId}</span>
      </div>

      <div className="article-wrap">
        <aside className="article-toc">
          <h5>Contents</h5>
          {article.sections.map((s, i) => (
            <a key={s.id} href={"#" + s.id} className={i === 0 ? "active" : ""}>
              {String(i + 1).padStart(2, "0")} — {s.label}
            </a>
          ))}
        </aside>

        <main className="article-body">
          <div className="hero-top" style={{ marginBottom: 0 }}>
            <div className="eyebrow">
              <span>{article.category}</span>
              <span>{article.docId}</span>
              <span>v{article.version}</span>
            </div>
            <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
              <BookmarkBtn id={article.id} bookmarks={bookmarks} className="static"/>
              <span className={cx("pill", article.status)}>{article.status}</span>
            </div>
          </div>
          <h1>{article.title}</h1>
          <p className="standfirst">{article.standfirst}</p>

          <div dangerouslySetInnerHTML={{ __html: article.body }}/>

          <div style={{ marginTop: 48, padding: "24px 0", borderTop: "1px solid var(--rule)", display: "flex", alignItems: "center", gap: 16 }}>
            <span className="eyebrow">Was this useful?</span>
            <button className={cx("btn", "sm", helpful === "yes" ? "" : "ghost")} onClick={() => setHelpful("yes")}>Yes</button>
            <button className={cx("btn", "sm", helpful === "no" ? "" : "ghost")} onClick={() => setHelpful("no")}>No</button>
            {helpful && <span className="ink-3" style={{ fontSize: 12, fontStyle: "italic", fontFamily: "var(--serif)" }}>— Noted. Your feedback goes to {article.owner}.</span>}
          </div>

          <span className="weird-quote">{weirdQuote}</span>
        </main>

        <aside className="article-meta">
          <div className="meta-block">
            <div className="edit-panel">
              <h5>Document metadata</h5>
              <div className="kv-row"><span className="k">Owner</span><span>{article.owner}</span></div>
              <div className="kv-row"><span className="k">Version</span><span>{article.version}</span></div>
              <div className="kv-row"><span className="k">Status</span><span>{article.status}</span></div>
              <div className="kv-row"><span className="k">Updated</span><span>{article.updated}</span></div>
              <div className="kv-row"><span className="k">Read</span><span>{article.readTime} min</span></div>
              <div className="kv-row"><span className="k">Doc ID</span><span>{article.docId}</span></div>
            </div>
          </div>

          <div className="edit-panel">
            <h5>Tags</h5>
            <div className="tag-row">
              {article.tags.map(t => <span key={t} className="tag on">{t}</span>)}
            </div>
          </div>

          <div className="edit-panel">
            <h5>Related</h5>
            <div style={{ fontSize: 13, lineHeight: 1.6 }}>
              {article.related.map(id => (
                <a key={id} href="#" style={{ display: "block", padding: "4px 0" }} onClick={(e) => { e.preventDefault(); setScreen("article:" + id); }}>{id}</a>
              ))}
            </div>
          </div>

          <div className="meta-block weird-stamp" style={{ opacity: "calc(var(--weird))" }}>
            <div style={{
              border: "1.5px solid var(--accent)",
              color: "var(--accent)",
              padding: "16px",
              textAlign: "center",
              fontFamily: "var(--serif)",
              fontStyle: "italic",
              transform: "rotate(-2deg)"
            }}>
              <div style={{ fontFamily: "var(--mono)", fontSize: 9, letterSpacing: "0.16em", textTransform: "uppercase", marginBottom: 6 }}>Certified Useful</div>
              <div style={{ fontSize: 14 }}>filed with care</div>
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}

// ============================================================
// SCREEN: SEARCH (async)
// ============================================================
function SearchScreen({ setScreen, weirdness }) {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("All");
  const [results, setResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const filters = ["All", "PMO", "Engineering", "Data & Product", "PL Pod"];

  useEffect(() => {
    if (!query.trim()) { setResults([]); return; }
    const t = setTimeout(() => {
      setSearching(true);
      window.SupabaseAPI.search(query, filter === "All" ? "" : filter)
        .then(r => { setResults(r); setSearching(false); })
        .catch(() => setSearching(false));
    }, 300);
    return () => clearTimeout(t);
  }, [query, filter]);

  return (
    <div className="screen">
      <div className="crumbs-nav">
        <a href="#" onClick={(e)=>{e.preventDefault(); setScreen("home");}}>Home</a>
        <span className="sep">/</span>
        <span>Search</span>
      </div>

      <div className="search-query-bar">
        <span className="ink-4" style={{ fontFamily: "var(--serif)", fontSize: 36, fontStyle: "italic" }}>'</span>
        <input
          value={query}
          onChange={e => setQuery(e.target.value)}
          placeholder="What are you looking for?"
          autoFocus
        />
        <span className="mono" style={{ color: "var(--ink-3)" }}>
          {searching ? "Searching…" : `${results.length} found`}
        </span>
      </div>

      <div className="search-filter-row">
        {filters.map(f => (
          <button key={f} className={cx("filter-chip", filter === f && "active")} onClick={() => setFilter(f)}>
            {f}
          </button>
        ))}
      </div>

      {!query.trim() ? (
        <div className="empty-state">
          <h3>Start typing to search.</h3>
          <p>Full-text search across all SOPs, runbooks, and role charters.</p>
        </div>
      ) : results.length === 0 && !searching ? (
        <div className="empty-state">
          <h3>Nothing here. Try something else.</h3>
          <p>Or keep looking. The archive is wide.</p>
        </div>
      ) : (
        <div className="search-results">
          {results.map(r => (
            <div key={r.idx} className="result-row" onClick={() => r._id && setScreen("article:" + r._id)}>
              <span className="idx">№ {r.idx}</span>
              <div>
                <h4 dangerouslySetInnerHTML={{ __html: r.title }}/>
                <p dangerouslySetInnerHTML={{ __html: r.snippet }}/>
                <div className="crumbs">{r.crumbs}</div>
              </div>
              <div className="right-meta">
                <div style={{ color: "var(--accent)", fontWeight: 600 }}>{r.score}</div>
                <div>{r.meta}</div>
              </div>
            </div>
          ))}
        </div>
      )}

      <MarqueeFooter weirdness={weirdness}/>
    </div>
  );
}

// ============================================================
// SCREEN: RECENT FEED
// ============================================================
function RecentScreen({ setScreen, weirdness }) {
  const data = window.KB_DATA;
  return (
    <div className="screen">
      <div className="crumbs-nav">
        <a href="#" onClick={(e)=>{e.preventDefault(); setScreen("home");}}>Home</a>
        <span className="sep">/</span>
        <span>Recently updated</span>
      </div>

      <div className="hero" style={{ paddingBottom: 24 }}>
        <div className="hero-top">
          <div className="eyebrow"><span>Activity</span><span>Rolling 30 days</span><span>All departments</span></div>
        </div>
        <h1 style={{ fontSize: "clamp(40px, 5vw, 68px)" }}>What <em>changed</em>.</h1>
      </div>

      <div>
        {data && data.recent.map((r, i) => (
          <div key={i} className="feed-row" style={{ cursor: "pointer" }}>
            <span className="when">{r.when}</span>
            <div className="title">
              {r.title}
              <small dangerouslySetInnerHTML={{ __html: r.note }}/>
            </div>
            <div className="author">
              <span className="avatar-sm"><em>{r.authorInit}</em></span>
              {r.author} · <span className="mono ink-3">{r.cat}</span>
            </div>
            <span className={cx("pill", r.change === "major" ? "hot" : r.change === "draft" ? "draft" : "live")}>{r.change}</span>
          </div>
        ))}
      </div>

      <MarqueeFooter weirdness={weirdness}/>
    </div>
  );
}

// ============================================================
// SCREEN: ADMIN EDIT
// ============================================================
function EditScreen({ weirdness }) {
  const [title, setTitle] = useState("First Notice of Loss — Intake Procedure");
  const [standfirst, setStandfirst] = useState("The front door of every claim. Governs the first 72 hours of contact across phone, web, mobile, and partner referral.");
  const [saved, setSaved] = useState(true);
  const [tags, setTags] = useState(["intake", "fnol", "sla"]);
  const allTags = ["intake", "fnol", "sla", "cross-channel", "compliance", "catastrophe", "fraud"];

  const toggleTag = (t) => {
    setTags(prev => prev.includes(t) ? prev.filter(x => x !== t) : [...prev, t]);
    setSaved(false);
  };
  const onChangeAny = () => setSaved(false);
  useEffect(() => {
    if (!saved) {
      const t = setTimeout(() => setSaved(true), 1400);
      return () => clearTimeout(t);
    }
  }, [saved, title, standfirst, tags]);

  return (
    <div className="screen">
      <div className="crumbs-nav" style={{ justifyContent: "space-between" }}>
        <div style={{ display: "flex", gap: 10 }}>
          <span>Admin</span>
          <span className="sep">/</span>
          <span>Edit</span>
          <span className="sep">/</span>
          <span>SOP-CLM-0041</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <span className={cx("pill", saved ? "live" : "review")}>
            {saved ? "Saved" : "Saving…"}
          </span>
          <button className="btn ghost sm">Preview</button>
          <button className="btn sm">Publish revision</button>
        </div>
      </div>

      <div className="edit-wrap">
        <div className="editor-shell">
          <div className="editor-toolbar">
            <button className="ed-btn" title="Heading"><span style={{ fontFamily: "var(--serif)", fontSize: 14 }}>H</span></button>
            <button className="ed-btn w" title="Bold">B</button>
            <button className="ed-btn i" title="Italic">I</button>
            <button className="ed-btn u" title="Underline">U</button>
            <span className="ed-sep"/>
            <button className="ed-btn" title="List">≡</button>
            <button className="ed-btn" title="Numbered list">1.</button>
            <button className="ed-btn" title="Quote">"</button>
            <span className="ed-sep"/>
            <button className="ed-btn" title="Link">↗</button>
            <button className="ed-btn" title="Image">▦</button>
            <button className="ed-btn" title="Callout">✦</button>
            <span className="ed-sep"/>
            <span className="mono ink-3" style={{ marginLeft: "auto" }}>1,284 words · 8 min read</span>
          </div>

          <div className="editor-page">
            <span className="eyebrow">Claims · SOP-CLM-0041 · v4.2 (draft)</span>
            <input
              type="text"
              className="title-input"
              value={title}
              onChange={e => { setTitle(e.target.value); onChangeAny(); }}
            />
            <textarea
              className="standfirst-input"
              rows={2}
              value={standfirst}
              onChange={e => { setStandfirst(e.target.value); onChangeAny(); }}
            />

            <div className="ed-body" contentEditable suppressContentEditableWarning onInput={onChangeAny}>
              <p>First Notice of Loss, hereafter "FNOL", is the formal record of a reported incident that may give rise to a covered claim. It is the canonical system-of-record entry point.</p>
              <h3>Scope &amp; applicability</h3>
              <p>This SOP applies to all lines, all channels, and all business units operating under Johnson &amp; Johnson Insurance.</p>
              <h3>The procedure</h3>
              <p>Verify identity, capture loss facts, assign reference, route, close. Each step has acceptance criteria documented in Appendix A.</p>
              <p><em>Continue editing…</em></p>
            </div>
          </div>
        </div>

        <aside className="edit-side">
          <div className="edit-panel">
            <h5>Publishing</h5>
            <div className="field">
              <label>Status</label>
              <select defaultValue="draft">
                <option value="draft">Draft</option>
                <option value="review">In review</option>
                <option value="live">Live</option>
              </select>
            </div>
            <div className="field">
              <label>Version</label>
              <input type="text" defaultValue="4.3"/>
            </div>
            <div className="field">
              <label>Owner</label>
              <select defaultValue="KM">
                <option value="KM">K. Mbeki</option>
                <option value="DC">D. Cho</option>
                <option value="JA">J. Ayotte</option>
              </select>
            </div>
            <div className="field">
              <label>Review due</label>
              <input type="text" defaultValue="Jul 15, 2026"/>
            </div>
          </div>

          <div className="edit-panel">
            <h5>Tags</h5>
            <div className="tag-row">
              {allTags.map(t => (
                <span key={t} className={cx("tag", tags.includes(t) && "on")} onClick={() => toggleTag(t)}>{t}</span>
              ))}
            </div>
          </div>

          <div className="edit-panel">
            <h5>Revision history</h5>
            <div style={{ fontSize: 12 }}>
              <div className="kv-row"><span className="k">v4.2</span><span>Apr 18</span></div>
              <div className="kv-row"><span className="k">v4.1</span><span>Mar 02</span></div>
              <div className="kv-row"><span className="k">v4.0</span><span>Jan 11</span></div>
              <div className="kv-row"><span className="k">v3.8</span><span>Nov 22</span></div>
            </div>
          </div>
        </aside>
      </div>

      <MarqueeFooter weirdness={weirdness}/>
    </div>
  );
}

// ============================================================
// MARQUEE FOOTER
// ============================================================
function MarqueeFooter({ weirdness }) {
  const words = (window.KB_DATA && window.KB_DATA.marquee_words) || window.KB_STATIC.MARQUEE_WORDS;
  return (
    <div className="marquee-footer" style={{ ["--weird"]: weirdness / 100 }}>
      <div className="marquee-track">
        {[...words, ...words].map((w, i) => <span key={i}>{w}</span>)}
      </div>
    </div>
  );
}

// ============================================================
// TWEAKS PANEL
// ============================================================
function TweaksPanel({ open, onClose, palette, setPalette, weirdness, setWeirdness }) {
  const palettes = [
    { id: "bone",  name: "J&J Blue",  colors: ["#F2EDE2", "#0F1B2D", "#2E6DA4", "#A9C4DD"] },
    { id: "ink",   name: "Ink",   colors: ["#14130F", "#F2EDE0", "#4A8BC2", "#A9C4DD"] },
    { id: "cream", name: "Cream", colors: ["#F5F1E8", "#1A1A1A", "#2E6DA4", "#4A8BC2"] },
    { id: "navy",  name: "Navy",  colors: ["#1A1F2E", "#EADDC4", "#6BA3D1", "#A9C4DD"] },
    { id: "moss",  name: "Moss",  colors: ["#E4E4D8", "#1B1F15", "#4F5C2E", "#7B8A4A"] },
  ];

  return (
    <div className={cx("tweaks-panel", !open && "hidden")}>
      <div className="tweaks-header">
        <h4>Tweaks</h4>
        <button className="close" onClick={onClose}>×</button>
      </div>
      <div className="tweaks-body">
        <div className="tweak-row">
          <label>Palette</label>
          <div className="palette-swatches">
            {palettes.map(p => (
              <div
                key={p.id}
                className={cx("swatch", palette === p.id && "active")}
                onClick={() => setPalette(p.id)}
                title={p.name}
              >
                <span style={{ background: p.colors[0] }}/>
                <span style={{ background: p.colors[1] }}/>
                <span style={{ background: p.colors[2] }}/>
                <span style={{ background: p.colors[3] }}/>
              </div>
            ))}
          </div>
        </div>

        <div className="tweak-row">
          <label>Weirdness dial — {weirdness}</label>
          <input
            type="range" min="0" max="100" value={weirdness}
            className="weird-slider"
            onChange={e => setWeirdness(parseInt(e.target.value, 10))}
          />
          <div className="weird-readout">
            <span>Institutional</span>
            <span>Off the rack</span>
          </div>
        </div>
      </div>
    </div>
  );
}

// ============================================================
// APP
// ============================================================
const DEFAULT_TWEAKS = /*EDITMODE-BEGIN*/{
  "palette": "bone",
  "weirdness": 15
}/*EDITMODE-END*/;

function App() {
  const [loading, setLoading] = useState(true);
  const [screen, setScreen] = useState(() => {
    try { return localStorage.getItem("jj_kb_screen") || "home"; }
    catch { return "home"; }
  });
  const [palette, setPalette] = useState(DEFAULT_TWEAKS.palette);
  const [weirdness, setWeirdness] = useState(DEFAULT_TWEAKS.weirdness);
  const [tweaksOpen, setTweaksOpen] = useState(false);
  const bookmarks = useBookmarks();

  useEffect(() => {
    window.KB_Loader.loadKBData()
      .then(() => setLoading(false))
      .catch(() => setLoading(false));
  }, []);

  useEffect(() => { localStorage.setItem("jj_kb_screen", screen); }, [screen]);
  useEffect(() => { document.body.setAttribute("data-palette", palette); }, [palette]);
  useEffect(() => { document.body.style.setProperty("--weird", weirdness / 100); }, [weirdness]);

  useEffect(() => {
    function onMsg(e) {
      const d = e.data || {};
      if (d.type === "__activate_edit_mode") setTweaksOpen(true);
      if (d.type === "__deactivate_edit_mode") setTweaksOpen(false);
    }
    window.addEventListener("message", onMsg);
    window.parent.postMessage({ type: "__edit_mode_available" }, "*");
    return () => window.removeEventListener("message", onMsg);
  }, []);

  const persistTweaks = (edits) => {
    window.parent.postMessage({ type: "__edit_mode_set_keys", edits }, "*");
  };
  const changePalette = (p) => { setPalette(p); persistTweaks({ palette: p }); };
  const changeWeirdness = (w) => { setWeirdness(w); persistTweaks({ weirdness: w }); };

  if (loading) return <LoadingScreen/>;

  const [, categoryId] = screen.startsWith("category:") ? screen.split(":") : [null, null];
  const [, articleId] = screen.startsWith("article:") ? screen.split(":") : [null, null];

  let screenBase = screen;
  if (screen.startsWith("category:")) screenBase = "browse";
  if (screen.startsWith("article:")) screenBase = "article";

  const TABS = [
    { id: "home", label: "Home" },
    { id: "browse", label: "Categories" },
    { id: "article", label: "Article reader" },
    { id: "search", label: "Search" },
    { id: "recent", label: "Recent" },
    { id: "edit", label: "Admin — edit" },
  ];

  // pick the first real doc for the "Article reader" tab
  const firstDocId = window.KB_DATA && window.KB_DATA.table_index.length
    ? window.KB_DATA.table_index[0]._id
    : null;

  return (
    <div className="app">
      <TopBar
        onSearchNav={() => setScreen("search")}
        onOpenTweaks={() => setTweaksOpen(v => !v)}
        currentScreen={screen}
      />
      <Sidebar screen={screen} setScreen={setScreen} bookmarks={bookmarks}/>

      <div className="main">
        <div className="screen-tabs">
          {TABS.map(t => (
            <button
              key={t.id}
              className={cx(
                screenBase === t.id && "active",
              )}
              onClick={() => {
                if (t.id === "article" && firstDocId) setScreen("article:" + firstDocId);
                else setScreen(t.id);
              }}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className="main-inner" data-screen-label={screen}>
          {screenBase === "home"    && <HomeScreen    bookmarks={bookmarks} setScreen={setScreen} weirdness={weirdness}/>}
          {screenBase === "browse"  && !categoryId && <BrowseScreen setScreen={setScreen} weirdness={weirdness}/>}
          {categoryId &&                 <CategoryScreen categoryId={categoryId} setScreen={setScreen} bookmarks={bookmarks} weirdness={weirdness}/>}
          {articleId &&                  <ArticleScreen articleId={articleId} bookmarks={bookmarks} setScreen={setScreen} weirdness={weirdness}/>}
          {screenBase === "search"  && <SearchScreen  setScreen={setScreen} weirdness={weirdness}/>}
          {screenBase === "recent"  && <RecentScreen  setScreen={setScreen} weirdness={weirdness}/>}
          {screenBase === "edit"    && <EditScreen    weirdness={weirdness}/>}
        </div>
      </div>

      <TweaksPanel
        open={tweaksOpen}
        onClose={() => setTweaksOpen(false)}
        palette={palette}
        setPalette={changePalette}
        weirdness={weirdness}
        setWeirdness={changeWeirdness}
      />
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
