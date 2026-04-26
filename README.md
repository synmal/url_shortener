# URL Shortener

A URL shortener service built with Ruby on Rails 8.1. Users can create short URLs, track click analytics with geolocation data, and manage their links through a web dashboard.

## Features

- Shorten URLs with automatic page title fetching
- Base58 slug generation (4–15 characters, excludes ambiguous 0/O/l/I)
- Click tracking with timestamps and geolocation (via ip-api.com)
- Per-user dashboard with metrics and analytics
- Public redirect endpoint — no login required to follow short links
- SSRF protection against private IPs, loopback, and cloud metadata endpoints
- Real-time title updates via Turbo Streams

## Tech Stack

- **Ruby 4.0.2** / **Rails 8.1**
- **PostgreSQL 17** — primary database
- **Redis 7** — caching, Sidekiq queue, rate limiting
- **Sidekiq 8.1** — background job processing (title fetching, geolocation enrichment)
- **Hotwire** (Turbo + Stimulus) — real-time UI updates
- **Bootstrap 5** — styling
- **Devise** — authentication
- **Kamal 2** — deployment to AWS Lightsail

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Getting Started

```bash
# Clone the repository
git clone <repo-url>
cd url_shortener

# Build and start all services (db:schema:load runs automatically via entrypoint)
docker compose up
```

The app runs at `http://localhost:3000`.

## Testing

Prepare the test database before running tests:

```bash
docker compose run --rm web bin/rails db:test:prepare
```

Then run specs:

```bash
# Full test suite
docker compose run --rm web bin/rspec

# Single test file
docker compose run --rm web bin/rspec spec/controllers/short_urls_controller_spec.rb

# Single test by line number
docker compose run --rm web bin/rspec spec/path/file.rb:23
```

Test framework: RSpec with factory_bot, shoulda-matchers, webmock, and rails-controller-testing.

## Linting & Security

```bash
docker compose run --rm web bin/rubocop    # Style linting
```

CI pipeline (GitHub Actions) also runs: brakeman, bundler-audit, importmap audit.

## Common Commands

All Rails commands run inside Docker. Prefix with `docker compose run --rm web`.

```bash
docker compose up                                          # Start the app
docker compose restart web sidekiq                         # Restart after config changes
docker compose run --rm web bin/rails console              # Rails console
docker compose run --rm web bin/rails db:migrate           # Run pending migrations
```

## Architecture

**Shortening flow:** User submits URL → `TargetUrlsController` → `TargetUrlForm` (input validation) → `LinkShortenerService` (normalize URL, create `TargetUrl` + `ShortUrl` with Base58 slug) → `FetchTitleWorker` fetches page title asynchronously → Turbo Stream updates the UI.

**Redirect flow:** `GET /:slug` → `ShortUrlsController#show` → create `Visit` record, atomically increment `visits_count` → 302 redirect to target URL. Visit tracking is best-effort and never blocks the redirect.

**Geolocation:** `BatchProcessVisitsWorker` runs every 5 minutes via sidekiq-scheduler, enriching unprocessed visits with country/city data from ip-api.com. Self-throttles to stay within the 45 req/min rate limit.

### Design Patterns

- **Service objects** (`app/services/`): `LinkShortenerService`, `TitleFetcherService`, `Base58Service`, `IpApi::Batch`
- **Form object** (`app/forms/target_url_form.rb`): input validation decoupled from models
- **Atomic counters**: `ShortUrl#increment_visits!` uses `update_counters` with `attr_readonly` guard to prevent race conditions
- **Custom validator** (`app/validators/ip_address_validator.rb`): SSRF protection via reusable IP validation
