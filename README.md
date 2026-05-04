# zdev Shopware 6 Template

A starter template for [zdev](https://github.com/0ploy/zdev) that scaffolds a Shopware 6 project with a working local development environment.

## What's included

- PHP 8.4 via ScaleCommerce's prebuilt [`docker-php-cli`](https://github.com/ScaleCommerce/docker-php-cli) image (`ghcr.io/scalecommerce/docker-php-cli:8.4.20`), which ships with every extension Shopware requires (`intl`, `pdo_mysql`, `gd`, `bcmath`, `opcache`, `exif`, `zip`, plus `apcu`, `redis`, `memcached`, etc.), Composer, Node.js, npm, and pnpm already baked in — no runtime extension install
- MariaDB 11.4 LTS database (Shopware's recommended database — the Shopware team tests against MariaDB, and 11.4 is comfortably above the minimum 10.11 required by 6.7)
- Symfony CLI dev server (installed during setup)
- [`shopware/production`](https://github.com/shopware/production) scaffolded via `composer create-project shopware/production` (the official Shopware 6 project skeleton)
- Database schema, basic sales channel, and default admin user installed via `bin/console system:install --create-database --basic-setup`
- [`shopware-cli`](https://github.com/shopware/shopware-cli) preinstalled at `/usr/local/bin/shopware-cli` — used for asset builds (`project ci`) and available inside the container for extension management, admin-api calls, DB dumps, and CI-style builds. Reinstalled automatically on container recreate.
- [`shopware/dev-tools`](https://packagist.org/packages/shopware/dev-tools) added as a dev dependency (required for `bin/console framework:demodata`)
- Demo data pre-generated: 30 products across 10 categories with 8 manufacturers, 15 customers, 15 orders, and 30 media files — so the storefront looks populated out of the box
- Administration **First Run Wizard skipped** via `bin/console system:config:set core.frw.completedAt` — log in to `/admin` and go straight to the dashboard, no first-run assistant
- Full asset build (admin + storefront + theme + bundle assets) run once via `shopware-cli project ci` — a single command that wraps `bin/build-administration.sh`, `bin/build-storefront.sh`, `theme:compile`, and `assets:install`
- HTTPS via zdev's shared Traefik router, with **`SYMFONY_TRUSTED_PROXIES=private_ranges`** so Symfony generates `https://` URLs behind the reverse proxy (without this, the admin login bounces and mixed-content errors appear in the browser console)
- Permanent **Symfony Messenger worker** running inside the app container — consumes the `async` and `low_priority` transports so emails, indexer updates, flow actions, and scheduled tasks process without anyone having to keep the admin tab open. Restarts every 120s (`--time-limit`) and on memory pressure (`--memory-limit=512M`). Lives in the same container as the dev server so it shares the existing `vendor/`, with no parallel Mutagen session or composer install. Inspect via `zdev worker` (see below)
- Mailpit integration (`MAILER_DSN=smtp://mail:1025`) — all outgoing mail is caught
- OpenSearch disabled by default (`SHOPWARE_ES_ENABLED=0`) — Shopware falls back to SQL-based search, which is plenty for dev
- Mutagen file sync (macOS) with `vendor/`, `var/`, `node_modules/`, `public/bundles/`, `public/theme/`, `public/media/`, `public/thumbnail/`, `.zdev/`, and `.setup-complete` kept inside the container for speed

## Usage

```bash
zdev create shopware my-shop
cd my-shop
zdev setup
```

Setup takes several minutes (Composer pulls ~500 MB of dependencies and Shopware builds both the storefront and admin bundles). When it finishes, the shop is running at `https://my-shop.0ploy.dev`.

## Default credentials

- **Storefront**: `https://my-shop.0ploy.dev/`
- **Admin panel**: `https://my-shop.0ploy.dev/admin/`
  - Username: `admin`
  - Password: `shopware`

## What `zdev setup` does

1. Starts the Docker containers (app + MariaDB) — PHP, extensions, Composer, Node, npm, and pnpm all come from the `ghcr.io/scalecommerce/docker-php-cli:8.4.20` image
2. Installs the Symfony CLI and `shopware-cli`
3. Scaffolds Shopware via `composer create-project shopware/production /tmp/app` and copies it into `/app` (Composer needs an empty target directory, so we stage in `/tmp`; PHP's `vendor/` uses relative paths, so copying back is safe)
4. Adds `shopware/dev-tools` as a dev dependency (gates `framework:demodata` — Shopware refuses to run demo generation without it)
5. Waits for MariaDB to accept connections
6. Runs `php bin/console system:install --create-database --basic-setup --force --no-interaction` — creates the database, imports the schema, loads the basic dataset, creates the default admin user, and registers a default storefront sales channel pointed at `APP_URL`
7. Runs `shopware-cli project ci --with-dev-dependencies` — one command that builds admin + storefront JS/CSS, compiles the theme, and copies bundle assets into `public/`
8. Runs `APP_ENV=prod php bin/console framework:demodata --products=30 --categories=10 ...` — generates demo products, categories, manufacturers, customers, orders, and media (Shopware's demo-data generator enforces `APP_ENV=prod` as a safety check, hence the env override)
9. Runs `php bin/console system:config:set core.frw.completedAt "<now>"` — marks the First Run Wizard as completed so admin login goes straight to the dashboard
10. Clears the cache and marks setup complete — the Symfony dev server **and the messenger worker** start automatically

Full script: [.zdev/commands/setup.just](.zdev/commands/setup.just).

## Development

Edit files in `src/`, `custom/plugins/`, or `config/` and refresh the browser — Symfony reloads on every request in dev mode. Administration and storefront JS changes require a rebuild (see below).

### Shortcuts

The template ships `zdev` wrappers for the most common operations:

```bash
zdev cache-clear                            # = zdev console cache:clear
zdev refresh-index                          # = zdev console dal:refresh:index
zdev build                                  # = zdev shopware-cli project ci --with-dev-dependencies

zdev console                                # bin/console with no args (lists every command)
zdev console cache:clear                    # any bin/console command — colons pass through
zdev console dal:refresh:index
zdev console plugin:refresh

zdev shopware-cli                           # shopware-cli top-level help
zdev shopware-cli project ci
zdev shopware-cli project doctor
zdev shopware-cli project storefront-watch  # HMR watcher
zdev shopware-cli extension list

zdev worker                                 # queue depth (async/low_priority/failed) + live worker pids
zdev worker drain                           # one-shot drain of the queue (useful after bulk imports)
zdev worker logs                            # tail the worker's log (/tmp/worker.log inside the container)
zdev worker failed                          # show messages stuck in the failure transport
zdev worker retry                           # retry every failed message
zdev worker restart                         # tell workers to exit; the container respawns them within ~1s
```

### Common commands

```bash
zdev shopware-cli project ci --with-dev-dependencies   # Full rebuild (admin + storefront + theme + assets)
zdev shopware-cli project storefront-build             # Rebuild storefront only
zdev shopware-cli project admin-build                  # Rebuild admin only
zdev shopware-cli project dump --output /app/dump.sql  # DB dump (optionally --anonymize)
zdev shopware-cli project admin-api GET /api/product   # Pre-authenticated Admin API call
zdev shopware-cli project doctor                       # Health-check the project
zdev exec app composer require <package>               # Add a PHP package
zdev exec app composer update                          # Update composer packages
zdev console <command>                                 # Run any Shopware / Symfony console command
zdev console cache:clear                               # Clear the cache
zdev console plugin:refresh                            # Refresh the plugin list
zdev console plugin:install --activate <Name>          # Install + activate a plugin
zdev console theme:compile                             # Recompile the active theme (SCSS changes)
zdev console dal:refresh:index                         # Rebuild search/category indexes
zdev exec app bash -c "APP_ENV=prod php bin/console framework:demodata --products=50 --reset-defaults"  # Regenerate demo data (needs APP_ENV=prod)
zdev exec app bash                                     # Open an interactive shell
```

### shopware-cli quick reference

`shopware-cli` is preinstalled in the container. Run `zdev shopware-cli project --help` for the full list.

**Works out of the box** (no project config needed):

| Command | What it does |
|---|---|
| `project ci [--with-dev-dependencies]` | One-shot build: composer install + admin-build + storefront-build + theme:compile + assets:install |
| `project admin-build` / `project storefront-build` | Individual Webpack/Vite builds |
| `project admin-watch` / `project storefront-watch` | Dev watchers with HMR (alternative to full rebuilds) |
| `project doctor` | Project health check (finds common misconfigurations) |
| `project extension install/activate/deactivate` | Wraps `bin/console plugin:*` with less ceremony |
| `project worker [amount]` | Runs Symfony workers (mail queue, flow actions, scheduled tasks) in the background |
| `project generate-jwt` | Rotates the JWT secret used for Admin API tokens |

**Need `.shopware-project.yml`** — run `zdev shopware-cli project config init` interactively once to create it, then:

| Command | What it does |
|---|---|
| `project admin-api [METHOD] [PATH]` | Auth'd `curl` to the Admin API — no manual token juggling |
| `project dump --anonymize --compression zstd` | DB dump with customer data scrubbed |
| `project clear-cache` | Clears the shop cache via the Admin API (for local, `bin/console cache:clear` is simpler) |

`shopware-cli` doesn't wrap `system:install`, `framework:demodata`, or `system:config:set core.frw.completedAt` — those stay on `bin/console`.

- `zdev db` — opens Adminer. Connect with server `db`, user `root`, password `shopware`, database `shopware`.
- `zdev mail` — opens Mailpit. All outgoing mail shows up here.
- `zdev logs -f app` — follow app container logs.
- `zdev update` — apply `.zdev/config.yaml` changes (env, image, command, volumes). `zdev restart` alone won't — it preserves the container.

## Customizing

- Change DB password / name in `.zdev/config.yaml` under `variables:`, then `zdev down -v` (removes DB volume so MariaDB reinitializes with new credentials) and `zdev start`.
- Change the internal HTTP port by overriding `PORT` in `.zdev/config.yaml` `variables:` (defaults to `80`). Traefik terminates HTTPS externally, so this only affects the Symfony dev server inside the container.
- Enable OpenSearch by flipping `SHOPWARE_ES_ENABLED` / `SHOPWARE_ES_INDEXING_ENABLED` to `1`, adding an `opensearch` service to `.zdev/config.yaml`, and setting `OPENSEARCH_URL=http://opensearch:9200`. Then run `zdev console es:index` to build the indexes.
- After editing Twig templates under `src/Resources/views/` or `custom/plugins/*/src/Resources/views/`, no rebuild is needed — just refresh.
- After editing storefront SCSS, run `zdev console theme:compile`.
- After editing storefront JS, run `zdev shopware-cli project storefront-build` (or `storefront-watch` for HMR).
- After editing admin JS/Vue, run `zdev shopware-cli project admin-build` (or `admin-watch` for HMR).
- To regenerate demo data with different counts: `zdev exec app bash -c "APP_ENV=prod php bin/console framework:demodata --products=100 --orders=50 --reset-defaults"`.
- Any other `.zdev/config.yaml` change: `zdev update` diffs the config against running containers and recreates only what changed.

## Troubleshooting

### Admin login redirects or cookies are dropped

This shouldn't happen with this template — `SYMFONY_TRUSTED_PROXIES=private_ranges` is set in `.zdev/config.yaml` and `APP_URL` is set to the HTTPS zdev URL. If you forked the template and dropped either, restore them: Traefik terminates HTTPS and forwards HTTP to Symfony, so without `SYMFONY_TRUSTED_PROXIES` Shopware generates `http://` URLs inside the HTTPS page and the browser blocks the cookies / forms.

### Storefront 500s with "file does not exist" for `public/theme/...` or `public/bundles/...`

Asset build hasn't run. Either `zdev setup` was skipped, or you ran `zdev down -v` which cleared the public build output. Rebuild manually:

```bash
zdev exec app bash bin/build-storefront.sh
zdev exec app bash bin/build-administration.sh
zdev console theme:compile
zdev console assets:install
```

### "Apps and plugins currently incompatible with your Shopware version" warning

Expected on a fresh install — the message appears until you run `zdev console plugin:refresh`. The template leaves the plugin list empty, so there are no actual incompatibilities.

### Config change isn't taking effect

`zdev restart` preserves the container. For env, image, command, or volume changes in `.zdev/config.yaml`, run `zdev update` — it diffs and recreates only what changed. Code changes (via bind mount / Mutagen) don't need any restart.

### `ghcr.io/scalecommerce/docker-php-cli:8.4.20` image pull fails

The image is published to GitHub Container Registry and should pull without authentication. If Docker reports an auth or not-found error, make sure your Docker daemon can reach `ghcr.io` (check proxy/VPN settings) and that you're not rate-limited. As a fallback, swap the image in `.zdev/config.yaml` for a public equivalent (e.g. `php:8.4-cli-alpine` plus manual extension install).

## Requirements

- [zdev](https://github.com/0ploy/zdev) installed
- Docker Desktop running
- Network access to `ghcr.io` to pull the `ghcr.io/scalecommerce/docker-php-cli:8.4.20` image (see [ScaleCommerce/docker-php-cli](https://github.com/ScaleCommerce/docker-php-cli))

## Learn more

- Shopware 6 developer documentation: https://developer.shopware.com/docs/
- Shopware installation guide: https://developer.shopware.com/docs/guides/installation/
- Shopware production repo (what we scaffold via `composer create-project`): https://github.com/shopware/production
- Shopware core repo: https://github.com/shopware/shopware
- Shopware CLI (useful for packaging extensions): https://github.com/shopware/shopware-cli
- zdev documentation: https://github.com/0ploy/zdev
- Base PHP image: https://github.com/ScaleCommerce/docker-php-cli
