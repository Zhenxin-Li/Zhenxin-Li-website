"""Read the supplied class workbook; preserve paired team observations."""
from pathlib import Path
import openpyxl,numpy as np,json,csv,hashlib
R=Path(__file__).resolve().parents[1]
p=R/'data/classroom/results.xlsx'
w=openpyxl.load_workbook(p,data_only=True)
rows=list(w['Sheet1'].values)
assert rows[0]==('portfolio1','portfolio2')
a=np.array(rows[1:],dtype=float)
assert a.shape==(45,2) and np.isfinite(a).all()
facts={'n':len(a),'initial_per_portfolio':100000,'mean1':float(a[:,0].mean()),'mean2':float(a[:,1].mean()),'mean_difference':float(np.mean(a[:,1]-a[:,0])),'mean_return1':float(a[:,0].mean()/100000-1),'mean_return2':float(a[:,1].mean()/100000-1),'p2_wins':int((a[:,1]>a[:,0]).sum()),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'interpretation':'Paired class game outcomes; portfolio2 may use indicators, optimized weights and/or XGBoost. Actual method by team is not recorded. No model-specific causal conclusion.'}
(R/'results/classroom_facts.json').write_text(json.dumps(facts,indent=2))
with (R/'data/classroom/paired_results.csv').open('w',newline='') as f:
    out=csv.writer(f);out.writerow(['anonymous_row','portfolio1','portfolio2'])
    out.writerows((j+1,*v) for j,v in enumerate(a))
print(json.dumps(facts,indent=2))
