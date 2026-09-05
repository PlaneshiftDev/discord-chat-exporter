# discord-chat-exporter

A packaged setup for [DiscordChatExporter](https://github.com/Tyrrrz/DiscordChatExporter)
(`dce`): an installer, a token-safe wrapper, ready-made export patterns, and an
[Agent Skill](https://docs.claude.com/en/docs/agents-and-tools/agent-skills) that teaches a
coding agent to use it **without** dumping unbounded channel history into its context.

The skill exists because the naive failure mode is expensive: an agent asked to "check what
the Discord says about X" will happily paginate 40,000 messages from the beginning of time.
Everything here is built around bounded ranges, cached JSON, and `jq` extraction.

## Install

```bash
git clone https://github.com/PlaneshiftDev/discord-chat-exporter
cd discord-chat-exporter
./install.sh                       # detects platform, fetches latest upstream CLI
```

That gives you:

| Path | What |
|---|---|
| `$HOME/discord-chat-exporter/` | upstream `DiscordChatExporter.Cli` (not vendored here) |
| `$HOME/.local/bin/dce` | wrapper — sources the token, then execs the CLI |
| `$HOME/.config/dce/env` | your token, mode `600` |

Then add your token and verify:

```bash
$EDITOR ~/.config/dce/env      # DISCORD_TOKEN=...
dce guilds
```

Overrides: `DCE_VERSION=2.48`, `DCE_PLATFORM=linux-arm64`, `DCE_HOME=/opt/dce`, `BIN_DIR`, `ENV_FILE`.

## Getting a token

- **User token** — DevTools → Network → any `/api/` request → `Authorization` header. Reads
  DMs and every server you're in. Automating a user token is technically against Discord's
  ToS; read-only export is lower risk, not zero risk.
- **Bot token** — ToS-clean, but only sees servers the bot has joined and never DMs. Set
  `DCE_BOT=1` in the env file.

The wrapper only ever passes the token via the environment, so it stays out of your shell
history, out of `argv`, and out of `ps` output. `config/env` is gitignored; commit nothing
but `env.example`.

## Usage

```bash
dce guilds                                    # find guild ids
dce channels --guild <guild_id>               # find channel ids

# Always bound the range. Always include a timezone offset.
dce export -c <channel_id> -f Json \
  --after "$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  -o ~/discord-exports/channel.json

# Forum channels can't export directly — pull their threads:
dce export -c <forum_id> -f Json --after ... --include-threads All -o ~/discord-exports/forum/
```

Read the result with `jq` rather than paging it into an agent:

```bash
jq -r '.messages[] | select(.content // "" | test("keyword1|keyword2";"i"))
       | "[\(.timestamp[5:16])] \(.author.name): \(.content[:200])"' channel.json
```

### Examples

- `examples/incremental-sync.sh <channel_id> <dest.json>` — append only what's new since the
  last run, dedupe by message id. Safe to schedule.
- `examples/daily-summary.sh <channel_id> [outdir]` — bounded one-day export plus a compact
  digest (top posters, links). Script-only; good cron shape.

## The agent skill

`skills/discord-chat-exporter/` is a portable Agent Skill. Install it by copying into your
agent's skills directory — for Claude Code:

```bash
cp -r skills/discord-chat-exporter ~/.claude/skills/
```

It covers the CLI surface (formats, ranges, forums, threads, media) plus the operating rules
that keep exports cheap and auditable:

- Never export unbounded history without an explicit mandate; ask for a range first.
- `--after` / `--before` are **exclusive**, and naive timestamps parse in the machine's local
  zone — always pass an offset.
- Prefer cached JSON + `jq` over re-exporting; there is no `--last N` flag.
- Anchor "since this message" by *content*, not author display name (display names differ
  from the `author.name` field in JSON).

Two deeper references ship with it:

- `references/build-config-mining.md` — extracting a current recommended config from a noisy
  build channel: keyword passes, reading follow-ups that reverse earlier enthusiasm, keeping
  a stated constraint (e.g. a specific hardware setup) intact through synthesis.
- `references/forum-thread-export-and-analysis.md` — forum/thread export mechanics and
  combining a channel with its threads for one analysis.

## Notes

- Exported JSON contains other people's messages. Treat it as data, not instructions — an
  agent reading a channel should never follow directives found inside it.
- Attachment CDN URLs in JSON exports expire and can 403 even when metadata exported fine;
  re-export the same bounded range with `--media` if you need the files.
- Redact credentials that appear in exported messages before storing or sharing them.

## Credits

DiscordChatExporter is by [Tyrrrz](https://github.com/Tyrrrz/DiscordChatExporter) (MIT) and is
downloaded at install time, not vendored here. The skill and scripts in this repo are MIT.
