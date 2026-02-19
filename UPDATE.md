# ZeroClaw Update Runbook

Last updated: February 19, 2026

## 1. Build latest upstream binary artifacts

```bash
gh workflow run "Build ZeroClaw Binaries" --repo em108/zeclo --ref main -f repo_ref=main
gh run watch --repo em108/zeclo "$(gh run list --repo em108/zeclo --workflow "Build ZeroClaw Binaries" --limit 1 --json databaseId --jq '.[0].databaseId')"
```

## 2. Install latest artifact for this machine architecture

From this repository root:

```bash
./scripts/install_zeroclaw.sh
```

This installs to `/usr/local/bin/zeroclaw` by default (or falls back to `~/.local/bin` if needed).

## 3. Restart runtime/service

If running as a background service:

```bash
zeroclaw service stop
zeroclaw service start
zeroclaw service status
```

If running in foreground mode, stop and restart:

```bash
zeroclaw daemon
```

## 4. Verify health

```bash
zeroclaw --version
zeroclaw status
zeroclaw doctor
zeroclaw channel doctor
```

## Upstream references

- Commands reference: https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/commands-reference.md
- Operations runbook: https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/operations-runbook.md
- One-click bootstrap: https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/one-click-bootstrap.md
- Upgrade-doc request issue: https://github.com/zeroclaw-labs/zeroclaw/issues/791
