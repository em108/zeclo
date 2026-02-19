# ZeroClaw First-Time Setup (Install -> Login -> Telegram)

Last updated: February 19, 2026

## 1. Install / update the binary

From this repo:

```bash
./scripts/install_zeroclaw.sh
```

Verify:

```bash
zeroclaw --version
```

## 2. Configure provider auth

Choose one path.

### A) API key providers (example: OpenRouter)

```bash
zeroclaw onboard --api-key "sk-..." --provider openrouter
```

### B) OpenAI Codex subscription login

```bash
zeroclaw auth login --provider openai-codex --device-code
zeroclaw auth status
```

### C) Anthropic subscription token

```bash
zeroclaw auth paste-token --provider anthropic
zeroclaw auth status
```

You can also do full wizard mode:

```bash
zeroclaw onboard --interactive
```

## 3. Set Telegram credentials

1. Message `@BotFather` in Telegram.
2. Create a bot and copy the bot token.
3. Configure Telegram via onboarding flow:

```bash
zeroclaw onboard --channels-only
```

Or directly in `~/.zeroclaw/config.toml`:

```toml
[channels_config.telegram]
bot_token = "123456:telegram-token"
allowed_users = []
```

Use `allowed_users = []` for deny-by-default, then approve identities intentionally.

## 4. Start runtime

Foreground (quick test):

```bash
zeroclaw daemon
```

Persistent background service:

```bash
zeroclaw service install
zeroclaw service start
zeroclaw service status
```

## 5. Approve Telegram user identity

Send a message to your bot from Telegram. If unauthorized, bind your identity:

```bash
zeroclaw channel bind-telegram 123456789
```

Then test again.

## 6. Health checks

```bash
zeroclaw status
zeroclaw doctor
zeroclaw channel doctor
```

Linux service logs:

```bash
journalctl --user -u zeroclaw.service -f
```

## 7. After future updates

Update binary:

```bash
./scripts/install_zeroclaw.sh
```

Restart service:

```bash
zeroclaw service stop
zeroclaw service start
zeroclaw service status
```

## 8. Recommended hardening

```bash
chmod 600 ~/.zeroclaw/config.toml
```

## Upstream references

- Commands reference: https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/commands-reference.md
- Channels reference: https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/channels-reference.md
- Operations runbook: https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/operations-runbook.md
- Upgrade-doc request issue: https://github.com/zeroclaw-labs/zeroclaw/issues/791
