---
name: discord-chat-exporter
description: Use when exporting or querying Discord chat history with DiscordChatExporter.Cli (`dce`), especially requests mentioning dce, DiscordChatExporter, export discord channel, discord messages, or discord history.
version: 1.0.0
author: PlaneshiftDev
license: MIT
metadata:
  tags: [discord, export, chat-history, dce, discordchatexporter]
  related_skills: []
---

# DiscordChatExporter (`dce`)

## Overview

Use DiscordChatExporter.Cli (`dce`) to export Discord chat history from servers, channels, and DMs. Prefer JSON when the result will be searched, summarized, sliced, or otherwise processed by tools.

This skill is intentionally conservative about export ranges: active channels can have thousands of messages, and unbounded exports waste time and bandwidth. Always establish a time range before running any export command unless the user explicitly asks for a full archive and confirms it.

**Trigger words:** `dce`, `DiscordChatExporter`, "export discord channel", "discord messages", "discord history".

## STOP — Before Any `dce export`

**If the user did not give a time range, ask for one before exporting.** Do not assume, do not guess, and do not default to full history.

Ask one short question, then wait:

> How far back? e.g. last hour / last day / since YYYY-MM-DD HH:MM / since a specific message?

This applies to every invocation of:

- `dce export`
- `dce exportguild`
- `dce exportdm`
- `dce exportall`

If you are about to type `dce export ... -o ...` with no `--after` and no explicit user mandate for a full archive, **stop and ask**.

### The Only Exception

You may export without `--after` only if the user explicitly says something like:

- "archive the whole channel"
- "everything"
- "full history"

Even then, confirm once before running it.

## Local Installation Reference

Reference installation (created by `install.sh`; adjust paths to taste):

- Wrapper on PATH: `$HOME/.local/bin/dce` → call `dce`
- Binary: `$HOME/discord-chat-exporter/DiscordChatExporter.Cli`
- Default export dir: `$HOME/discord-exports/`
- Version check: `dce --version`
- Token env file: `$HOME/.config/dce/env` (`chmod 600`, holds the `DISCORD_TOKEN` assignment)
- The `$HOME/.local/bin/dce` wrapper automatically sources `$HOME/.config/dce/env` before invoking the binary

Check installation:

```bash
dce --version
```

If calling `DiscordChatExporter.Cli` directly instead of the `dce` wrapper, source the DCE env file first:

```bash
source $HOME/.config/dce/env
```

Then verify token presence without printing the token:

```bash
printf '%s\n' "${#DISCORD_TOKEN}"
```

Confirm a token is present by its length only — never print the token itself.

## Discovery — Finding Guild and Channel IDs

```bash
dce guilds                            # list all accessible servers
dce channels --guild <guild_id>       # list channels in a server
dce dm                                # list DM channels
```

Use plain `grep -i <keyword>` on the output to find IDs. Cache IDs in notes or local working files when useful; they are stable.

Examples:

```bash
dce guilds | grep -i "server name"
dce channels --guild <guild_id> | grep -i "general"
```

## Export — Canonical Commands

### Single Channel JSON

Use JSON for any machine-readable or post-processing workflow:

```bash
dce export -c <channel_id> -f Json --after "2026-01-01T00:00:00-07:00" -o <path-or-dir>
```

### Forum Channels and Threads

Forum channels cannot be exported directly as a single channel; DCE reports that you need to pull/export their threads. Prefer exporting the forum channel with `--include-threads All` and the same bounded time range:

```bash
dce export -c <forum_channel_id> -f Json \
  --after "2026-01-01T00:00:00-07:00" \
  --before "2026-01-02T00:00:00-07:00" \
  --include-threads All \
  -o <output_dir>/
```

If `dce channels --guild <guild_id> --include-threads All` is slow or times out on a large guild, skip the full thread listing and run the bounded `dce export ... --include-threads All` against the known forum channel ID instead. See `references/forum-thread-export-and-analysis.md` for a worked pattern.

### Full Server

```bash
dce exportguild --guild <guild_id> -f Json --after "2026-01-01T00:00:00-07:00" -o <output_dir>/
```

### All DMs

```bash
dce exportdm -f Json --after "2026-01-01T00:00:00-07:00" -o <output_dir>/
```

## Output Formats (`-f`)

| Format | Notes |
|---|---|
| `HtmlDark` | Default. Self-contained dark-theme HTML. Pair with `--media` for offline attachments. |
| `HtmlLight` | Same, light theme. |
| `Json` | Structured. Use for programmatic work. **Always pick this when post-processing.** |
| `PlainText` | Readable `.txt`, includes attachment URLs. |
| `Csv` | Spreadsheet-friendly, one row per message. |

## Output Path (`-o`)

- File path with extension → single file.
- Directory ending in `/` → DCE auto-names (`<guild> - <channel> [<id>].<ext>`).
- Use `--partition 1000` or `--partition 100mb` to split large exports.

## Media Attachments

- HTML formats: add `--media` to download attachments into `<file>_Files/` for offline viewing.
- JSON/Csv/PlainText: by default reference Discord CDN URLs, which may expire. Add `--media` for archival.

## Time-Range Filtering

```bash
dce export -c <channel_id> -f Json \
  --after "2026-01-01T00:00:00-07:00" \
  --before "2026-01-02T00:00:00-07:00" \
  -o <output>
```

Critical rules:

1. **Always include a timezone offset** (`-07:00`, `+00:00`, or `Z`). Without one, DCE parses in the server's local timezone, which may be UTC and can be hours off from Discord's displayed time.
2. **`--after` is exclusive.** To include a message, pick a timestamp at least one second before it. Rounding down to `:00` of the minute is a clean convention.
3. **`--before` is also exclusive.** Round up when needed.
4. Either flag is optional; omit one for an open-ended range.
5. Date filters may still require pagination. For repeated queries, prefer cached JSON + `jq`.

## Translating User Anchors to `--after`

Use shell date conversion for relative ranges:

```bash
# last hour
--after "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)"

# last day
--after "$(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ)"

# yesterday / since yesterday
--after "$(date -u -d 'yesterday 00:00' +%Y-%m-%dT%H:%M:%SZ)"
```

For a bare date, add an explicit timezone offset before passing it to DCE.

For "since this message <quote>":

1. Search cached JSON by content if available.
2. Take the matched message timestamp.
3. Round down a minute or subtract at least one second.
4. Use that as `--after`.

## Last N Messages — DCE Has No `--last` Flag

### Preferred: Cached JSON Path

When a cached export exists at `$HOME/discord-exports/<channel>.json`, serve from the cache with `jq`. Do **not** re-export.

```bash
jq -r '.messages | length as $n | (.[$n-10:$n][] |
  "[\(.timestamp | sub("T"; " ") | sub("\\..*$"; ""))] \(.author.name): \(.content // "")")' \
  $HOME/discord-exports/<channel>.json
```

### Fallback: Recent Re-Export

If there is no useful cache, ask for or choose a user-provided recent range; do not perform a blind full export.

```bash
dce export -c <channel_id> -f Json \
  --after "$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  -o /tmp/recent.json
```

## For "Last N Messages from <channel>"

Workflow:

1. If a cached export exists at `$HOME/discord-exports/<channel>.json`, slice it with `jq` immediately.
2. If no cache exists, ask for a time range before exporting.
3. Export that bounded range to JSON.
4. Slice the tail with `jq`.
5. Do not re-export the whole channel just to get the tail.

## Anchoring to a Specific Message

When the user says "starting from this message" or "yesterday at 9 PM":

1. Prefer content-based anchoring by searching cached JSON for a substring:

   ```bash
   jq -r '.messages[] | select(.content // "" | test("<substring>"; "i")) | "\(.timestamp) | \(.author.name) | \(.content[:120])"' \
     $HOME/discord-exports/<channel>.json
   ```

2. Read the exact timestamp from the match.
3. Build `--after` with a small buffer, e.g. round down to the minute.
4. Re-export and verify by checking `.messages[0]`.

**Display name is not username.** The Discord display name shown in the client may differ from `author.name` in JSON (e.g. display "Cool Person" may have API field `coolperson_1234`). Anchor by message content, not by author name.

## Scheduled Bounded Fetch Pattern

For recurring jobs such as daily channel summaries, prefer a script-only scheduled job (no agent in the loop) that runs a bounded `dce export`, saves JSON, and prints concise Markdown. Keep the date calculation inside the script so each run uses the current local day. Always include an explicit timezone offset and both `--after` and `--before` bounds.

Example script shape:

```bash
DAY="$(date +%Y-%m-%d)"
OFFSET_RAW="$(date +%z)"
OFFSET="${OFFSET_RAW:0:3}:${OFFSET_RAW:3:2}"
AFTER="${DAY}T00:00:00${OFFSET}"
BEFORE="${DAY}T02:00:00${OFFSET}"
dce export -c "$CHANNEL_ID" -f Json --after "$AFTER" --before "$BEFORE" -o "$OUT"
jq -r '.messages[] | select((.content // "") != "") | .content' "$OUT"
```

Keep the script in a dedicated scripts directory, test it manually, then schedule it (cron/systemd timer). Prefer a script-only job that prints a compact summary over one that pipes raw exports into an agent.

## Incremental Sync Pattern

For periodic backups of an active channel:

```bash
CHANNEL=<channel_id>
DEST=$HOME/discord-exports/<name>.json

LAST_TS=$(jq -r '.messages[-1].timestamp' "$DEST")
dce export -c "$CHANNEL" -f Json --after "$LAST_TS" -o /tmp/sync-tail.json

jq -s '.[0].messages = (.[0].messages + .[1].messages | unique_by(.id)) | .[0]' \
  "$DEST" /tmp/sync-tail.json > "$DEST.new" && mv "$DEST.new" "$DEST"
```

`unique_by(.id)` dedupes boundary messages if present.

## JSON Schema Reference

Fields you will usually use:

```jsonc
{
  "guild": { "id": "...", "name": "..." },
  "channel": { "id": "...", "name": "...", "topic": "..." },
  "messages": [
    {
      "id": "msg_snowflake",
      "type": "Default | Reply | ChannelPinnedMessage | ...",
      "timestamp": "2026-01-01T12:00:00.000-07:00",
      "timestampEdited": "... | null",
      "callEndedTimestamp": null,
      "isPinned": false,
      "content": "the message text, may be empty",
      "author": {
        "id": "...",
        "name": "username",
        "discriminator": "...",
        "nickname": "...",
        "color": "...",
        "isBot": false,
        "roles": [],
        "avatarUrl": "..."
      },
      "attachments": [ { "id": "...", "url": "...", "fileName": "...", "fileSizeBytes": 0 } ],
      "embeds": [],
      "stickers": [],
      "reactions": [],
      "mentions": [],
      "reference": { "messageId": "...", "channelId": "...", "guildId": "..." },
      "inlineEmojis": []
    }
  ],
  "messageCount": 0
}
```

## Useful `jq` patterns:

```bash
# Messages only
jq '.messages' file.json

# Count
jq '.messages | length' file.json

# By author username
jq '.messages | map(select(.author.name == "X"))' file.json

# With attachments
jq '.messages | map(select(.attachments | length > 0))' file.json

# Replies to a message
jq --arg id "<msg_id>" '.messages | map(select(.reference.messageId == $id))' file.json
```

## Mining Build / Config History from a Channel

When the user asks for “last month of builds”, “current meta”, “recommended config”, or similar from a Discord channel, use the detailed checklist in `references/build-config-mining.md`.

1. Export the requested bounded date range to JSON.
2. Programmatically filter for high-signal terms (the tool/product names and version tags the channel is about, plus `build`, `config`, `benchmark`, `pinned`, error names) instead of reading the full archive manually.
3. Inspect exact full messages around promising snippets, especially messages with code blocks, attachments, or replies that validate/contradict the candidate.
4. Download text attachments (`.txt`, `.yaml`, `.yml`, `.sh`, `.diff`, `.json`, `.log`) from the relevant messages and read them directly; many Discord “config” answers are attached files rather than inline text. If direct CDN attachment URLs 403, re-export the same bounded range with `--media` rather than assuming the attachment is unavailable.
5. Distinguish stable/recommended configs from experimental branches by recency plus follow-up messages (“works”, “crashes”, “current best”, “pinned”, “use this one”). Treat pinned configs as high-signal but verify later follow-up messages for caveats.
6. Preserve the user's target constraint (e.g. a specific hardware count or mode) throughout synthesis; do not silently generalize configs written for a different setup.
7. Save derived config artifacts in the active workspace and mention the source export path so the user can audit the evidence.

Pitfall: do not overfit to the latest benchmark screenshot alone. The newest option may be fastest but less reliable than an older one that multiple users report as working.

## Token and ToS Notes

- `$HOME/.config/dce/env` exposes `DISCORD_TOKEN` to the `dce` wrapper. If it is a **user token**, automation is technically against Discord ToS; read-only export is lower risk but not zero risk.
- Bot tokens work too: `dce --bot -t '<bot_token>' ...`.
- Bots cannot read DMs or servers they are not in, but are ToS-cleaner.
- If `dce guilds` returns auth errors, the token may have rotated due to password change or log-out-everywhere. Re-grab via DevTools Network tab → any `/api/` request → `Authorization` header.

## Common Failure Modes

| Symptom | Cause / Fix |
|---|---|
| `Channel '<name>' ... is a forum and cannot be exported directly` | Re-run `dce export` against the forum channel with `--include-threads All` and a bounded `--after`/`--before`; output to a directory so each thread becomes its own JSON file. |
| `dce channels --guild ... --include-threads All` times out on a large guild | Avoid enumerating every thread when you already know the forum channel ID; use bounded `dce export -c <forum_id> --include-threads All` instead. |
| Empty results from `--after` filter | Timezone offset missing or wrong; DCE assumed UTC and you meant local. |
| First message is not the anchor | `--after` is exclusive; back off the bound by at least one second. |
| Author search returns nothing | You used display name, not `author.name`; search by content instead. |
| `dce` says auth failed | Token stale or `$HOME/.config/dce/env` missing/incorrect. The wrapper sources this file automatically; if bypassing the wrapper, run `source $HOME/.config/dce/env` and verify token length without printing the token. |
| Full-channel export is slow | DCE paginates from oldest message; cache JSON and slice with `jq`. |
| Background `dce export` looks stuck | It may be buffering progress. Check `stat -c '%s' <outfile>` to confirm growth. |

## Verification Checklist

Before running exports:

- [ ] User supplied a time range, or explicitly requested and confirmed full history.
- [ ] Command includes `--after` unless it is a confirmed full-history archive.
- [ ] Timestamps include timezone offsets.
- [ ] Cached JSON was checked first for last-N or anchor-based requests.
- [ ] JSON format is used for post-processing.
- [ ] Output path is under `$HOME/discord-exports/` or another user-approved location.
