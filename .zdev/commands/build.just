# Full Shopware build: admin + storefront + theme + public bundle assets.
# Shortcut for:  zdev exec app shopware-cli project ci --with-dev-dependencies

[no-exit-message]
default:
    zdev exec app shopware-cli project ci --with-dev-dependencies
