# Mining build/config meta from Discord channels

Use this reference when a user asks for a current/recent recommended configuration from a high-volume Discord channel where people share setups (e.g. “last month of builds”, “updated settings”, “what is the current meta”).

## Workflow pattern

1. Export only the requested bounded time window to JSON with explicit timezone offsets.
2. Verify the first/last messages after export so the user can audit the exact range.
3. Run broad keyword passes first: the tool/product names and version tags the channel is about, plus generic signal words (`config`, `pinned`, `works`, `crash`, `fails`, `stable`, `latest`).
4. Then inspect surrounding windows around high-signal messages rather than relying on isolated snippets. Look especially for follow-ups that reverse earlier enthusiasm (`crashes`, `fails`, `quality difference`, `don’t use yet`, `stick with X`).
5. Treat pinned configs and attached scripts/config files as high-signal, but not automatically authoritative: recent replies may say a pin is stale, risky, or only valid for a different hardware setup.
6. If the user asked for a constrained target (a specific hardware count, model, or mode), filter every candidate against that constraint before recommending it. Do not generalize a config written for one setup to another without noting the required changes.
7. Separate baseline vs experimental configs explicitly. Prefer the most repeatedly reported stable/accurate config as the baseline; put faster but quality-risky branches under experiments.
8. Write a compact artifact in the active workspace (config/run notes) and validate syntax where possible.

## Attachment handling

- JSON exports include attachment URLs, but direct CDN downloads can 403 even when DCE was able to export the message metadata.
- If attachments are likely to contain the actual config (`message.txt`, `.yaml`, `.json`, `.sh`, `.log`), prefer exporting the bounded range with `--media` from the start, or ask/obtain approval before a media-download re-export if the tool requires it.
- Never preserve credentials from attachments or pasted configs; replace secrets with `[REDACTED]`.

## Recommendation synthesis checklist

For each candidate config, record:

- exact version/tag/build
- exact target hardware/setup it was reported on
- required flags/env vars
- reported positive results
- reported failures or caveats
- whether the source says it is pinned/current/stable or experimental
- whether later messages contradict earlier claims

When finalizing, state the evidence window and export path, then provide a conservative runnable baseline plus a tuning ladder.