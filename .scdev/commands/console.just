# Forward args to bin/console. Colons (cache:clear, dal:refresh:index,
# debug:container) pass through because scdev auto-prepends the matching
# recipe name, so just does not parse them as module separators.

[no-exit-message]
console *args:
    scdev exec app php bin/console {{args}}
