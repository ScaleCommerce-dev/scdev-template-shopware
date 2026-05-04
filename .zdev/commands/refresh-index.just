# Rebuild all DAL indexes (search, product listing, category, sales channel, ...).
# Run this after bulk data changes (e.g. after `framework:demodata` or a DB import)
# so the storefront picks up the new data.
# Shortcut for:  zdev exec app php bin/console dal:refresh:index

[no-exit-message]
default:
    zdev exec app php bin/console dal:refresh:index
