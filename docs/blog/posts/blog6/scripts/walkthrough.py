import sqlite3

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


n_pairs = con.execute(
    "SELECT COUNT(*) FROM tutorial_pairs"
).fetchone()[0]
print(f"Recorded father–child links: {n_pairs:,}")
assert n_pairs == 29218


con.executescript("""
DROP TABLE IF EXISTS psid_candidates;
CREATE TABLE psid_candidates AS
SELECT l.*, c.birth_year,
 (SELECT age FROM waves w WHERE w.fid=l.parent_fid AND w.pnum=l.parent_pnum AND year=1970) AS parent_age_1970,
 (SELECT age FROM waves w WHERE w.fid=l.child_fid AND w.pnum=l.child_pnum AND year=1986) AS child_age_1986,
 (SELECT age FROM waves w WHERE w.fid=l.child_fid AND w.pnum=l.child_pnum AND year=1996) AS child_age_1996
FROM tutorial_pairs l JOIN persons c ON c.fid=l.child_fid AND c.pnum=l.child_pnum
WHERE c.sex=1 AND c.birth_year BETWEEN 1955 AND 1959 AND c.birth_discrepancy=0
 AND (SELECT COUNT(*) FROM waves w WHERE w.fid=l.parent_fid AND w.pnum=l.parent_pnum
      AND year IN (1969,1970,1971) AND relation=1 AND age BETWEEN 25 AND 65)=3
 AND (SELECT COUNT(*) FROM waves w WHERE w.fid=l.child_fid AND w.pnum=l.child_pnum
      AND year IN (1985,1986,1987,1995,1996,1997) AND relation=10)=6;
""")


con.executescript("""
DROP TABLE IF EXISTS psid_income;
CREATE TABLE psid_income AS
SELECT w.fid,w.pnum,w.year,f.real_income,
 CASE WHEN w.year BETWEEN 1969 AND 1971 THEN 'parent'
      WHEN w.year BETWEEN 1985 AND 1987 THEN 'early' ELSE 'mid' END AS window
FROM waves w JOIN psid_family_income f ON f.wave=w.year AND f.family=w.family
WHERE f.valid=1 AND ((w.year BETWEEN 1969 AND 1971 AND w.relation=1)
 OR (w.year IN (1985,1986,1987,1995,1996,1997) AND w.relation=10));
CREATE UNIQUE INDEX psid_income_key ON psid_income(fid,pnum,year);
""")


con.executescript("""
DROP TABLE IF EXISTS psid_measures;
CREATE TABLE psid_measures AS
SELECT fid,pnum,window,AVG(real_income) AS mean_income,
 MAX(CASE WHEN year IN (1970,1986,1996) THEN real_income END) AS single_income,
 COUNT(*) AS n_valid
FROM psid_income GROUP BY fid,pnum,window HAVING COUNT(*)=3;
""")


con.executescript("""
DROP TABLE IF EXISTS psid_matched;
CREATE TABLE psid_matched AS
SELECT k.child_fid,k.child_pnum,k.parent_fid,k.parent_pnum,k.birth_year,
 k.parent_age_1970,k.child_age_1986,k.child_age_1996,
 p.single_income AS p_single,p.mean_income AS p_mean,
 e.single_income AS c_early_single,e.mean_income AS c_early_mean,
 m.single_income AS c_mid_single,m.mean_income AS c_mid_mean
FROM psid_candidates k
JOIN psid_measures p ON p.fid=k.parent_fid AND p.pnum=k.parent_pnum AND p.window='parent'
JOIN psid_measures e ON e.fid=k.child_fid AND e.pnum=k.child_pnum AND e.window='early'
JOIN psid_measures m ON m.fid=k.child_fid AND m.pnum=k.child_pnum AND m.window='mid';
""")


n_pairs = con.execute("SELECT COUNT(*) FROM psid_matched").fetchone()[0]
n_sons = con.execute("""
SELECT COUNT(*) FROM (
 SELECT DISTINCT child_fid,child_pnum FROM psid_matched
);
""").fetchone()[0]
n_fathers = con.execute("""
SELECT COUNT(*) FROM (
 SELECT DISTINCT parent_fid,parent_pnum FROM psid_matched
);
""").fetchone()[0]
assert n_pairs == n_sons == 191
assert n_fathers == 170
print(f"Complete sample: {n_sons} sons, {n_fathers} fathers")


import numpy as np

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
