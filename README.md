# tekservix-cli

[![tests](https://github.com/TekservixHQ/tekservix-cli/actions/workflows/tests.yml/badge.svg)](https://github.com/TekservixHQ/tekservix-cli/actions/workflows/tests.yml)

Official command-line tools for the SMS Gora SMS Gateway and the **WAservix WhatsApp API Gateway** by Tekservix.

Command-line tools for two Tekservix messaging APIs:

- **`smsgora`**: send and receive SMS through your own Android phones with the [SMS Gora SMS Gateway](https://tekservix.com/smsgora/)
- **`waservix`**: send WhatsApp messages from your own number with the [WAservix WhatsApp API Gateway](https://tekservix.com/waservix/)

Great for cron jobs, CI pipelines, server monitoring, backups and any shell script that needs to alert a phone. Plain bash + curl (jq is used for pretty output when installed).

## Install

**Homebrew** (macOS and Linux):

```bash
brew install tekservixhq/tap/tekservix
```

**Manual** (any Unix with bash and curl):

```bash
curl -fsSL https://github.com/TekservixHQ/tekservix-cli/archive/refs/tags/v1.0.0.tar.gz | tar xz
sudo install tekservix-cli-1.0.0/bin/smsgora tekservix-cli-1.0.0/bin/waservix /usr/local/bin/
```

## Setup

You need a Tekservix account and API keys. Keep them in your environment, not in scripts you share:

```bash
export SMSGORA_KEY=sgk_...      # SMS Gora -> API keys
export WASERVIX_KEY=...         # WAservix dashboard -> Devices -> API key of your number
```

## smsgora

```bash
smsgora send --to +15551234567 --message "Backup finished OK"
smsgora send --to "+15551234567,+447700900123" --message "Server down" --device 42 --sim 1
smsgora send --to +15551234567 --message "Meeting at 10:00" --schedule 2026-12-01T08:00:00Z

smsgora status 1873             # queued, dispatched, sent, delivered or failed
smsgora cancel 1874
smsgora inbox --limit 20        # received SMS
smsgora devices                 # your linked phones
smsgora account                 # plan and usage
smsgora api GET /webhooks       # any other endpoint
```

## waservix

```bash
waservix send --to +15551234567 --text "Deploy finished"
waservix send --to +15551234567 --image https://example.com/chart.png --caption "Today's sales"
waservix send --to +15551234567 --document https://example.com/report.pdf --filename Report.pdf
waservix send --to 120363040000000000@g.us --text "Team meeting at 3pm"   # a group

waservix status 58213           # queued, sent, delivered, read, played or failed
waservix check +15551234567     # is this number on WhatsApp?
waservix connection             # connection status of your number
waservix groups
waservix api GET /contacts      # any other endpoint
```

## Scripting

Commands print the JSON `data` of the answer and exit with:

- `0` on success
- `1` on an API error (the message goes to stderr; for WAservix, 503 means the number is reconnecting)
- `2` on a usage error or a missing key

```bash
# Alert when the disk is almost full (cron)
used=$(df / | awk 'NR==2 {print $5+0}')
[ "$used" -gt 90 ] && smsgora send --to +15551234567 --message "Disk at ${used}% on $(hostname)"

# GitHub Actions: notify on failure
- if: failure()
  run: waservix send --to "$PHONE" --text "Build failed: $GITHUB_REPOSITORY"
  env:
    WASERVIX_KEY: ${{ secrets.WASERVIX_KEY }}
```

WAservix is not Meta's official WhatsApp Business Platform: WhatsApp's spam rules apply to your number, so only message people who expect to hear from you.

## More from Tekservix

- [AI Sales Agent](https://tekservix.com/ai-sales-agent): answers customers on WhatsApp and SMS using your website's content
- [Website to App](https://tekservix.com/mobile-apps): turn your website into Android and iOS apps
- Client libraries for 15+ languages, n8n and Node-RED: [github.com/TekservixHQ](https://github.com/TekservixHQ)

## License

MIT
