#!/usr/bin/env bash
# Bounded daily collector, suitable for cron / systemd timer. Script-only: it prints a
# compact digest instead of piping a raw export into an agent.
#
#   ./daily-summary.sh <channel_id> [outdir]
#
# Both --after and --before are explicit and carry a timezone offset: DCE parses naive
# timestamps in the machine's local zone, which silently shifts your window otherwise.
set -euo pipefail

CHANNEL="${1:?usage: daily-summary.sh <channel_id> [outdir]}"
OUTDIR="${2:-$HOME/discord-exports}"
mkdir -p "$OUTDIR"

DAY="$(date +%Y-%m-%d)"
OFFSET_RAW="$(date +%z)"                       # e.g. -0700
OFFSET="${OFFSET_RAW:0:3}:${OFFSET_RAW:3:2}"   # -> -07:00
AFTER="${DAY}T00:00:00${OFFSET}"
BEFORE="${DAY}T23:59:59${OFFSET}"
OUT="$OUTDIR/${CHANNEL}-${DAY}.json"

dce export -c "$CHANNEL" -f Json --after "$AFTER" --before "$BEFORE" -o "$OUT"

jq -r '
  "## \(.channel.name) — \(.messageCount) messages (\($after))",
  "",
  "Top posters:",
  ( .messages | group_by(.author.name) | map({a: .[0].author.name, n: length})
    | sort_by(-.n) | .[:5][] | "  \(.n)\t\(.a)" ),
  "",
  "Links shared:",
  ( [ .messages[] | (.content // "") | scan("https?://[^\\s>)]+") ] | unique | .[:15][] | "  \(.)" )
' --arg after "$AFTER" "$OUT"
