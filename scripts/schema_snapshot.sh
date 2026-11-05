#!/usr/bin/env bash
# Skriver et øjebliksbillede af den levende database (public-skema + cron-jobs) til supabase/schema/public.sql.
# Kun læsning. Kræver Supabase CLI logget ind (supabase login). Kør fra repo-roden: ./scripts/schema_snapshot.sh
# Kør den efter hver migration, og commit resultatet sammen med migrationen.
set -euo pipefail
cd "$(dirname "$0")/.."
REF=apagcfedizgjnnuefzfo
OUT=supabase/schema/public.sql
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

supabase db query -f scripts/schema_snapshot.sql --remote=$REF --read-only --output-format json >"$TMP/ddl.json" 2>"$TMP/err" || { cat "$TMP/err" >&2; exit 1; }
supabase db query "select jobname, schedule, command from cron.job order by jobname" --remote=$REF --read-only --output-format json >"$TMP/cron.json" 2>"$TMP/err" || { cat "$TMP/err" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
python3 -I - "$TMP/ddl.json" "$TMP/cron.json" "$OUT" <<'PY'
import json, sys
ddl, cron, out = sys.argv[1:4]
rows = json.load(open(ddl))["rows"]
jobs = json.load(open(cron))["rows"]
sec = {1: "Udvidelser", 2: "Enums", 3: "Sekvenser", 4: "Tabeller", 5: "Nøgler og checks", 6: "Fremmednøgler",
       7: "Indeks", 8: "Views", 9: "Funktioner", 10: "Triggere", 11: "Row level security", 12: "Policies",
       13: "Tabelrettigheder", 14: "Funktionsrettigheder", 15: "Realtime"}
lines = ["-- Øjebliksbillede af det levende public-skema i Supabase-projektet apagcfedizgjnnuefzfo.",
         "-- Genereret af scripts/schema_snapshot.sh. Ret ikke i hånden.",
         "-- Dette er sandheden om databasen; migrationerne i supabase/migrations er historikken.",
         "-- Data (spillere, klubber, formationer) er ikke med.", ""]
cur = None
for r in rows:
    if r["s"] != cur:
        cur = r["s"]
        lines += ["", f"-- ===== {sec.get(cur, cur)} =====", ""]
    lines.append(r["ddl"].rstrip())
    if cur in (4, 8, 9):
        lines.append("")
lines += ["", "-- ===== Cron-jobs (pg_cron) =====", ""]
for j in jobs:
    lines.append(f"select cron.schedule('{j['jobname']}', '{j['schedule']}', $cron${j['command']}$cron$);")
open(out, "w").write("\n".join(lines).rstrip() + "\n")
print(f"{out}: {len(rows)} objekter, {len(jobs)} cron-jobs")
PY
