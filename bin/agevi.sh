#!/usr/bin/env bash
set -euo pipefail

NAME=agevi

if [ "$#" -ne 2 ]
then
    echo "Usage: $NAME <age-identity> <encrypted-file.age>"
    exit 1
fi

AGE_ID="$1"
AGE_FILE="$2"

if [ ! -f "$AGE_ID" ]
then
    echo "Error: Identity file not found at $AGE_ID" >&2
    exit 1
fi

if grep /tmp /proc/mounts | grep -q tmpfs
then
    AGEVI_TMPDIR=/tmp
else
    : "${AGEVI_TMPDIR:?AGEVI_TMPDIR must identify a suitable temp directory}"
fi

CLEAR_FILE=$(mktemp "/$AGEVI_TMPDIR/$NAME.XXXXXXXXXX.txt")
AGE_ID_CLEAR=$(mktemp /$AGEVI_TMPDIR/$NAME.XXXXXXXXXX.key)

cleanup() {
    rm -f "$CLEAR_FILE" "$AGE_ID_CLEAR"
}
trap cleanup EXIT

age --decrypt "$AGE_ID" > "$AGE_ID_CLEAR"

if [ -f "$AGE_FILE" ]
then
    age --decrypt -i "$AGE_ID_CLEAR" "$AGE_FILE" > "$CLEAR_FILE"
fi

INITIAL_HASH=""
if [ -f "$CLEAR_FILE" ]
then
    INITIAL_HASH=$(sha256sum "$CLEAR_FILE" | awk '{print $1}')
fi

vim -N -i NONE -n \
    -c 'set nobackup nowritebackup noundofile' \
    "$CLEAR_FILE"

FINAL_HASH=$(sha256sum "$CLEAR_FILE" | awk '{print $1}')

if [ "$INITIAL_HASH" != "$FINAL_HASH" ]
then
    echo "Changes detected. Creating backup and re-encrypting..."
    NEW_FILE=$(mktemp "$AGE_FILE.XXXXXXXXXX")
    age --encrypt --armor -i "$AGE_ID_CLEAR" --output "$NEW_FILE" "$CLEAR_FILE"
    mv -vi "$NEW_FILE" "$AGE_FILE"
else
    echo "No changes detected. Leaving original file unchanged."
fi

