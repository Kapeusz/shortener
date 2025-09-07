# Shortnr

## Application Description
Shortnr is a Phoenix-based URL shortener with an admin interface, real‑time metrics, and optional geolocation capture. It lets you create short slugs for long URLs, enforce simple slug rules (A–Z, a–z, 0–9, `_`, `-`, length 4–32), optionally set expiration, and tracks redirect counts. Redirects publish events used to power live dashboards (browser and IP-bucket breakdowns) and a map of recent locations when geolocation capture is enabled. Rate limiting protects the redirect and API endpoints.

Key capabilities:
- Create short URLs from long URLs with normalization and collision retries.
- Expired URLs are cleared using an Oban Job
- Live admin views for URL management and usage metrics.
- Redirect event collection with batched writes for performance.
- Optional client geolocation capture on first hop, with a map view.
- Basic API endpoints with CORS and per-IP rate limiting.

## Technologies
- Elixir/Phoenix: Phoenix 1.7 + LiveView for UI
- Ecto + PostgreSQL: Persistence, pagination (Scrivener)
- PostGIS + `geo_postgis`: Storing geolocation points (SRID 4326)
- Hammer: Simple rate limiting plug
- PubSub: Real‑time metrics updates

## Data Structures
- Url: Core short link record
  - shortened_url – slug/short code (string, primary key)
  - long_url – target URL (string)
  - redirect_count – number of redirects (integer)
  - expires_at – expiration timestamp (UTC)

- RedirectEvent: Append‑only redirect log (for aggregates)
  - shortened_url – slug (string)
  - user_agent – raw User‑Agent (string)
  - ip – remote IP used for coarse location buckets (string)
  - inserted_at – event time (UTC)

- RedirectLocation: Optional per‑redirect geolocation
  - shortened_url – slug (string)
  - geom – PostGIS point (WGS84/SRID 4326)
  - inserted_at – event time (UTC)

## Database Types
- Urls: `shortened_url` (varchar/text), `long_url` (text), `redirect_count` (integer), `expires_at` (timestamptz), timestamps.
- RedirectEvents: `shortened_url` (text), `user_agent` (text), `ip` (text), `inserted_at` (timestamptz).
- RedirectLocations: `shortened_url` (text), `geom` (geometry(Point, 4326) via PostGIS), `inserted_at` (timestamptz).

## Running Tests
Install dependencies:

```
mix deps.get
```

Run the test suite:

```
mix test
```
