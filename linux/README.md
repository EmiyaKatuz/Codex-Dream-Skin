# Codex Dream Skin for Linux

Linux engine for the official Codex Desktop app. It starts the official client with a loopback-only CDP port, injects the Choten / INTERNET ANGEL theme into the verified Codex renderer, and never modifies `app.asar` or the installed application files.

## Requirements

- Linux desktop with official Codex Desktop installed
- Node.js 20+
- `bash`, `curl`, `tar`, and `pgrep`

## Install from source

Close Codex first, then run:

```bash
./linux/scripts/install-dream-skin-linux.sh
```

The engine is copied to `~/.codex/codex-dream-skin-linux`; state, logs, and the active theme are kept in `${XDG_STATE_HOME:-~/.local/state}/CodexDreamSkin`.

## Daily commands

```bash
~/.codex/codex-dream-skin-linux/scripts/start-dream-skin-linux.sh
~/.codex/codex-dream-skin-linux/scripts/verify-dream-skin-linux.sh
~/.codex/codex-dream-skin-linux/scripts/restore-dream-skin-linux.sh
```

`restore` removes the live renderer payload and stops only the recorded injector process. It does not modify Codex configuration or binaries.

## Performance

Linux defaults to `"performanceMode": "full"`, preserving the complete Choten animation, particles, and filters. DOM refresh is deliberately limited: only shell-level mutations, navigation actions, resize/appearance changes, and a 15-second fallback can trigger a full scan; streamed text updates do not. Set `performanceMode` to `"low"` in the active `theme.json` to disable animated ornaments and blur when battery life or GPU load matters more.

## Build a distributable archive

```bash
./linux/scripts/build-release.sh
```

This produces `linux/release/CodexDreamSkin-Linux-v<version>.tar.gz` and a SHA-256 sidecar file. The archive is self-contained and can be unpacked anywhere before running the installer.

## Security boundary

- CDP binds to `127.0.0.1` only.
- The injector accepts only official `app://` targets or the Linux package's `localhost:5175` renderer, then verifies Codex DOM markers.
- Theme image validation limits artwork to 16 MiB, 16384 px per edge, and 50 megapixels.
- No API key, provider, account, or Codex config is read or modified.
