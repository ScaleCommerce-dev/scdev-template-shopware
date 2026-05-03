# Forward args to shopware-cli inside the app container.
# scdev auto-prepends the matching recipe name, so multi-word subcommands
# (project ci, extension list, account login, project storefront-watch)
# flow through unchanged.

[no-exit-message]
shopware-cli *args:
    scdev exec app shopware-cli {{args}}
