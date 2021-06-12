#!/bin/sh
set -e

if [ $(echo "$1" | cut -c1) = "-" ]; then
	echo "$0: assuming arguments for bitcoind"
	set -- bitcoind "$@"
fi

# Allow the container to be started with `--user`, if running as root drop privileges
if [ "$1" = 'bitcoind' -a "$(id -u)" = '0' ]; then
	# Set perms on data
	echo "$0: detected bitcoind"
	mkdir -p "$DATADIR"
	chmod 700 "$DATADIR"
	chown -R bitcoinsv "$DATADIR"
	exec gosu bitcoinsv "$0" "$@" -datadir=$DATADIR
fi

if [ "$1" = 'bitcoin-cli' -a "$(id -u)" = '0' ] || [ "$1" = 'bitcoin-tx' -a "$(id -u)" = '0' ]; then
	echo "$0: detected bitcoin-cli or bitcoint-tx"
	exec gosu bitcoinsv "$0" "$@" -datadir=$DATADIR
fi

# If not root (i.e. docker run --user $USER ...), then run as invoked
echo "$0: running exec"
exec "$@"
