"""Real PSID family-income analysis. Inputs are local licensed files, not public assets.
Run prepare_psid_linkage.py first. No microdata are written to the public output directory.
"""
from pathlib import Path
from zipfile import ZipFile
import argparse,csv,re,sqlite3,json,hashlib,sys
import numpy as np

p=argparse.ArgumentParser();p.add_argument('--raw',type=Path,required=True);p.add_argument('--db',type=Path,required=True)
p.add_argument('--out',type=Path,required=True);p.add_argument('--cpi',type=Path,required=True);a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
if not a.db.exists():raise SystemExit('Run the official-file linkage preparation first.')
mapping={1969:('V442','V529',99999),1970:('V1102','V1514',99999),1971:('V1802','V2226',99999),
1985:('V11102','V12371',999999),1986:('V12502','V13623',9999999),1987:('V13702','V14670',9999999),
1995:('ER5002','ER6993',9999999),1996:('ER7002','ER9244',9999999),1997:('ER10002','ER12079',999999)}
with a.cpi.open() as f:cpi={int(r['year']):float(r['cpi']) for r in csv.DictReader(f)}
con=sqlite3.connect(a.db);con.execute('PRAGMA foreign_keys=ON')
con.executescript('''DROP TABLE IF EXISTS psid_family_income;
 CREATE TABLE psid_family_income(wave INTEGER,family INTEGER,nominal REAL,real_income REAL,valid INTEGER,
 PRIMARY KEY(wave,family));''')
metadata=[]
for year,(idvar,incvar,ceiling) in mapping.items():
    path=next(a.raw.glob(f'fam{year}*.zip'))
    with ZipFile(path) as z:
        sn=next(n for n in z.namelist() if n.lower().endswith('.sas') and 'format' not in n.lower())
        sas=z.read(sn).decode('utf-8-sig');inp=sas.split('   INPUT ')[1]
        pos={v:(int(lo)-1,int(hi)) for v,lo,hi in re.findall(r'(\w+)\s+(\d+)\s*-\s*(\d+)',inp)}
        label=re.search(incvar+r'\s+LABEL\s*=\s*"([^"]+)"',sas).group(1)
        name=next(n for n in z.namelist() if n.lower().endswith('.txt'))
        nrows=0;invalid=0
        with z.open(name) as f:
            for line in f:
                nrows+=1;fid=int(line[slice(*pos[idvar])]);value=float(line[slice(*pos[incvar])])
                # Exclude bottom-coded $1, nonpositive, upper-coded and sentinel amounts.
                valid=int(1<value<ceiling);invalid+=not valid
                real=value*cpi[1996]/cpi[year-1] if valid else None
                con.execute('INSERT INTO psid_family_income VALUES (?,?,?,?,?)',(year,fid,value,real,valid))
        metadata.append(dict(wave=year,income_year=year-1,id_variable=idvar,income_variable=incvar,
          label=label,valid_lower_exclusive=1,valid_upper_exclusive=ceiling,rows=nrows,excluded=invalid,
          cpi=cpi[year-1],sha256=hashlib.sha256(path.read_bytes()).hexdigest(),file=path.name))

sql=(Path(__file__).with_name('psid_match.sql')).read_text(encoding='utf-8')
con.executescript(sql)
cur=con.execute('SELECT * FROM psid_matched ORDER BY child_fid,child_pnum')
cols=[x[0] for x in cur.description];rows=cur.fetchall();d={k:np.array([r[i] for r in rows],dtype=float) for i,k in enumerate(cols)}
n=len(rows)
if n<30:raise RuntimeError(f'Only {n} complete pairs: inspect inputs and filtering; do not report silently.')
def fit(x,y,controls=None):
    X=np.column_stack([np.ones(len(x)),x] + ([] if controls is None else [controls]))
    return float(np.linalg.lstsq(X,y,rcond=None)[0][1])
fathers=np.array([f'{int(r[2])}:{int(r[3])}' for r in rows]);unique=np.unique(fathers)
groups={k:np.where(fathers==k)[0] for k in unique}
rng=np.random.default_rng(640006)
samples=[np.concatenate([groups[k] for k in rng.choice(unique,len(unique),replace=True)]) for _ in range(500)]
specs=[('Early single','p_single','c_early_single'),('Midlife single','p_single','c_mid_single'),
       ('Early three-year average','p_mean','c_early_mean'),('Midlife three-year average','p_mean','c_mid_mean')]
est=[];draws=[]
for label,px,cy in specs:
    x,y=np.log(d[px]),np.log(d[cy]);bs=np.array([fit(x[k],y[k]) for k in samples]);draws.append(bs)
    lo,hi=np.quantile(bs,[.025,.975]);est.append([label,fit(x,y),lo,hi,n,len(unique)])
def save(name,header,rows):
    with (a.out/name).open('w',newline='',encoding='utf-8') as f:w=csv.writer(f);w.writerow(header);w.writerows(rows)
save('estimates.csv',['measure','ige','ci_low','ci_high','n_pairs','n_fathers'],est)
save('paired_differences.csv',['comparison','difference','ci_low','ci_high'],
 [(label,est[j][1]-est[i][1],*np.quantile(draws[j]-draws[i],[.025,.975])) for label,i,j in
  [('Midlife minus early, single-year',0,1),('Three-year minus single, midlife',1,3)]])
controls=np.column_stack([d['birth_year']-1957,d['parent_age_1970']-40])
save('age_adjusted_sensitivity.csv',['measure','ige','n_pairs'],[(label,fit(np.log(d[x]),np.log(d[y]),controls),n) for label,x,y in specs])
# Each son counts once in the main tutorial. A separate equal-father sensitivity reduces sibling weighting.
keep=np.array([groups[k][0] for k in unique])
save('one_son_per_father_sensitivity.csv',['measure','ige','n_pairs'],[(label,fit(np.log(d[x][keep]),np.log(d[y][keep])),len(keep)) for label,x,y in specs])
flow=[('Linked sons, birth 1955-1959, consistent birth year',con.execute("SELECT COUNT(*) FROM links l JOIN persons c ON c.fid=l.child_fid AND c.pnum=l.child_pnum WHERE l.parent_type='father' AND c.sex=1 AND c.birth_year BETWEEN 1955 AND 1959 AND c.birth_discrepancy=0").fetchone()[0]),
('Complete three-window headship and age coverage',con.execute('SELECT COUNT(*) FROM psid_candidates').fetchone()[0]),('All nine usable real family incomes',n),('Distinct recorded fathers',len(unique))]
save('sample_flow.csv',['stage','n'],flow)
save('source_variables.csv',list(metadata[0]),[list(r.values()) for r in metadata])
save('sample_age_summary.csv',['variable','min','mean','max'],[(k,d[k].min(),d[k].mean(),d[k].max()) for k in ['birth_year','parent_age_1970','child_age_1986','child_age_1996']])
age_change=d['child_age_1996']-d['child_age_1986']
save('age_increment_audit.csv',['reported_age_change','n'],[(int(k),int(sum(age_change==k))) for k in np.unique(age_change)])
consistent=np.where((age_change>=9)&(age_change<=11))[0]
save('age_consistency_sensitivity.csv',['measure','ige','n_pairs'],[(label,fit(np.log(d[x][consistent]),np.log(d[y][consistent])),len(consistent)) for label,x,y in specs])
checks=[('Unique child pairs',len(set(zip(d['child_fid'],d['child_pnum'])))==n),
 ('Every record has nine positive usable incomes',all(np.isfinite(d[k]).all() and (d[k]>0).all() for _,x,y in specs for k in (x,y))),
 ('Later interview window is ten calendar years later and all reported ages increase',1996-1986==10 and np.all(d['child_age_1996']>d['child_age_1986'])),
 ('Three records in each income window',con.execute('SELECT COUNT(*) FROM psid_measures WHERE n_valid!=3').fetchone()[0]==0),
 ('Both generations use composite identifiers',not con.execute('SELECT 1 FROM psid_matched WHERE parent_fid=0 OR parent_pnum=0 LIMIT 1').fetchone()),
 ('No nonfinite OLS outputs',np.isfinite(np.array([r[1:4] for r in est])).all())]
save('validation.csv',['check','passed'],checks);assert all(x[1] for x in checks)
(a.out/'manifest.json').write_text(json.dumps(dict(status='Actual PSID estimates, no simulated observations',
 income_definition='Total family money income, before personal income taxes, not individual wages',
 base_dollars=1996,weighted=False,selection='Recorded father-son, born 1955-1959, heads in all nine selected waves; parent age25-65 each early wave',
 numpy=np.__version__,python=sys.version,bootstrap='500 recorded-father clusters, seed640006',
 main_sample_n=n,n_fathers=len(unique),microdata_exported=False),indent=2),encoding='utf-8')
con.commit();con.close();print(json.dumps(dict(estimates=est,sample_flow=flow)))
