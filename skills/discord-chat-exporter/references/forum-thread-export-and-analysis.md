# Forum/thread export and focused analysis pattern

Use this when a user asks for a bounded Discord history analysis and the target appears as both a normal channel and a forum channel, or when DCE says a channel is a forum and cannot be exported directly.

## Pattern

1. Discover guild/channel IDs normally:

```bash
dce guilds | grep -i "<guild>"
dce channels --guild <guild_id> | grep -i "<channel>"
```

2. If duplicate channel paths appear, export each bounded candidate separately. A normal text channel exports directly:

```bash
AFTER=$(date -u -d '1 month ago' +%Y-%m-%dT%H:%M:%SZ)
BEFORE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
dce export -c <text_channel_id> -f Json --after "$AFTER" --before "$BEFORE" -o <outdir>/<id>.json
```

3. If a candidate is a forum channel, DCE may fail with:

```text
Channel '<name>' of guild '<guild>' is a forum and cannot be exported directly. You need to pull its threads and export them individually.
```

Re-run against the forum channel using thread inclusion and an output directory:

```bash
dce export -c <forum_channel_id> -f Json \
  --after "$AFTER" --before "$BEFORE" \
  --include-threads All \
  -o <outdir>/forum/
```

This can export only the threads active/visible in the bounded range, each as its own JSON file.

## Avoiding slow discovery

`dce channels --guild <guild_id> --include-threads All` can be very slow or time out on large guilds because it enumerates threads broadly. If you already have the forum channel ID from `dce channels --guild`, prefer bounded `dce export ... --include-threads All` directly.

## Analysis workflow

For focused recommendation synthesis:

1. Combine the normal channel JSON plus all forum-thread JSON files.
2. Count per-file messages and verify min/max timestamps before summarizing.
3. Extract topic candidates with broad keyword regexes, then filter for recommendation verbs (`recommend`, `use`, `avoid`, `works`, `broke`). Build the clusters from the domain at hand, e.g. for a product-recommendation question:
   - the generic category words and their slang/abbreviations
   - platform / generation / family names
   - vendor and model names
   - technical spec terms people use when comparing options
4. Synthesize by recurring pattern and caveat, not by isolated quotes. Include message counts, date bounds, and export path in the final answer so the user can audit the work.
