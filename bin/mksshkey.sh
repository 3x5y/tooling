#!/usr/bin/env bash

[ "$HOSTNAME" ] || { echo HOSTNAME not set >&2; exit 1; }
[ "$1" ] || { echo require target argument >&2; exit 2; }

set -eu

target=$1
date=$(date +%Y%m%d)
idfile="$date"_"$HOSTNAME"_$target
comment="$date:$HOSTNAME:$target"
nl=$'\n'
entry="host $target$nl    identityfile ~/.ssh/$idfile"
vimline=''
if [ -s ~/.ssh/keys.conf ]
then
    line=$(wc -l ~/.ssh/keys.conf | cut -d' ' -f1)
    vimline=+$((line + 2))
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
echo run: ssh-copy-id -f -i ~/.ssh/"$idfile.pub" $target
echo to copy public key to target
echo
#vim ~/.ssh/keys.conf $vimline
