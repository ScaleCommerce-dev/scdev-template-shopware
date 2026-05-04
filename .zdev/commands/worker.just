# Inspect and manage the Symfony Messenger worker.
#
# The worker runs as a background process inside the `app` container — see
# .zdev/config.yaml `command:`. Putting it inside `app` avoids the duplicate
# Mutagen session and parallel `composer install` we'd get from a separate
# `worker` service (zdev creates one volume + one sync per service).
#
# It consumes the `async` and `low_priority` transports, restarts every 120s
# (--time-limit) and on memory pressure (--memory-limit=512M), and appends
# stdout/stderr to /tmp/worker.log inside the container.
#
# These subcommands are utilities — the worker runs unattended otherwise.

[no-exit-message]
default:
    @echo "Inspect and manage the Symfony Messenger worker."
    @echo ""
    @echo "Available subcommands:"
    @echo "  zdev worker stats     Queue depth (async/low_priority/failed) + live worker pids"
    @echo "  zdev worker drain     Drain the queue once, right now (useful after bulk imports)"
    @echo "  zdev worker logs      Tail the worker's log file (/tmp/worker.log in container)"
    @echo "  zdev worker failed    Show messages stuck in the failure transport"
    @echo "  zdev worker retry     Retry every message in the failure transport"
    @echo "  zdev worker restart   Stop running workers — the container respawns them"
    @echo ""
    @echo "Note: zdev refresh-index runs indexers synchronously and does NOT use the"
    @echo "worker. To see the worker actually consume something, run an action that"
    @echo "queues messages — saving a product in Admin, or zdev console"
    @echo "dal:refresh:index --use-queue."

# Queue depth (async / low_priority / failed) + live worker processes.
[no-exit-message]
stats:
    @zdev exec app php bin/console messenger:stats async low_priority failed
    @zdev exec app sh -c 'printf "\nWorker processes:\n"; ps -eo comm,args | awk "\$1==\"php\" && /messenger:consume/" || true; ps -eo comm,args | awk "\$1==\"php\" && /messenger:consume/" | grep -q . || echo "  (none — worker is between restarts, will respawn within 1s)"'

# Drain the queue once, right now (exits when empty or after 60s).
# Useful after `framework:demodata` or a bulk import to flush indexer messages.
[no-exit-message]
drain:
    zdev exec app php bin/console messenger:consume async low_priority --limit=10000 --time-limit=60 --memory-limit=512M --no-interaction

# Follow the worker's log file. The same output also lands in `zdev logs -f app`,
# interleaved with the Symfony dev-server log; this gives you just the worker.
[no-exit-message]
logs:
    zdev exec app tail -f /tmp/worker.log

# Show messages that ended up in the failure transport (after retry exhaustion).
[no-exit-message]
failed:
    zdev exec app php bin/console messenger:failed:show --max=50

# Retry every message in the failure transport.
[no-exit-message]
retry:
    zdev exec app php bin/console messenger:failed:retry --force

# Tell running workers to exit after their current message.
# The container's restart loop respawns them within ~1s — this is how you
# pick up code changes without restarting the whole container.
[no-exit-message]
restart:
    zdev exec app php bin/console messenger:stop-workers
