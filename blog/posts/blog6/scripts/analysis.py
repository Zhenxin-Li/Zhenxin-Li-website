"""Offline SQL tutorial. Synthetic data only; no empirical population claims."""
from pathlib import Path
import csv, hashlib, json, sqlite3, sys, platform
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RAW, OUT, FIG = [ROOT / x for x in ('data/raw', 'results', 'figures')]
for folder in (RAW, OUT, FIG):
    folder.mkdir(parents=True, exist_ok=True)
SEED, N, BETA = 640006, 4000, 0.4

def write_csv(path, header, rows):
    with path.open('w', newline='', encoding='utf-8') as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)

def generate():
    rng = np.random.default_rng(SEED)
    parent = 10.7 + rng.normal(0, .6, N)
    child = 10.7 + BETA * (parent - 10.7) + rng.normal(0, .5, N)
    persons, incomes, truth = [], [], []
    for i in range(N):
        family, pid, cid = i + 1, i + 1, N + i + 1
        persons.extend([(pid, family, family, 'parent', '', 1940),
                        (cid, family, N + family, 'child', pid, 1965)])
        truth.append((cid, pid, parent[i], child[i]))
        for person, birth, permanent in ((pid,1940,parent[i]), (cid,1965,child[i])):
            for age in range(25, 46):
                loading = min(1.0, .5 + .05 * (age - 25))
                log_y = 10.7 + .02*(age-35) + loading*(permanent-10.7) + rng.normal(0,.45)
                incomes.append((person,birth+age,age,round(float(np.exp(log_y)),6)))
    write_csv(RAW/'persons.csv', ['person_id','origin_family_id','current_family_id','role','parent_id','birth_year'],persons)
    write_csv(RAW/'income.csv', ['person_id','year','age','real_income'],incomes)
    write_csv(RAW/'truth.csv', ['child_id','parent_id','log_parent_permanent','log_child_permanent'],truth)
    (RAW/'simulation.json').write_text(json.dumps(dict(seed=SEED,n_families=N,true_ige=BETA,
        source='Author-generated synthetic balanced panel; not PSID or actual people',
        units='Constant purchasing-power dollars, arbitrary reference price level; no inflation',
        equation='lp=10.7+N(0,.6^2); lc=10.7+.4*(lp-10.7)+N(0,.5^2); log y(a)=10.7+.02*(a-35)+min(1,.5+.05*(a-25))*(l-10.7)+N(0,.45^2)',
        assumptions='One parent and one adult child per origin family; independent yearly shocks; complete positive incomes; no attrition'),indent=2),encoding='utf-8')

if '--regenerate' in sys.argv or not all((RAW/f).exists() for f in ('persons.csv','income.csv','truth.csv','simulation.json')):
    generate()
con = sqlite3.connect(':memory:')
con.executescript('''CREATE TABLE persons(person_id INTEGER PRIMARY KEY, origin_family_id INTEGER,
 current_family_id INTEGER, role TEXT, parent_id INTEGER, birth_year INTEGER);
 CREATE TABLE income(person_id INTEGER, year INTEGER, age INTEGER, real_income REAL,
 PRIMARY KEY(person_id,year), FOREIGN KEY(person_id) REFERENCES persons(person_id));''')
con.execute('PRAGMA foreign_keys=ON')
for table, width in [('persons',6),('income',4)]:
    with (RAW/f'{table}.csv').open(encoding='utf-8') as f:
        reader=csv.reader(f); next(reader)
        con.executemany(f'INSERT INTO {table} VALUES ({",".join("?" for _ in range(width))})',
                        ([None if v=='' else v for v in row] for row in reader))
con.executescript((ROOT/'scripts/match.sql').read_text(encoding='utf-8'))
cols=[x[0] for x in con.execute('SELECT * FROM matched').description]
rows=con.execute('SELECT * FROM matched ORDER BY child_id').fetchall()
write_csv(OUT/'matched.csv',cols,rows)
m=np.array(rows,dtype=float); d={k:m[:,i] for i,k in enumerate(cols)}
truth=np.genfromtxt(RAW/'truth.csv',delimiter=',',names=True)
assert np.array_equal(truth['child_id'],d['child_id'])

def slope(x,y):
    x=x-x.mean(); return float(x @ (y-y.mean())/(x@x))

rng=np.random.default_rng(SEED+1)
bootstrap=rng.integers(0,N,size=(400,N))
def estimate(label,x,y):
    draws=np.array([slope(x[k],y[k]) for k in bootstrap])
    lo,hi=np.quantile(draws,[.025,.975])
    return (label,slope(x,y),float(lo),float(hi),N)

specs=[('Early single: child 25 / parent 35','parent_single','child_early_single'),
       ('Midcareer single: both 35','parent_single','child_mid_single'),
       ('Early averages: child 25-29 / parent 35-39','parent_mean','child_early_mean'),
       ('Midcareer averages: both 35-39','parent_mean','child_mid_mean')]
est=[estimate(label,np.log(d[x]),np.log(d[y])) for label,x,y in specs]
oracle=slope(truth['log_parent_permanent'],truth['log_child_permanent'])
est.append(estimate('Oracle: permanent income',truth['log_parent_permanent'],truth['log_child_permanent']))
write_csv(OUT/'estimates.csv',['measure','ige','ci_low','ci_high','n_pairs'],est)
age_results=[]
for age in range(25,46):
    annual=np.array([r[0] for r in con.execute('''SELECT i.real_income FROM pairs k JOIN income i
      ON i.person_id=k.child_id WHERE i.age=? ORDER BY k.child_id''',(age,))])
    beta=slope(np.log(d['parent_mean']),np.log(annual))
    avg_beta=''
    if 27<=age<=43:
        averaged=np.array([r[0] for r in con.execute('''SELECT AVG(i.real_income) FROM pairs k
          JOIN income i ON i.person_id=k.child_id WHERE i.age BETWEEN ? AND ?
          GROUP BY k.child_id ORDER BY k.child_id''',(age-2,age+2))])
        avg_beta=slope(np.log(d['parent_mean']),np.log(averaged))
    age_results.append((age,beta,avg_beta))
write_csv(OUT/'age_profile.csv',['child_age_or_window_center','annual_ige','five_year_ige'],age_results)
checks=[('4000 unique matched child-parent pairs',len(rows)==N and len(set(d['child_id']))==N),
 ('Income rows unique by person and year',con.execute('SELECT COUNT(*) FROM income').fetchone()[0]==2*N*21),
 ('Both generations five valid years',con.execute('SELECT COUNT(*) FROM measures WHERE n_mid=5 AND n_early=5').fetchone()[0]==2*N),
 ('No parent-child current household matches required',con.execute('SELECT COUNT(*) FROM pairs k JOIN persons p ON p.person_id=k.parent_id JOIN persons c ON c.person_id=k.child_id WHERE p.current_family_id=c.current_family_id').fetchone()[0]==0),
 ('Parents older by 25 years',con.execute('SELECT COUNT(*) FROM pairs k JOIN persons p ON p.person_id=k.parent_id JOIN persons c ON c.person_id=k.child_id WHERE c.birth_year-p.birth_year=25').fetchone()[0]==N),
 ('Foreign keys valid',len(con.execute('PRAGMA foreign_key_check').fetchall())==0)]
write_csv(OUT/'validation.csv',['check','passed'],checks)
assert all(v for _,v in checks)
write_csv(OUT/'checksums.csv',['file','sha256'],[(p.name,hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(RAW.iterdir())])
(OUT/'environment.json').write_text(json.dumps(dict(python=platform.python_version(),numpy=np.__version__,sqlite=sqlite3.sqlite_version,seed=SEED,bootstrap_replicates=400,oracle_ige=oracle),indent=2))

# Dependency-free, scalable SVG figures. All marks are drawn from saved estimates.
def svg_start(title,subtitle):
    return [f'<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="560" viewBox="0 0 1000 560" role="img"><title>{title}</title><rect width="1000" height="560" fill="white"/>',
     '<style>text{font-family:Arial,sans-serif;fill:#243447} .small{font-size:15px} .tick{font-size:16px}</style>',
     f'<text x="40" y="36" font-size="25" font-weight="bold">{title}</text><text x="40" y="65" class="small">{subtitle}</text>']

svg=svg_start('The same families, different income measurements','Synthetic panel | 4,000 pairs | Bars: paired bootstrap 95% intervals (400 resamples)')
left,right,top,bottom=450,940,115,445
xp=lambda b:left+(b/.55)*(right-left)
for tick in np.arange(0,.56,.1):
    x=xp(tick);svg += [f'<line x1="{x}" x2="{x}" y1="95" y2="465" stroke="#e0e5eb"/>',f'<text x="{x}" y="490" text-anchor="middle" class="tick">{tick:.1f}</text>']
svg += [f'<line x1="{xp(BETA)}" x2="{xp(BETA)}" y1="90" y2="465" stroke="#b45309" stroke-dasharray="6 5"/>']
for i,(label,b,lo,hi,n) in enumerate(est):
    y=top+i*77
    svg += [f'<text x="430" y="{y+5}" text-anchor="end" class="small">{label}</text>',f'<line x1="{xp(lo)}" x2="{xp(hi)}" y1="{y}" y2="{y}" stroke="#176b91" stroke-width="4"/>',f'<circle cx="{xp(b)}" cy="{y}" r="7" fill="#176b91"/>',f'<text x="{xp(hi)+9}" y="{y+5}" class="small">{b:.3f}</text>']
svg += ['<text x="695" y="525" text-anchor="middle" class="tick">Intergenerational elasticity (log-log slope)</text>', '<text x="40" y="550" class="small">Dashed orange line: true permanent-income IGE = 0.400. Oracle uses latent values unavailable in real surveys.</text></svg>']
(FIG/'measurement.svg').write_text('\n'.join(svg),encoding='utf-8')
svg=svg_start('Averaging cannot turn early earnings into midcareer earnings','Synthetic panel | Fixed parent measure: mean income at ages 35-39 | Same 4,000 pairs at every age')
xp=lambda a:90+(a-25)/20*840
yp=lambda b:455-b/.5*345
for tick in np.arange(0,.51,.1):
    y=yp(tick);svg += [f'<line x1="90" x2="930" y1="{y}" y2="{y}" stroke="#e0e5eb"/>',f'<text x="75" y="{y+5}" text-anchor="end" class="tick">{tick:.1f}</text>']
for a in range(25,46,5):
    svg.append(f'<text x="{xp(a)}" y="485" text-anchor="middle" class="tick">{a}</text>')
for col,color in [(1,'#176b91'),(2,'#9d4173')]:
    points=' '.join(f'{xp(a):.2f},{yp(row[col]):.2f}' for row in age_results if row[col]!='' for a in [row[0]])
    svg.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="3"/>')
svg += [f'<line x1="90" x2="930" y1="{yp(BETA)}" y2="{yp(BETA)}" stroke="#b45309" stroke-dasharray="6 5"/>',
 '<text x="90" y="98" class="small" fill="#176b91">Blue: single child year</text><text x="340" y="98" class="small" fill="#9d4173">Purple: centered five-year mean</text><text x="690" y="98" class="small">Dashed: true IGE 0.400</text>',
 '<text x="500" y="520" text-anchor="middle" class="tick">Child age (single year) or center of five-year age window</text>',
 '<text x="40" y="550" class="small">Both series retain measurement error in parental income; curves need not reach the known permanent-income slope.</text></svg>']
(FIG/'lifecycle.svg').write_text('\n'.join(svg),encoding='utf-8')
con.close()
print(json.dumps(dict(n_pairs=N,estimates={r[0]:round(r[1],4) for r in est},checks_passed=len(checks))))
