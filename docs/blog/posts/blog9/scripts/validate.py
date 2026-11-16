"""Independent reconstruction from saved predictions, holdings and raw prices."""
from pathlib import Path
import json,hashlib,csv
import pandas as pd
import numpy as np
R=Path(__file__).resolve().parents[1]
checks={}
manifest=pd.read_csv(R/'data/raw/manifest.csv')
checks['raw_hashes']=all(hashlib.sha256((R/f'data/raw/{x.symbol}.json').read_bytes()).hexdigest()==x.sha256 for x in manifest.itertuples())
p=pd.read_csv(R/'results/test_predictions.csv')
m=pd.read_csv(R/'results/prediction_metrics.csv').set_index('model')
base=np.mean((p.target-p['Historical mean'])**2)
for n in m.index:
    mse=np.mean((p.target-p[n])**2)
    checks['rmse_'+n]=bool(np.isclose(m.loc[n,'rmse'],np.sqrt(mse)))
    checks['r2_'+n]=bool(np.isclose(m.loc[n,'r2_oos'],1-mse/base))
h=pd.read_csv(R/'results/holdings.csv');ret=pd.read_csv(R/'results/monthly_returns.csv')
prices={}
for sym in h.symbol.unique():
    d=json.loads((R/f'data/raw/{sym}.json').read_text())['chart']['result'][0]
    dates=pd.to_datetime(d['timestamp'],unit='s',utc=True).tz_convert('America/New_York').strftime('%Y-%m-%d')
    prices[sym]=dict(zip(dates,d['indicators']['adjclose'][0]['adjclose']))
for model,g in ret.groupby('model'):
    weights=None;wealth=1
    for row in g.itertuples():
        cur=h[(h.model==model)&(h.signal==row.signal)].set_index('symbol').weight
        r=pd.Series({s:prices[s][row.exit]/prices[s][row.entry]-1 for s in cur.index})
        gross=(cur*r).sum()
        turn=1 if weights is None else cur.subtract(weights,fill_value=0).abs().sum()
        net=(1-.001*turn)*(1+gross)*(1-.001 if row.exit==g.exit.iloc[-1] else 1)-1
        wealth*=1+net
        assert np.isclose(row.gross,gross) and np.isclose(row.net,net) and np.isclose(row.wealth,wealth)
        weights=cur*(1+r)/(1+gross)
    checks['portfolio_'+model]=True
checks['common_entry_exit']=ret.groupby('signal').agg({'entry':'nunique','exit':'nunique'}).eq(1).all().all().item()
checks['all_predictions_finite']=np.isfinite(p[['Original','Improved','Historical mean']]).all().all().item()
assert all(checks.values()),checks
(R/'results/independent_checks.json').write_text(json.dumps(checks,indent=2))
print(f'{len(checks)} independent checks passed')
