import sqlite3
from pathlib import Path
import numpy as np

con = sqlite3.connect("data/private/psid.sqlite")
con.execute("DROP TABLE IF EXISTS temp.tutorial_pairs")
con.execute("""
CREATE TEMP TABLE tutorial_pairs AS
SELECT r.child_fid, r.child_pnum,
       r.father_fid AS parent_fid, r.father_pnum AS parent_pnum
FROM parent_ids r
JOIN persons c ON c.fid=r.child_fid AND c.pnum=r.child_pnum
JOIN persons p ON p.fid=r.father_fid AND p.pnum=r.father_pnum
WHERE r.father_fid>0 AND r.father_pnum BETWEEN 1 AND 995;
""")
assert con.execute("SELECT COUNT(*) FROM tutorial_pairs").fetchone()[0] == 29218


# Family income joins require BOTH the annual family ID and survey year.
income_rows = con.execute("""
SELECT w.fid, w.pnum, w.year, f.real_income
FROM waves w JOIN psid_family_income f
 ON w.family=f.family AND w.year=f.wave
WHERE f.valid=1 AND (
 (w.year BETWEEN 1969 AND 1971 AND w.relation=1) OR
 (w.year IN (1985,1986,1987,1995,1996,1997) AND w.relation=10));
""").fetchall()

# Inspect the aggregation used by the full matching script.
means = con.execute("""
SELECT fid,pnum,window,AVG(real_income) AS mean_income,
 MAX(CASE WHEN year IN (1970,1986,1996)
          THEN real_income END) AS single_income,
 COUNT(*) AS n_valid
FROM psid_income GROUP BY fid,pnum,window HAVING COUNT(*)=3;
""").fetchall()
con.executescript(Path("scripts/psid_match.sql").read_text())
# Inspect the final two-generation join: one row per selected son.
joined = con.execute("""
SELECT k.child_fid,k.child_pnum,
 p.mean_income AS father_mean,e.mean_income AS son_early_mean,
 m.mean_income AS son_mid_mean
FROM psid_candidates k
JOIN psid_measures p
 ON p.fid=k.parent_fid AND p.pnum=k.parent_pnum AND p.window='parent'
JOIN psid_measures e
 ON e.fid=k.child_fid AND e.pnum=k.child_pnum AND e.window='early'
JOIN psid_measures m
 ON m.fid=k.child_fid AND m.pnum=k.child_pnum AND m.window='mid';
""").fetchall()
assert len(joined) == 191


specs = [("Early single","p_single","c_early_single"),
         ("Midlife single","p_single","c_mid_single"),
         ("Early average","p_mean","c_early_mean"),
         ("Midlife average","p_mean","c_mid_mean")]
for label, px, cy in specs:  # fixed column names, not user input
    rows = con.execute(f"SELECT {px},{cy} FROM psid_matched").fetchall()
    x,y = np.log(np.asarray(rows,dtype=float)).T
    X = np.column_stack([np.ones(len(x)),x])
    beta = np.linalg.lstsq(X,y,rcond=None)[0][1]
    print(f"{label}: n={len(x)}, IGE={beta:.3f}")
con.close()
