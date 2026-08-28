# MikroTik Starlink Ocean Mode

A firewall whitelist mode for MikroTik RouterOS that blocks all outbound WAN
traffic except a curated list of apps, intended for sailing in open ocean with
Starlink.

## Why

Starlink's **Ocean** plan costs roughly **~6 USD/GB**. During an ocean passage
most background traffic is waste: OS updates, app telemetry, ad trackers,
sync agents. Ocean Mode flips the firewall into **whitelist-only** — only the
apps you actually need (messaging, weather, email) can
reach the internet. Everything else is dropped before it burns data.

This repo was born from the Starlink Ocean pricing update. It is a living
**alpha/beta** project: the whitelist is not fixed, add the domains your crew
uses.

## How it works

RouterOS firewall does **not** filter by domain — it filters by **IP**. Ocean
Mode bridges the gap in two steps:

1. Domains in `whitelist.conf` are added to an **address-list**
   (`ocean-whitelist`) as DNS names. RouterOS resolves each name to its IPs
   and keeps them updated at TTL expiry.
2. Four firewall rules in the `forward` chain implement the mode:
   - `accept` traffic to `ocean-whitelist` (the gate)
   - `accept` DNS (UDP + TCP) so clients can always resolve
   - `drop` everything else **out to WAN** (`out-interface-list=WAN`)

Turning the mode **on** enables the final `drop WAN` rule; turning it **off**
disables it again. Everything else (LAN, router itself) is untouched.

## Files

| File | Purpose |
|---|---|
| `install.rsc` | Idempotent installer: address-list + firewall rules + boot scheduler. **Run first.** |
| `ocean-on.rsc` | Imports the `ocean-on` script — enables Ocean Mode, logs session start. |
| `ocean-off.rsc` | Imports the `ocean-off` script — disables Ocean Mode, logs session end. |
| `ocean-report.rsc` | Imports the `ocean-report` script — prints a usage/session report. |
| `whitelist.conf` | The editable domain list (source of truth for the address-list). |
| `LICENSE` | MIT. |

## Install

```routeros
# On the router, after uploading the files (WinBox drag & drop or scp):
/import file-name=install.rsc
/import file-name=ocean-on.rsc
/import file-name=ocean-off.rsc
/import file-name=ocean-report.rsc
```

`install.rsc` is idempotent — run it again to re-apply without duplicates.

## Usage

```bash
# Enable Ocean Mode (from any machine that can SSH to the router)
ssh admin@<router-ip> '/system script run ocean-on'

# Check the report
ssh admin@<router-ip> '/system script run ocean-report'

# Disable Ocean Mode (back to normal, all traffic allowed)
ssh admin@<router-ip> '/system script run ocean-off'
```

Or run the same from WinBox Terminal.

### Default on reboot: Ocean OFF

The router always boots **Ocean OFF** (normal, everything open). A scheduler
(`ocean-boot`, `start-time=startup`) disables the drop rule on every reboot.

**Why:** if the router restarts at sea (power blip, upgrade) you are never cut
off — everything is reachable immediately. The trade-off is that protection is
off until you re-enable manually; auto-updates may consume data in the
meantime. Availability wins, by design.

## Whitelist

Edit `whitelist.conf`, then re-run `/import file-name=install.rsc`.

Current apps:
- **WhatsApp** — messaging, media
- **Windy** — weather
- **PredictWind** — weather routing
- **Gmail / Google** — mail
- **Outlook / Hotmail** — Microsoft 365 mail
- **X (Twitter)**

### Known limitations

- **No wildcard domains.** RouterOS address-lists cannot resolve `*.domain`
  entries (error: *not a valid dns name*). Only concrete, resolvable hostnames
  work. The list uses base domains (`google.com`, `microsoft.com`, …) which
  cover most subdomains' IP ranges.
- **"Only Gmail" is not perfectly isolatable.** Google shares many domains; in
  practice whitelisting `google.com` + `googleusercontent.com` opens most of
  Google, not just Gmail. Same for Microsoft.
- **CDN hosts** (akamaized / edgekey / edgesuite) are not listed because they
  can't be wildcard-resolved. If media/attachments fail, add the specific CDN
  hostname.
- **WhatsApp calls/voice** use extra ports/addresses beyond the listed
  domains. Verify if you rely on WhatsApp calls at sea.

## Log & persistence

`ocean-on` / `ocean-off` append `START`/`END` lines (timestamp + WAN rx/tx
counters) to **`ocean-sessions.txt`** on the router. `ocean-report` prints a
summary to the terminal (capture it over SSH).

> **Important (accepted limitation):** on devices **without a `flash`
> directory**, files created by `/file add` live in the **RAM disk** and are
> **lost on reboot**. This router has no `flash` dir, so the session log does
> not survive a reboot. The firewall rules, scripts and scheduler *are*
> persistent (stored in config). We accept this and document it rather than
> depend on an external server that a repo user may not have.

## Status

**Alpha/beta** — works and is tested on a **MikroTik hAP ax²** (board
`C52iG-5HaxD2HaxD`) running **RouterOS 7.23.2 stable**. It is a living
project, not a finished product.

## Test it — your experience matters

Ocean Mode is built for real boats, and the only honest way to harden it is
to run it. If you have a MikroTik and Starlink:

- **Try it in port first** (not at sea): install, `ocean-on`, use your apps,
  `ocean-off`. See the README install/usage above.
- **Report what breaks** — open an issue with your router model, RouterOS
  version, and which app/domain failed. Whitelists rot as services change
  their hosts.
- **Tell us what works** too — especially weather, mail and messaging combos
  your crew relies on at sea.
- **Fork if it serves you differently.** This is MIT, no strings. If your
  whitelist or flow fits a different crew or router line, fork it and make it
  yours — and consider opening a PR back so everyone benefits.

The more boats run it, the better the whitelist gets for everyone.

## Backup

Before touching the router, take a backup:

```bash
ssh admin@<router-ip> '/export file=pre-ocean-mode'
scp admin@<router-ip>:pre-ocean-mode.rsc ./
```

A binary backup for WinBox restore:

```bash
ssh admin@<router-ip> '/system backup save name=y2k-router-bin'
scp admin@<router-ip>:y2k-router-bin.backup ./
```

## License

MIT.
