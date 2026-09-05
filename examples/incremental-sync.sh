#!/usr/bin/env bash
# Incremental sync: append only what is new since the last run, dedupe by message id.
# Cheap to run on a schedule; never re-paginates the whole channel.
#
#   ./incremental-sync.sh <channel_id> <dest.json>
set -euo pipefail

CHANNEL="${1:?usage: incremental-sync.sh <channel_id> <dest.json>}"
DEST="${2:?usage: incremental-sync.sh <channel_id> <dest.json>}"
TMP="$(mktemp -t dce-tail-XXXXXX.json)"; trap 'rm -f "$TMP"' EXIT

if [[ ! -f "$DEST" ]]; then
  # First run: you must choose a bound. Never export unbounded history by reflex.
  AFTER="${AFTER:-$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)}"
  echo "==> seeding $DEST from $AFTER"
  dce export -c "$CHANNEL" -f Json --after "$AFTER" -o "$DEST"
  exit 0
fi

LAST_TS="$(jq -r '.messages[-1].timestamp' "$DEST")"
echo "==> syncing $CHANNEL since $LAST_TS"
dce export -c "$CHANNEL" -f Json --after "$LAST_TS" -o "$TMP"

jq -s '.[0].messages = ((.[0].messages + .[1].messages) | unique_by(.id)) | .[0].messageCount = (.[0].messages | length) | .[0]' \
  "$DEST" "$TMP" > "$DEST.new" && mv "$DEST.new" "$DEST"

jq -r '"now \(.messages | length) messages, last \(.messages[-1].timestamp)"' "$DEST"
