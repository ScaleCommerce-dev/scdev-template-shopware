# Clear the Shopware / Symfony cache inside the app container.
# Shortcut for:  zdev exec app php bin/console cache:clear

[no-exit-message]
default:
    zdev exec app php bin/console cache:clear
