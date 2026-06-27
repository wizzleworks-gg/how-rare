# How Rare?

A World of Warcraft companion addon that shows **how rare each achievement is** —
the share of accounts that have earned it — right where you see achievements in
game. The numbers come from [gratz.gg](https://gratz.gg), baked in as a periodic
snapshot.

## Features

One master switch (**How Rare? enabled**) governs every automatic
surface; the toast and its screenshot have their own toggles beneath it. Open the
options with `/howrare` or Settings → AddOns → How Rare?.

- **Rarity everywhere** — every achievement tooltip, incoming guild/nearby chat
  announcement, and Blizzard achievement-panel row gets its rarity:
  `Rarity: 3% of active accounts — gratz.gg (24 June 2026)`. Panel rows are tinted
  by rarity tier (the loot-quality colours), so you can browse by rarity at a
  glance while scrolling.
- **Earned toast** — a companion toast on achievement earn carrying the rarity,
  styled to be screenshotted; it replaces Blizzard's own alert while on (optional
  auto-screenshot on earn). `/howrare share` (or the "Share rarest achievement"
  keybind) re-pops your rarest earned achievement as a shareable card.

## Privacy

Everything stays on your machine. The addon reads from Blizzard's own in-game API
and keeps its settings in local SavedVariables — it never sends anything anywhere.
(WoW addons can't reach the internet at runtime, and this one transmits nothing.)

## How the data works

WoW addons are sandboxed — no internet access at runtime — so every number ships
baked in, as a periodic snapshot from gratz.gg. Each figure carries its own
"as of" date, and a new release is a fresh snapshot.

## Development

Symlink the addon into your WoW install and `/reload` after edits:

```sh
ln -s "$(pwd)/HowRare" \
  "/Applications/World of Warcraft/_retail_/Interface/AddOns/HowRare"
```

### Refreshing the shipped data

The numbers in `HowRare/Data/` are a snapshot pulled from the gratz.gg
database (`scripts/export-addon-data.py`, dev/CI only — never shipped in the zip).
Refresh them before a release:

```sh
python -m venv .venv && .venv/bin/pip install -r requirements.txt
# Tunnel to the prod DB, then run the export against it:
ssh -N -L 15432:localhost:5432 root@<prod-host> &
.venv/bin/python scripts/export-addon-data.py \
    --database-url postgresql://gratz:gratz@localhost:15432/gratz
```

Commit the regenerated `HowRare/Data/*.lua`.

### Releasing

Add a `## <version>` section to `CHANGELOG.md` for the release — CI uploads that
section verbatim as the CurseForge changelog (it falls back to "Release `<version>`"
if no matching section exists). Then tag the commit — CI
(`.github/workflows/release.yml`) stamps the tag as the version, builds the zip, and
uploads it to CurseForge:

```sh
git tag v1.0.0 && git push --tags
```

The tag version must match the `CHANGELOG.md` heading (and the `## Version:` in the
TOC, which the tag also overwrites). `scripts/release.sh` builds the same zip locally
for testing. CurseForge upload is inert until the `CF_API_KEY` secret and
`CF_PROJECT_ID` variable are configured on the repo.

## License

© 2026 gratz.gg. All rights reserved. See [LICENSE](LICENSE).
