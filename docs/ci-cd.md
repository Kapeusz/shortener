# CI/CD with GitHub Actions and Fly.io

This repo ships with two GitHub Actions workflows:

- `.github/workflows/ci.yml`: Runs tests on pushes/PRs
- `.github/workflows/deploy.yml`: Deploys to Fly.io after successful builds on `main` (also supports manual `workflow_dispatch`)

## CI (Tests)

Highlights:

- Uses `erlef/setup-beam` to install Elixir/OTP
- Caches `deps/` and `_build/` for faster runs
- Brings up a Postgres service with PostGIS (`postgis/postgis:15-3.3`), which is required by migrations
- Runs `mix ecto.create`, `mix ecto.migrate`, then `mix test`

Environment assumptions come from `config/test.exs` (localhost Postgres, username/password `postgres`).

## Deploy (Fly.io)

The deploy workflow:

1. Checks out the code and compiles it for a quick sanity check
2. Installs `flyctl` via `superfly/flyctl-actions/setup-flyctl@v1`
3. Runs `flyctl deploy --remote-only`

Secrets:

- Add `FLY_API_TOKEN` to the repo/environment secrets

App configuration files included:

- `fly.toml`: Fly app config (set `app = "shortnr-app-placeholder"` to your app name)
- `Dockerfile`: Multi-stage build for a Phoenix release listening on port `8080`

Required runtime secrets on Fly (set via `flyctl secrets set`):

- `SECRET_KEY_BASE` – generate with `mix phx.gen.secret`
- `DATABASE_URL` – Postgres URL, e.g. `ecto://USER:PASS@HOST:5432/DB`
- `SLUG_SECRET` – secret for deterministic slug generation
- Optionals: `URL_CACHE_TTL_MS`, `GOOGLE_MAPS_API_KEY`

## Local validation

Run tests locally:

```
mix deps.get
mix ecto.create
mix ecto.migrate
mix test
```

Build and run the release Docker image locally:

```
docker build -t shortnr:local .
docker run -e SECRET_KEY_BASE=$(mix phx.gen.secret) -e DATABASE_URL=ecto://postgres:postgres@host.docker.internal:5432/shortnr_dev -e SLUG_SECRET=dev-secret -p 8080:8080 shortnr:local
```

## Notes

- The deploy job triggers only on `main` branch pushes by default.

