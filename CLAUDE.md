# CLAUDE.md

Behavioral guidelines and project context for working in this URL shortener codebase.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

## Project: URL Shortener

Rails 8.1, PostgreSQL, Redis, Sidekiq, Hotwire (Turbo + Stimulus). Deployed via Kamal 2 to AWS Lightsail with Docker.

### Commands

All Ruby/Rails commands run inside Docker. Prefix with `docker compose run --rm web`.

```bash
docker compose up                                          # Start the app
docker compose restart web sidekiq                         # Restart after config/initializer changes
docker compose run --rm web bin/rspec                      # Full test suite
docker compose run --rm web bin/rspec spec/path/file.rb:23 # Single test
docker compose run --rm web bin/rubocop                    # Lint
docker compose run --rm web bin/rails db:migrate           # Run migration (dev)
docker compose run --rm web bin/rails db:migrate RAILS_ENV=test  # Run migration (test)
docker compose run --rm web bin/rails console              # Console
docker compose run --rm web bin/rails db:test:prepare      # Prepare test DB
```

### Architecture

**Request flow:** User submits URL → `TargetUrlsController` validates via `TargetUrlForm` → `LinkShortenerService` normalizes URL, creates/links `TargetUrl` and `ShortUrl` (Base58 slug with 3-retry collision loop) → `FetchTitleWorker` fetches page title async → Turbo Stream broadcasts title to the UI.

**Redirect flow:** `GET /:slug` → `ShortUrlsController#show` creates a `Visit` record, atomically increments `visits_count`, redirects 302 to target. Visit tracking is best-effort (never blocks redirect). Geolocation batch-processed every 5 min by `BatchProcessVisitsWorker` via ip-api.com, rate limit tracking in Redis.

**Key patterns:**
- **Service objects** (`app/services/`): `LinkShortenerService`, `TitleFetcherService`, `Base58Service`, `IpApi::Batch`
- **Form object** (`app/forms/target_url_form.rb`): input validation separate from models
- **Custom validator** (`app/validators/ip_address_validator.rb`): reusable IP validation
- **Atomic counters**: `ShortUrl#increment_visits!` uses `update_counters` under `attr_readonly` guard
- **SSRF protection**: `TargetUrl` blocks private IPs, loopback, cloud metadata, self-referencing URLs
- **Turbo Streams**: `FetchTitleWorker` broadcasts title updates to replace spinner in real-time

### Slug generation

Base58 alphabet (excludes 0/O/l/I), 4–15 characters. `Base58Service.generate` via `SecureRandom.base58`. Validated at route, model, and service layers. `LinkShortenerService` retries up to 3 times on unique constraint violations.

### Background jobs

- `FetchTitleWorker` (default queue): async title fetch + Turbo broadcast
- `BatchProcessVisitsWorker` (low queue): scheduled every 5 min via `sidekiq-scheduler`, enriches visits with geolocation, auto-re-enqueues if more unprocessed visits remain

### Auth & authorization

Devise for authentication. All actions except `ShortUrlsController#show` (public redirect) require login. Dashboard and metrics scope queries to `current_user.short_urls`. Sidekiq web UI at `/sidekiq` with HTTP Basic Auth.

### Frontend

Bootstrap 5 + Stimulus + Turbo. CSS via `yarn build:css` (sass + autoprefixer), `css` Docker service watches for changes. JavaScript uses importmap (no bundler). Stimulus controllers: `clipboard_controller.js` for copy-to-clipboard with visual feedback.

### Testing

RSpec with factory_bot, shoulda-matchers, webmock, rails-controller-testing. All specs use `type: :controller`. Devise test helpers included for controller specs. Webmock enabled globally. Transactional fixtures.

### CI

GitHub Actions (`.github/workflows/ci.yml`): brakeman, bundler-audit, importmap audit, rubocop, RSpec with PostgreSQL service container. Deploy workflow is manual (`workflow_dispatch`) via Kamal.

### Gotchas

- Migrations must run in both `development` and `test` environments
- `config/initializer` or `config/environments` changes require `docker compose restart`
- `config.force_ssl` is commented out in production.rb — should be enabled before production deploy
- ip-api.com free tier uses HTTP only (no HTTPS) — known limitation
- ip-api.com rate limit (45 req/min) is tracked in Redis; `BatchProcessVisitsWorker` self-throttles
