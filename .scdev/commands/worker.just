# Inspect and manage the Symfony Messenger worker.
#
# The worker runs as a background process inside the `app` container — see
# .scdev/config.yaml `command:`. Putting it inside `app` avoids the duplicate
# Mutagen session and parallel `composer install` we'd get from a separate
# `worker` service (scdev creates one volume + one sync per service).
#
# It consumes the `async` and `low_priority` transports, restarts every 120s
# (--time-limit) and on memory pressure (--memory-limit=512M), and appends
# stdout/stderr to /tmp/worker.log inside the container.
#
# These subcommands are utilities — the worker runs unattended otherwise.

[no-exit-message]
default: stats

# Queue depth (async / low_priority / failed) + live worker processes.
[no-exit-message]
stats:
    @scdev exec app php bin/console messenger:stats async low_priority failed
    @scdev exec app sh -c 'printf "\nWorker processes:\n"; ps -eo comm,args | awk "\$1==\"php\" && /messenger:consume/" || true; ps -eo comm,args | awk "\$1==\"php\" && /messenger:consume/" | grep -q . || echo "  (none — worker is between restarts, will respawn within 1s)"'

# Drain the queue once, right now (exits when empty or after 60s).
# Useful after `framework:demodata` or a bulk import to flush indexer messages.
[no-exit-message]
drain:
    scdev exec app php bin/console messenger:consume async low_priority --limit=10000 --time-limit=60 --memory-limit=512M --no-interaction

# Follow the worker's log file. The same output also lands in `scdev logs -f app`,
# interleaved with the Symfony dev-server log; this gives you just the worker.
[no-exit-message]
logs:
    scdev exec app tail -f /tmp/worker.log

# Show messages that ended up in the failure transport (after retry exhaustion).
[no-exit-message]
failed:
    scdev exec app php bin/console messenger:failed:show --max=50

# Retry every message in the failure transport.
[no-exit-message]
retry:
    scdev exec app php bin/console messenger:failed:retry --force

# Tell running workers to exit after their current message.
# The container's restart loop respawns them within ~1s — this is how you
# pick up code changes without restarting the whole container.
[no-exit-message]
restart:
    scdev exec app php bin/console messenger:stop-workers
