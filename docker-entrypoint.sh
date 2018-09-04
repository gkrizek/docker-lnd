#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
# or first arg is `something.conf`
if [ "${1#-}" != "$1" ] || [ "${1%.conf}" != "$1" ]; then
	set -- lnd_oneshot "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'lnd_oneshot' -a "$(id -u)" = '0' ]; then
	chown -R lnd .
	exec su-exec lnd "$0" "$@"
fi

exec "$@"
