# Clear the Shopware / Symfony cache inside the app container.
# Shortcut for:  scdev exec app php bin/console cache:clear

[no-exit-message]
default:
    scdev exec app php bin/console cache:clear
