"""Décale de +4 h les cours legacy (créés avant le correctif de fuseau).

État constaté le 6 août : après la première correction, les cours legacy sont
stockés 4 h trop tôt (ex. stocké 01:00 UTC → affiché 03:00 Paris, alors que le
cours réel est à 07:00). Ce script ajoute 4 h aux cours créés avant le
18 juillet 2026 (les cours créés depuis l'app corrigée sont déjà justes).

Aperçu (heure de Paris affichée avant → après) + confirmation avant écriture.
⚠️ À NE LANCER QU'UNE SEULE FOIS.

Usage :
  pip install psycopg2-binary
  python scripts/shift_course_times_plus4.py
"""
import getpass
from zoneinfo import ZoneInfo

import psycopg2

PARIS = ZoneInfo("Europe/Paris")
FIX_DEPLOYED_AT = "2026-07-18T20:00:00+00:00"
SHIFT_HOURS = 4

url = getpass.getpass("External Database URL Render (saisie masquée) : ").strip()
conn = psycopg2.connect(url, sslmode="require")
cur = conn.cursor()

cur.execute(
    "SELECT id, name, start_time FROM courses "
    "WHERE created_at < %s ORDER BY start_time LIMIT 12;",
    (FIX_DEPLOYED_AT,),
)
sample = cur.fetchall()
cur.execute(
    "SELECT COUNT(*) FROM courses WHERE created_at < %s;", (FIX_DEPLOYED_AT,)
)
total = cur.fetchone()[0]
if not total:
    print("Aucun cours legacy — rien à corriger.")
    raise SystemExit

print(f"\n{total} cours legacy. Échantillon (heure de Paris avant → après) :\n")
from datetime import timedelta

for cid, name, start in sample:
    before = start.astimezone(PARIS)
    after = (start + timedelta(hours=SHIFT_HOURS)).astimezone(PARIS)
    print(f"  #{cid:>4} {name[:26]:<26} {before:%a %d/%m %H:%M} → {after:%H:%M}")

if input(f"\n⚠️  +{SHIFT_HOURS} h sur {total} cours, UNE seule fois. Appliquer ? (oui/non) : ").strip().lower() != "oui":
    print("Abandon, rien modifié.")
    raise SystemExit

cur.execute(
    "UPDATE courses SET start_time = start_time + interval '4 hours', "
    "end_time = end_time + interval '4 hours' WHERE created_at < %s;",
    (FIX_DEPLOYED_AT,),
)
conn.commit()
print(f"\n✅ {cur.rowcount} cours corrigés (+{SHIFT_HOURS} h).")
conn.close()
