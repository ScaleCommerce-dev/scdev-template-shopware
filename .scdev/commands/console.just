# Run a Shopware / Symfony bin/console command inside the app container.
#
# `scdev console` with no args shows the full command list.
# Colon-containing commands (`cache:clear`, `dal:refresh:index`, etc.) can't be
# passed through this wrapper because `just` — the runner scdev dispatches
# through — reserves `:` as its module-path separator. For those, either use
# a dedicated shortcut (see `scdev cache-clear`, `scdev refresh-index`) or the
# direct form:
#   scdev exec app php bin/console cache:clear

[no-exit-message]
default *args:
    scdev exec app php bin/console {{args}}
