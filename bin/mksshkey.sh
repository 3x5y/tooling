#!/usr/bin/env bash

set -euo pipefail

if (( $# != 1 ))
then
    echo "Usage: mksshkey.sh <target>" >&2
    exit 1
fi

[ "${HOSTNAME:-}" ] || { echo HOSTNAME not set >&2; exit 1; }

target=$1
date=$(date +%Y%m%d)
idfile="$date"_"$HOSTNAME"_"$target"
comment="$date:$HOSTNAME:$target"
nl=$'\n'
entry="host $target$nl    identityfile ~/.ssh/$idfile"
if [ -s ~/.ssh/keys.conf ]
then
    entry="$nl$entry"
fi

ssh-keygen -t ed25519 -f ~/.ssh/"$idfile" -C "$comment"

echo
echo adding to ~/.ssh/keys.conf
echo "$entry" | tee -a ~/.ssh/keys.conf
echo
echo public key ~/.ssh/"$idfile".pub
cat ~/.ssh/"$idfile".pub
echo
echo run: ssh-copy-id -f -i ~/.ssh/"$idfile".pub $target
echo to copy public key to target
echo
echo edit ~/.ssh/keys.conf to finalise
