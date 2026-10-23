"""Read official PSID ASCII using its SAS column specifications; no fabricated data.
Only aggregate diagnostics go to --out; individual records stay in --db locally.
"""
from pathlib import Path
import argparse, csv, re, sqlite3, hashlib, json
from collections import Counter

ap=argparse.ArgumentParser()
ap.add_argument('--raw',type=Path,required=True)
ap.add_argument('--db',type=Path,required=True)
ap.add_argument('--out',type=Path,required=True)
a=ap.parse_args();a.db.parent.mkdir(parents=True,exist_ok=True);a.out.mkdir(parents=True,exist_ok=True)
if a.db.exists(): raise SystemExit('Database already exists; select a new output path rather than overwrite it.')
def schema(path,prefix):
    text=path.read_text(encoding='utf-8-sig')
    positions={v:(int(lo)-1,int(hi)) for v,lo,hi in re.findall(r'('+prefix+r'\w+)\s+(\d+)\s*-\s*(\d+)',text.split('   INPUT ')[1])}
    labels=dict(re.findall(r'('+prefix+r'\w+)\s+LABEL="([^"]+)"',text))
    return positions,labels
ip,labels=schema(a.raw/'ind2023er/IND2023ER.sas','ER')
pp,_=schema(a.raw/'pid23/PID23.sas','PID')
def get(line,pos,name):
    lo,hi=pos[name];x=line[lo:hi].strip();return int(x) if x else None
years=[1969,1970,1971,1985,1986,1987,1995,1996,1997]
layout={}
for year in years:
    def find(term):
        hits=[k for k,v in labels.items() if term in v and v.strip().endswith(str(year)[-2:])]
        assert len(hits)==1,(term,year,hits)
        return hits[0]
    rel=[k for k,v in labels.items() if ('RELATIONSHIP TO HEAD' in v or 'RELATION TO HEAD' in v) and v.strip().endswith(str(year)[-2:])]
    assert len(rel)==1
    layout[year]=dict(family=next(k for k,v in labels.items() if v==f'{year} INTERVIEW NUMBER'),
                      sequence=find('SEQUENCE NUMBER'),age=find('AGE OF INDIVIDUAL'),relation=rel[0])
birth_vars=[k for k,v in labels.items() if re.search(r'YEAR IND(?:IVIDUAL)? BORN\s+\d{2}$',v)]
con=sqlite3.connect(a.db)
con.executescript('''PRAGMA foreign_keys=ON;
 CREATE TABLE persons(fid INTEGER,pnum INTEGER,sex INTEGER,birth_year INTEGER,birth_discrepancy INTEGER,PRIMARY KEY(fid,pnum));
 CREATE TABLE waves(fid INTEGER,pnum INTEGER,year INTEGER,family INTEGER,sequence INTEGER,age INTEGER,relation INTEGER,
 PRIMARY KEY(fid,pnum,year),FOREIGN KEY(fid,pnum) REFERENCES persons(fid,pnum));
 CREATE TABLE parent_ids(child_fid INTEGER,child_pnum INTEGER,mother_fid INTEGER,mother_pnum INTEGER,
 father_fid INTEGER,father_pnum INTEGER,PRIMARY KEY(child_fid,child_pnum));''')
hashes={};n_ind=0;birth_conflicts=0
with (a.raw/'ind2023er/IND2023ER.txt').open('rb') as f:
    digest=hashlib.sha256()
    for line in f:
        digest.update(line);n_ind+=1
        assert len(line.rstrip(b'\r\n'))==6553
        fid,pnum=get(line,ip,'ER30001'),get(line,ip,'ER30002')
        births=[get(line,ip,k) for k in birth_vars];births=[b for b in births if b and 1850<=b<=2023]
        birth=Counter(births).most_common(1)[0][0] if births else None
        conflict=int(bool(births) and max(births)-min(births)>1);birth_conflicts+=conflict
        con.execute('INSERT INTO persons VALUES (?,?,?,?,?)',(fid,pnum,get(line,ip,'ER32000'),birth,conflict))
        for year,cols in layout.items():
            values={k:get(line,ip,v) for k,v in cols.items()}
            # Sequence 1-20: individual present in the responding family unit.
            if values['family'] and 1<=values['sequence']<=20 and 0<=values['age']<120:
                con.execute('INSERT INTO waves VALUES (?,?,?,?,?,?,?)',
                            (fid,pnum,year,values['family'],values['sequence'],values['age'],values['relation']))
hashes['IND2023ER.txt']=digest.hexdigest()
n_pid=0
with (a.raw/'pid23/PID23.txt').open('rb') as f:
    digest=hashlib.sha256()
    for line in f:
        digest.update(line);n_pid+=1
        assert len(line.rstrip(b'\r\n'))==75
        con.execute('INSERT INTO parent_ids VALUES (?,?,?,?,?,?)',tuple(get(line,pp,k) for k in ['PID2','PID3','PID4','PID5','PID23','PID24']))
hashes['PID23.txt']=digest.hexdigest()
con.executescript('''CREATE TABLE links AS
 SELECT r.child_fid,r.child_pnum,r.father_fid AS parent_fid,r.father_pnum AS parent_pnum,'father' AS parent_type
 FROM parent_ids r JOIN persons c ON c.fid=r.child_fid AND c.pnum=r.child_pnum
 JOIN persons p ON p.fid=r.father_fid AND p.pnum=r.father_pnum
 WHERE r.father_fid>0 AND r.father_pnum BETWEEN 1 AND 995
 UNION ALL
 SELECT r.child_fid,r.child_pnum,r.mother_fid,r.mother_pnum,'mother'
 FROM parent_ids r JOIN persons c ON c.fid=r.child_fid AND c.pnum=r.child_pnum
 JOIN persons p ON p.fid=r.mother_fid AND p.pnum=r.mother_pnum
 WHERE r.mother_fid>0 AND r.mother_pnum BETWEEN 1 AND 995;
 CREATE UNIQUE INDEX unique_parent_link ON links(child_fid,child_pnum,parent_type);
 CREATE INDEX waves_head ON waves(fid,pnum,year,relation);''')
def save(name,query):
    cur=con.execute(query)
    with (a.out/name).open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow([x[0] for x in cur.description]);w.writerows(cur)
save('linkage_counts.csv','''SELECT parent_type,COUNT(*) AS links,COUNT(DISTINCT printf('%d:%d',parent_fid,parent_pnum)) AS distinct_parents
 FROM links GROUP BY parent_type''')
save('wave_coverage.csv','''SELECT year,COUNT(*) AS responding_persons,SUM(CASE WHEN relation IN (1,10) THEN 1 ELSE 0 END) AS heads FROM waves GROUP BY year''')
# Structural availability only: no income or IGE can be computed yet.
save('father_son_cohort_screen.csv','''WITH availability AS (
 SELECT l.*,c.birth_year,c.birth_discrepancy,c.sex,
 (SELECT COUNT(*) FROM waves w WHERE w.fid=l.parent_fid AND w.pnum=l.parent_pnum
   AND w.year IN (1969,1970,1971) AND w.relation=1 AND w.age BETWEEN 25 AND 65) AS parent_head_years,
 (SELECT COUNT(*) FROM waves w WHERE w.fid=l.child_fid AND w.pnum=l.child_pnum
   AND w.year IN (1985,1986,1987) AND w.relation=10) AS child_early_head_years,
 (SELECT COUNT(*) FROM waves w WHERE w.fid=l.child_fid AND w.pnum=l.child_pnum
   AND w.year IN (1995,1996,1997) AND w.relation=10) AS child_mid_head_years
 FROM links l JOIN persons c ON c.fid=l.child_fid AND c.pnum=l.child_pnum
 WHERE l.parent_type='father' AND c.sex=1 AND c.birth_year BETWEEN 1945 AND 1969
 AND c.birth_discrepancy=0)
 SELECT (birth_year/5)*5 AS cohort_start,COUNT(*) AS linked_sons,
 SUM(parent_head_years=3) AS parent_all3,
 SUM(parent_head_years=3 AND child_early_head_years=3 AND child_mid_head_years=3) AS all9_head_records
 FROM availability GROUP BY cohort_start ORDER BY cohort_start''')
assert n_ind==85536 and n_pid==103725
assert not con.execute('PRAGMA foreign_key_check').fetchall()
con.commit();con.close()
(a.out/'manifest.json').write_text(json.dumps(dict(individual_records=n_ind,parent_id_records=n_pid,
 birth_year_conflicts_over_one_year=birth_conflicts,input_sha256=hashes,variables=layout,
 status='Identifiers and age/headship coverage verified; family income files not supplied; no IGE estimated.'),indent=2),encoding='utf-8')
print(json.dumps(dict(individual_records=n_ind,parent_id_records=n_pid,status='SQL linkage completed; income pending')))
