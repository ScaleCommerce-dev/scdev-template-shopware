# Run shopware-cli inside the app container.
#
# `scdev shopware-cli` with no args shows the top-level help.
# shopware-cli's subcommands (`project`, `account`, `extension`) don't contain
# colons, so they forward transparently:
#
#   scdev shopware-cli project ci
#   scdev shopware-cli project doctor
#   scdev shopware-cli project storefront-watch
#   scdev shopware-cli extension list

[no-exit-message]
default *args:
    scdev exec app shopware-cli {{args}}

[no-exit-message]
project *args:
    scdev exec app shopware-cli project {{args}}

[no-exit-message]
extension *args:
    scdev exec app shopware-cli extension {{args}}

[no-exit-message]
account *args:
    scdev exec app shopware-cli account {{args}}
