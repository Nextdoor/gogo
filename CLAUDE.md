# CLAUDE.md

GoGo is a "go link" URL shortener (e.g., `go/shortname` -> full URL). Flask + Python 3 + PostgreSQL + nginx in Docker. Supports Google OAuth, header-based auth, or skip-auth for dev. Originally from Nextdoor, Apache 2.0 licensed.

## Development Commands

```bash
# Prerequisites (macOS)
brew install postgresql        # needed for psycopg2 build
make venv                      # creates .venv with deps + black + isort

# Docker-based local dev
make db                        # start + initialize Postgres container
make run                       # build image, run app at http://localhost (SKIP_AUTH=true by default)
make stop                      # stop app container
make clean                     # remove all containers and venv

# Database
make psql                      # interactive psql session
make db-apply-schema           # apply schema/schema.sql (idempotent)
make db-truncate               # truncate the shortcut table
make db-wipe                   # drop and recreate the database
COMMAND='SELECT ...' make db-run-command  # run arbitrary SQL
```

Format with `black` and `isort` from the venv.

## Architecture

### Source Files (`src/`)

| File | Purpose |
|------|---------|
| `app.py` | Flask app creation, route registration, entry point. Reads config from `APP_SETTINGS` env var. |
| `gogo.py` | Core views: dashboard, list, CRUD, redirect handler (`ShortcutRedirectView`). |
| `models.py` | Single model `Shortcut` (id, created_at, name, owner, url, secondary_url, hits). |
| `auth.py` | `@login_required` decorator + `get_current_user()`. Three auth modes (see below). |
| `search.py` | AJAX endpoint `/_ajax/search` using PostgreSQL `ILIKE` for name/url substring matching. |
| `base_list_view.py` | Shared pagination/sorting for dashboard and list views (`sort`, `order`, `limit`, `offset` params). |
| `config.py` | `Config` / `DevelopmentConfig` / `ProductionConfig`. Auth mode derived from env vars. |

### Routes

| Route | View | Description |
|-------|------|-------------|
| `/` | `DashboardView` | User's shortcuts + create form |
| `/_list` | `ListView` | All shortcuts org-wide |
| `/_create` | `CreateShortcutView` | POST to create shortcut |
| `/_edit` | `EditShortcutView` | GET form / POST to edit |
| `/_delete` | `DeleteShortcutView` | GET confirmation / POST to delete |
| `/<path:name>` | `ShortcutRedirectView` | Redirect (or prompt creation if not found) |
| `/_ajax/search` | `SearchView` | JSON search by `name`/`url` params |
| `/healthz` | `Healthz` | DB health check (no auth) |
| `/oauth2/callback` | `OAuth2Callback` | Google OAuth callback (conditional) |

### Auth Modes (mutually exclusive, checked in this priority)

1. **Skip auth** (`SKIP_AUTH=true`) - user is always "anonymous". Overrides everything.
2. **Header auth** (`AUTH_HEADER_NAME` set) - trusts a header from upstream proxy. Returns 401 if missing.
3. **Google OAuth** (default when no `AUTH_HEADER_NAME`) - session-based, domain-restricted via `HOSTED_DOMAIN`. Uses deprecated `oauth2client`.

### Key Behavior: Redirect Logic (`ShortcutRedirectView`)

- `go/<name>` with `/` splits into name + secondary_arg (e.g., `go/jira/PROJ-123`)
- If shortcut has `secondary_url` with `%s` placeholders and secondary_arg exists, placeholders are filled via `_replace_placeholders()` (302 redirect)
- Otherwise, 301 redirect to primary `url`
- If shortcut doesn't exist, renders create form with name pre-filled
- Hit counter incremented synchronously on every redirect

### Data Model

Single table `shortcut` (schema in `schema/schema.sql`). No migrations system - schema applied idempotently. Only index is the implicit unique on `name`.

### Frontend

- Bootstrap 2.x (vendored in `static/bootstrap/`), jQuery 2.2 from Google CDN
- `static/go.js` handles: form validation, column sort toggling, live AJAX search as-you-type, alert banners
- Templates in `templates/` using Jinja2 with macros (`forms.html`, `search.html`)

### Deployment

- Docker: `python:3.13-alpine3.20` + nginx + self-signed SSL in one container
- `resources/entrypoint.sh`: KMS decryption (boto3), OAuth client_secrets.json templating, starts nginx + Flask
- CI: Docker build on PRs (`build.yml`), push to `ghcr.io/nextdoor/gogo` on main/release (`publish.yml`), auto-drafted releases (`release-drafter.yml`), weekly CodeQL scans

### Key Env Vars

| Var | Required | Notes |
|-----|----------|-------|
| `TITLE` | Yes (crashes at import if missing) | UI branding, e.g. "Nextdoor" -> "Go Nextdoor" |
| `DATABASE_URI` | Yes | PostgreSQL connection string |
| `SKIP_AUTH` | Yes (crashes if unset - see gotchas) | `true` for local dev |
| `CONFIG` | No (defaults to `ProductionConfig`) | `DevelopmentConfig` or `ProductionConfig` |
| `AUTH_HEADER_NAME` | No | Enables header-based auth, disables Google OAuth |
| `HTTPS_REDIRECT_URL` | No (defaults to `https://localhost`) | Post-CRUD redirect base URL |
| `DISABLE_NGINX` | No | Skip nginx startup in container |
| `BEHIND_PROXY` | No | Enables Werkzeug `ProxyFix` middleware |
