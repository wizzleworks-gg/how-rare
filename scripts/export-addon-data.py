#!/usr/bin/env python3
"""Export the Achievement Rarity addon's data files (baked Lua tables).

Reads the same tables the gratz.gg site reads — public.achievement_rarity +
public.rarity_meta (the rarity counter's output) — so the addon cannot disagree
with the site. Emits into AchievementRarity/Data/:

  Rarity.lua  — achievement_id -> {us, eu, global} account counts, packed
  Meta.lua    — as-of date + per-region active-account denominators

Releases ship PROD numbers. Tunnel to the prod DB first, then point at it:

  ssh -N -L 15432:localhost:5432 root@<prod-host> &
  .venv/bin/python scripts/export-addon-data.py \
      --database-url postgresql://gratz:gratz@localhost:15432/gratz

Dev (local compose DB, default URL): .venv/bin/python scripts/export-addon-data.py
"""

import argparse
from datetime import date
from pathlib import Path

import psycopg

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO_ROOT / "AchievementRarity" / "Data"
DEFAULT_DB = "postgresql://gratz:gratz@localhost:5432/gratz"

REGIONS = ("us", "eu", "global")  # index order of the packed Lua triples


def fetch(db_url: str):
    with psycopg.connect(db_url) as conn:
        meta = {
            region: (active, computed.date())
            for region, active, computed in conn.execute(
                "SELECT region, active_accounts, computed_at FROM public.rarity_meta"
            )
        }
        rows = conn.execute(
            """
            SELECT achievement_id,
                   COALESCE(MAX(account_count) FILTER (WHERE region = 'us'), 0),
                   COALESCE(MAX(account_count) FILTER (WHERE region = 'eu'), 0),
                   COALESCE(MAX(account_count) FILTER (WHERE region = 'global'), 0)
              FROM public.achievement_rarity
             GROUP BY achievement_id
             ORDER BY achievement_id
            """
        ).fetchall()
    return meta, rows


def header(as_of: date) -> str:
    return (
        "-- GENERATED from gratz.gg - do not edit by hand.\n"
        f"-- Rarity counter snapshot as of {as_of.isoformat()}.\n"
    )


def write_meta(out: Path, meta: dict) -> date:
    as_of = max(computed for _, computed in meta.values())
    accounts = ", ".join(f"{r} = {meta[r][0]}" for r in REGIONS if r in meta)
    out.write_text(
        header(as_of)
        + "local _, G = ...\n"
        + "G.Meta = {\n"
        + f'    asOf = "{as_of.isoformat()}",\n'
        + f"    accounts = {{ {accounts} }},\n"
        + "}\n"
    )
    return as_of


def write_rarity(out: Path, rows, as_of: date) -> None:
    lines = [header(as_of), "local _, G = ...\n", "G.RarityCounts = {\n"]
    lines += [f"[{aid}]={{{us},{eu},{glob}}},\n" for aid, us, eu, glob in rows]
    lines.append("}\n")
    out.write_text("".join(lines))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-url", default=DEFAULT_DB)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    meta, rows = fetch(args.database_url)
    # A release ships these files verbatim; an empty result means a broken or
    # half-fetched source, never a valid state (same stance as db/derive's
    # guard). Refuse rather than bake a zeroed addon.
    if not meta or not rows:
        raise SystemExit("refusing to write: empty rarity/meta result")
    args.out.mkdir(parents=True, exist_ok=True)
    as_of = write_meta(args.out / "Meta.lua", meta)
    write_rarity(args.out / "Rarity.lua", rows, as_of)
    print(f"Wrote {len(rows)} achievements (as of {as_of}) to {args.out}")


if __name__ == "__main__":
    main()
