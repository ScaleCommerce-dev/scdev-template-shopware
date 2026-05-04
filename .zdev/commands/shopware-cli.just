# Forward args to shopware-cli inside the app container.
# zdev auto-prepends the matching recipe name, so multi-word subcommands
# (project ci, extension list, account login, project storefront-watch)
# flow through unchanged.

[no-exit-message]
shopware-cli *args:
    zdev exec app shopware-cli {{args}}
