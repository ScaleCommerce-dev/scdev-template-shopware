# Scaffold Shopware 6 project, install dependencies, initialize the database,
# generate demo data, and skip the First Run Wizard.
#
# Uses /tmp for scaffolding because composer create-project requires an empty
# directory. PHP's vendor/ uses relative paths, so copying the scaffolded
# project back to /app works without breaking autoload.
#
# APP_URL / APP_SECRET / DATABASE_URL / MAILER_DSN are already set as container
# environment variables in .scdev/config.yaml — Shopware reads them directly,
# so we don't write a .env.local file here.
#
# shopware-cli is preferred for build/admin-api/dump operations (it wraps the
# bin/build-*.sh scripts and theme:compile/assets:install into one step).
# bin/console is still used for system:install, framework:demodata, and
# system:config:set — shopware-cli has no equivalent wrappers for those.

[no-exit-message]
default:
    scdev start -q
    @scdev step "Installing Symfony CLI and shopware-cli"
    scdev exec app sh -c "wget -q https://get.symfony.com/cli/installer -O - | bash && cp \$HOME/.symfony5/bin/symfony /usr/local/bin/symfony"
    scdev exec app sh -c "ARCH=\$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && wget -qO /tmp/sw.tar.gz https://github.com/shopware/shopware-cli/releases/latest/download/shopware-cli_linux_\$ARCH.tar.gz && tar -xzf /tmp/sw.tar.gz -C /usr/local/bin shopware-cli && rm /tmp/sw.tar.gz"
    @scdev step "Scaffolding Shopware 6 (this takes several minutes)"
    scdev exec app sh -c "rm -rf /tmp/app && composer create-project shopware/production /tmp/app --no-interaction"
    @scdev step "Copying project files"
    scdev exec app sh -c "cp -a /tmp/app/. /app/ && rm -rf /tmp/app"
    @scdev step "Adding shopware/dev-tools (needed for framework:demodata)"
    scdev exec app composer require --dev --no-interaction shopware/dev-tools
    @scdev step "Waiting for MariaDB to accept connections"
    scdev exec app sh -c "until nc -z db 3306 2>/dev/null; do sleep 1; done"
    @scdev step "Installing Shopware (database, schema, admin user, default sales channel)"
    scdev exec app php bin/console system:install --create-database --basic-setup --force --no-interaction
    @scdev step "Building admin + storefront assets + compiling theme (via shopware-cli project ci)"
    scdev exec app shopware-cli project ci --with-dev-dependencies .
    @scdev step "Generating demo data (products, categories, customers, orders — using Shopware's default mix)"
    scdev exec app bash -c "APP_ENV=prod php bin/console framework:demodata --no-interaction"
    @scdev step "Marking First Run Wizard as completed"
    scdev exec app bash -c "php bin/console system:config:set core.frw.completedAt \"\$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\""
    @scdev step "Clearing cache"
    scdev exec app php bin/console cache:clear
    @scdev step "Rebuilding search/category/sales-channel/product indexes (makes demo products visible on the storefront)"
    scdev exec app php bin/console dal:refresh:index
    @scdev step "Finalizing setup"
    scdev exec app sh -c "grep -qxF '.setup-complete' .gitignore 2>/dev/null || echo '.setup-complete' >> .gitignore; touch .setup-complete"
    @scdev step "Setup complete! Shopware will start automatically."
    @echo "Default admin: admin / shopware"
    scdev info
