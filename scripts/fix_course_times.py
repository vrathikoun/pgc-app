"""Correction ponctuelle des heures des cours en base (Render).

Contexte : avant le correctif de fuseau (commit b7b3441, 18 juillet), l'app
envoyait les heures SANS fuseau et le backend les stockait comme de l'UTC alors
que c'était de l'heure de Paris. Les cours créés avant cette date s'affichent
donc décalés de 2 h.

Ce script réinterprète l'heure « murale » stockée comme de l'heure de Paris et
réécrit le bon instant UTC. Aperçu + confirmation avant toute écriture.
⚠️ À NE LANCER QU'UNE SEULE FOIS (le lancer deux fois décalerait de 2 h de trop).

Usage :
  pip install psycopg2-binary
  python scripts/fix_course_times.py
  → colle l'External Database URL Render quand demandé.
"""
import getpass
from datetime import timezone
from zoneinfo import ZoneInfo

import psycopg2

PARIS = ZoneInfo("Europe/Paris")

url = getpass.getpass("External Database URL Render (saisie masquée) : ").strip()
conn = psycopg2.connect(url, sslmode="require")
cur = conn.cursor()

# Seuls les cours créés AVANT le déploiement du correctif de fuseau sont faux ;
# ceux créés après (app qui envoie l'offset) sont déjà corrects.
FIX_DEPLOYED_AT = "2026-07-18T20:00:00+00:00"

cur.execute(
    "SELECT id, name, start_time, end_time FROM courses "
    "WHERE created_at < %s ORDER BY start_time;",
    (FIX_DEPLOYED_AT,),
)
rows = cur.fetchall()
if not rows:
    print("Aucun cours legacy à corriger (tous créés après le correctif).")
    raise SystemExit


def reinterpret(dt):
    """L'heure murale stockée (lue en UTC) était en réalité de l'heure de Paris."""
    wall = dt.astimezone(timezone.utc).replace(tzinfo=None)
    return wall.replace(tzinfo=PARIS).astimezone(timezone.utc)


print(f"\n{len(rows)} cours. Aperçu (heure de Paris affichée) :\n")
plan = []
for cid, name, start, end in rows:
    ns, ne = reinterpret(start), reinterpret(end)
    plan.append((cid, ns, ne))
    print(
        f"  #{cid:>4} {name[:28]:<28} "
        f"{start.astimezone(PARIS):%d/%m %H:%M} → {ns.astimezone(PARIS):%d/%m %H:%M}"
    )

if input("\n⚠️  À ne lancer qu'UNE fois. Appliquer ? (oui/non) : ").strip().lower() != "oui":
    print("Abandon, rien modifié.")
    raise SystemExit

for cid, ns, ne in plan:
    cur.execute(
        "UPDATE courses SET start_time=%s, end_time=%s WHERE id=%s;", (ns, ne, cid)
    )
conn.commit()
print(f"\n✅ {len(plan)} cours corrigés.")
conn.close()
