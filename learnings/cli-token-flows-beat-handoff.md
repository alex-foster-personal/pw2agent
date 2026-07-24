# CLI token flows beat pw2agent handoff

Thu 24 Jul 2026: pw2agent was invoked to hand over a Modal API key, but it was
never needed - the Modal CLI had its own browser token flow.

The agent ran `modal token new` as a background Bash task. It printed a
token-flow URL (`https://modal.com/token-flow/tf-...`), auto-opened the
browser, the user completed auth there, and the CLI verified and wrote
`~/.modal.toml` itself. Zero secret ever touched chat, clipboard, or a
stash file.

**Rule:** before invoking pw2agent for a service API key/token, check whether
the service CLI has a built-in browser auth flow (`<cli> token new`,
`<cli> auth login` - e.g. modal, gh, gcloud, doppler, wrangler). If it does,
prefer it: run it in background so the URL/flow surfaces while the agent
keeps working, and let the tool write its own credential file. Fall back to
pw2agent only when no such flow exists or a raw key is genuinely required
(e.g. env var for CI, keys minted in a dashboard).
