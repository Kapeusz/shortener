**Decision Log**

**Scope:** Core design choices for Shortnr (schema, infra, runtime, metrics) with key trade‑offs and discarded alternatives.

**Database Schema**
- **Partitioned `urls` table:** Hash‑partition by `shortened_url` with 32 partitions; primary key on slug; columns: `long_url`, `redirect_count`, `expires_at`, timestamps; check constraints on slug length/charset and expiry after insert. Discarded: single unpartitioned table — simpler early on but risks write hot‑spots and vacuum bloat as volume grows; partitioning smooths contention and eases future scale/purges.
- `redirect_events`:** Stores `shortened_url`, `user_agent`, `ip`, `inserted_at` to back admin metrics and real‑time updates. Discarded: only aggregate counters in DB — loses flexibility for new breakdowns (e.g., browsers) and makes auditing impossible.
- `redirect_locations` with PostGIS:** Point geometry (SRID 4326) for recent marker views; spatial GiST index; constraints enforce type/SRID. Discarded: external geo store or third‑party analytics — adds cost/latency and complicates local development; PostGIS keeps queries local and simple.

**Indexes**
- **`urls(expires_at)` + `urls(long_url)`:** Supports expiry sweeps and idempotent create from normalized long_url. Discarded: unique index on `long_url` — conflicts with multiple concurrent shorteners and expiry semantics.
- **`redirect_events(shortened_url)` + `(inserted_at)`:** Powers recent‑window aggregations and per‑slug filters. Discarded: composite `(shortened_url, inserted_at)` only — slightly smaller set but reduces flexibility for time‑only scans.
- **`redirect_locations USING GIST (geom)`:** Spatial queries and map rendering. Discarded: B‑tree on lat/lng columns — not optimal for spatial operations.

**Slug Generation**
- **Deterministic HMAC‑SHA256 -> Base62 prefix:** Stable 8‑char slug from `SLUG_SECRET` + long URL; retry path adds salt on collisions; server‑enforced charset/length via constraints and changeset validations. Discarded: Own Snowflake implementation — too much time needed to roll out a self-made Snowflake implementation.

**Write Path & Counters**
- **Event buffering via PubSub -> batch DB writes:** Redirects broadcast a compact event; a GenServer batches `redirect_events` inserts and executes one `UPDATE` per slug to increment `urls.redirect_count`. Discarded: synchronous insert per request — raises tail latency and DB pressure under burst traffic.
- **Periodic expiry with Oban:** Daily job deletes expired URLs and their analytics in a transaction, rescheduling if batches are large. Discarded: DB triggers on write — complicates partitioned setup and adds overhead to hot paths.

**Caching & Rate Limiting**
- **Per‑node ETS cache (long_url -> slug) with TTL:** Avoids duplicate inserts and reduces DB hits for repeat inputs. Discarded: distributed cache (e.g., Redis) — adds ops surface; per‑node suffices given idempotent DB path.
- **Hammer (ETS) rate limiting:** Per‑IP limits for redirect and API endpoints with simple configuration. Discarded: reverse proxy only (e.g., NGINX) — still recommended in front, but in‑app guards ensure safety everywhere (tests, dev, alt deployments).

**Metrics Collected**
- **App/DB/VM Telemetry:** Phoenix router/endpoint, Ecto query times, and VM run queue/memory via `Telemetry.Metrics` for LiveDashboard observability. Discarded: full Prometheus exporter — extra infra until external scraping/storage is required.
- **Product metrics (admin UI) and Geolocation:** Totals per slug, browser breakdown (UA buckets), coarse location buckets (IP class/private/IPv6) with a moving window (last 10k events) and live updates.Client posts lat/lng once before redirect; recent markers rendered on a map. Discarded: Using d3.js to visualise, e.g. Number of redirections per country per URL, because of time constraints. Current implementation of Google Maps markers might be a good starting step to add more visual metrics to the system.

**Infrastructure**
- **Elixir/Phoenix + LiveView:** Real‑time admin views; Bandit HTTP adapter; PubSub for local fan‑out. Discarded: separate SPA + JSON API — more moving parts and duplication for a small surface area.
- **PostgreSQL + PostGIS:** One durable store for URLs, events, and optional geo with mature tooling. Discarded: polyglot stores (NoSQL + SQL) — unnecessary operational burden.
- **Oban for background jobs:** Reliable expiry cleanup and scheduled tasks inside the BEAM supervision tree. Discarded: external cron/worker — harder to ship and observe as a single service.
- **CORS via config:** Environment‑driven allowed origins for the API. Discarded: unconditional wildcard — need least‑privilege defaults.

**Security & Privacy**
- **Minimal PII:** Store raw IP in events only for coarse bucketing; optional precise geo is client‑provided and not inferred from IP; no cookies/sessions for end‑users. Discarded: storing referer or fingerprints — avoid unnecessary data retention and compliance overhead.
- **Strict CSP in browser pipeline:** Allows only required Google Maps assets when map is used. Discarded: permissive CSP — higher XSS risk.

**Why Not Other Metrics**
- **No per‑user cohorts/UU metrics:** Requires identity and tracking beyond scope; can be derived later from events if needed with external tooling.
- **No long‑term rollups:** Keep raw events; rollups belong in analytics/warehouse if scale demands it.

**Operational Notes**
- **Hot path is read‑heavy and single‑row lookups:** Partitioning by slug, PK on `shortened_url`, and batched counters keep redirects fast.
- **Growth levers:** Increase partition count for `urls` if needed; move events to a dedicated tablespace/retention; add Prometheus exporter if external monitoring is adopted.

