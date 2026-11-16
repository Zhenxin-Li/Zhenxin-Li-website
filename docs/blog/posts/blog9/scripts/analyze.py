"""Chronological, label-purged model comparison; frozen 2025 test and monthly backtest."""
from pathlib import Path
import json, platform, hashlib
import numpy as np
import pandas as pd
import xgboost as xgb
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
np.random.seed(123)
frames=[]
for path in sorted((ROOT/'data/raw').glob('*.json')):
    if path.name=='capture.json': continue
    z=json.loads(path.read_text())['chart']['result'][0]
    q=z['indicators']['quote'][0]
    f=pd.DataFrame(q,index=pd.to_datetime(z['timestamp'],unit='s',utc=True).tz_convert('America/New_York').normalize().tz_localize(None))
    f['adjusted']=z['indicators']['adjclose'][0]['adjclose']; f['symbol']=path.stem
    frames.append(f.rename_axis('date').reset_index())
prices=pd.concat(frames).sort_values(['symbol','date'])
spy=prices[prices.symbol=='SPY'].set_index('date').adjusted
cal=spy.index
sr=spy.pct_change()
spy_target=spy.shift(-20)/spy.shift(-1)-1
rows=[]
for sym,g in prices[prices.symbol!='SPY'].groupby('symbol'):
    g=g.set_index('date').reindex(cal)
    assert g.adjusted.notna().all(),f'missing prices: {sym}'
    p=g.adjusted; r=p.pct_change();g['return']=r;g['spy_ret']=sr
    for n,k in [(21,'1m'),(63,'3m'),(126,'6m')]:
        g['mom_'+k]=p.shift(n)/p.shift(1)-1 # classroom inverse momentum, retained
        g['trend_'+k]=p/p.shift(n)-1
        g['relative_'+k]=(p/p.shift(n))/(spy/spy.shift(n))-1
    g['vol_1m']=r.shift(1).rolling(22).std()
    g['ret_5d']=p.shift(5)/p.shift(1)-1
    g['excess_ret']=r-sr
    g['vol_3m']=r.rolling(63).std()
    g['volume_ratio']=g.volume/g.volume.rolling(21).mean()
    g['target']=p.shift(-20)/p.shift(-1)-1
    g['market_target']=spy_target
    g['excess_target']=g.target-g.market_target
    g['label_end']=pd.Series(cal,index=cal).shift(-20)
    g['symbol']=sym
    rows.append(g.rename_axis('date').reset_index())
df=pd.concat(rows).dropna().sort_values(['date','symbol']).reset_index(drop=True)
old=['open','high','low','close','volume','adjusted','return','spy_ret','mom_1m','mom_3m','mom_6m','vol_1m','ret_5d','excess_ret']
new=['trend_1m','trend_3m','trend_6m','relative_1m','relative_3m','relative_6m','vol_1m','vol_3m','ret_5d','excess_ret','volume_ratio','spy_ret']
def fit(train,features,target,depth,trees,rate,child):
    params=dict(max_depth=depth,eta=rate,min_child_weight=child,gamma=0,objective='reg:squarederror',tree_method='hist',nthread=2,seed=123)
    booster=xgb.train(params,xgb.DMatrix(train[features].to_numpy(),label=train[target].to_numpy(),feature_names=features),num_boost_round=trees)
    class Predictor:
        def predict(self,values):
            return booster.predict(xgb.DMatrix(values.to_numpy(),feature_names=list(values.columns)))
    return Predictor()
train=df[(df.date<'2024-01-01')&(df.label_end<'2024-01-01')]
valid=df[(df.date>='2024-01-01')&(df.label_end<'2025-01-01')]
test=df[(df.date>='2025-01-01')&(df.label_end<'2026-01-01')].copy()
assert train.label_end.max()<valid.date.min()
grid=[]
for depth in [1,2,3]:
    for trees in [100,300]:
        m=fit(train,new,'excess_target',depth,trees,.03,30)
        pred=m.predict(valid[new])
        grid.append(dict(depth=depth,trees=trees,validation_mse=float(np.mean((valid.excess_target-pred)**2))))
tuning=pd.DataFrame(grid).sort_values(['validation_mse','depth','trees'])
best=tuning.iloc[0]
# Refit after choosing on 2024 only; no 2025 labels enter either model.
final_train=df[(df.date<'2025-01-01')&(df.label_end<'2025-01-01')]
assert final_train.label_end.max()<test.date.min()
baseline=fit(final_train,old,'target',5,300,.05,10)
improved=fit(final_train,new,'excess_target',int(best.depth),int(best.trees),.03,30)
test['Original']=baseline.predict(test[old])
test['Improved']=improved.predict(test[new])+final_train.market_target.mean()
test['Historical mean']=final_train.target.mean()
metrics=[]
benchmark_mse=np.mean((test.target-test['Historical mean'])**2)
for name in ['Original','Improved','Historical mean']:
    error=test.target-test[name];mse=float(np.mean(error**2))
    metrics.append(dict(model=name,rmse=float(np.sqrt(mse)),mae=float(np.mean(abs(error))),r2_oos=1-mse/benchmark_mse))
# First trading day signals; next close execution; identical nonoverlapping windows.
signals=pd.Series(cal,index=cal).groupby(cal.to_period('M')).first()
testsignals=list(signals[signals.dt.year==2025])
# Last position liquidated at final 2025 close; no January 2026 outcome needed.
end=cal[-1]
wide=prices.pivot(index='date',columns='symbol',values='adjusted')
wealth={n:1.0 for n in ['Original','Improved','Equal weight','SPY']}
prev={n:None for n in wealth}; back=[]; holdings=[]
for i,signal in enumerate(testsignals):
    entry=cal[cal.get_loc(signal)+1]
    exit=cal[cal.get_loc(testsignals[i+1])+1] if i+1<len(testsignals) else end
    available=test[test.date==signal]
    # December signal has a fully observed 20-session target; assert full universe.
    assert len(available)==prices.symbol.nunique()-1,(signal,len(available))
    realised=wide.loc[exit]/wide.loc[entry]-1
    for name in wealth:
        if name in ['Original','Improved']:
            picks=available.sort_values([name,'symbol'],ascending=[False,True]).head(10)
            # Equal weights isolate selection quality; same rule for both models.
            w=pd.Series(.1,index=picks.symbol)
        elif name=='Equal weight':w=pd.Series(1/len(available),index=available.symbol)
        else:w=pd.Series(1.,index=['SPY'])
        gross=float((w*realised.reindex(w.index)).sum())
        oldw=prev[name]
        turnover=1. if oldw is None else float(w.subtract(oldw,fill_value=0).abs().sum())
        # 10 bps per dollar bought or sold; include terminal liquidation.
        traded=turnover+(1. if i==len(testsignals)-1 else 0.)
        net=(1-.001*turnover)*(1+gross)*(1-.001 if i==len(testsignals)-1 else 1)-1
        wealth[name]*=1+net
        prev[name]=w*(1+realised.reindex(w.index))/(1+gross)
        back.append(dict(model=name,signal=str(signal.date()),entry=str(entry.date()),exit=str(exit.date()),gross=gross,net=net,wealth=wealth[name],traded=traded))
        for sym,weight in w.items():holdings.append(dict(model=name,signal=str(signal.date()),symbol=sym,weight=weight))
back=pd.DataFrame(back)
invest=[]
for name,g in back.groupby('model',sort=False):
    wealth_path=np.r_[1,g.wealth.to_numpy()]
    invest.append(dict(model=name,gross_return=float(np.prod(1+g.gross)-1),net_return=float(g.wealth.iloc[-1]-1),max_drawdown=float(np.min(wealth_path/np.maximum.accumulate(wealth_path)-1)),annualized_vol=float(g.net.std(ddof=1)*np.sqrt(12)),traded=float(g.traded.sum())))
invest=pd.DataFrame(invest)
for name,data in [('tuning',tuning),('prediction_metrics',pd.DataFrame(metrics)),('investment_metrics',invest),('monthly_returns',back),('holdings',pd.DataFrame(holdings))]:data.to_csv(ROOT/f'results/{name}.csv',index=False)
test[['date','symbol','target','label_end','Original','Improved','Historical mean']].to_csv(ROOT/'results/test_predictions.csv',index=False)
df.to_csv(ROOT/'data/processed/features.csv',index=False)
facts={'symbols':int(prices.symbol.nunique()-1),'train_rows':len(final_train),'test_rows':len(test),'test_dates':int(test.date.nunique()),'selected_depth':int(best.depth),'selected_trees':int(best.trees),'metrics':metrics,'investment':invest.to_dict('records'),'train_last_label':str(final_train.label_end.max().date()),'test_first_signal':str(test.date.min().date()),'test_last_signal':str(test.date.max().date()),'xgboost':xgb.__version__,'python':platform.python_version()}
(ROOT/'results/facts.json').write_text(json.dumps(facts,indent=2))
checks={'label_purge':bool(final_train.label_end.max()<test.date.min()),'tuning_only_2024':bool(valid.label_end.max()<pd.Timestamp('2025-01-01')),'twelve_windows':len(back)==48,'weights_sum_one':bool(np.allclose(pd.DataFrame(holdings).groupby(['model','signal']).weight.sum(),1)),'no_window_overlap':all(pd.to_datetime(g.exit).iloc[:-1].to_numpy()==pd.to_datetime(g.entry).iloc[1:].to_numpy() for _,g in []) if False else all((g.exit.iloc[:-1].to_numpy()==g.entry.iloc[1:].to_numpy()).all() for _,g in back.groupby('model')),'finite_predictions':bool(np.isfinite(test[['Original','Improved']]).all().all())}
assert all(checks.values()),checks
(ROOT/'results/checks.json').write_text(json.dumps(checks,indent=2))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,'axes.spines.right':False})
colors={'Original':'#c66b35','Improved':'#147d92','Equal weight':'#353c50','SPY':'#8d77ab'}
fig,ax=plt.subplots(figsize=(9,4.5))
ms=pd.DataFrame(metrics)
ax.barh(ms.model.replace({"Original":"Classroom specification","Improved":"Revised model"}),ms.rmse*100,color=[colors.get(n,'#92979d') for n in ms.model]);ax.set_xlabel('Prediction RMSE (percentage points; lower is better)')
ax.set_title('Do the forecasts beat a constant historical mean?')
for i,v in enumerate(ms.rmse*100):ax.text(v+.05,i,f'{v:.2f}',va='center')
ax.set_xlim(0,ms.rmse.max()*115);fig.tight_layout();fig.savefig(ROOT/'figures/prediction.png',dpi=180);plt.close(fig)
fig,ax=plt.subplots(figsize=(9,4.8))
for name,g in back.groupby('model',sort=False):
    ax.plot([pd.Timestamp('2025-01-03')]+list(pd.to_datetime(g.exit)),np.r_[100,100*g.wealth],label={"Original":"Classroom specification","Improved":"Revised model"}.get(name,name),color=colors[name],lw=2)
ax.set_ylabel('Value of $100, after modeled trading costs');ax.set_title('Did better forecasts produce a better 2025 portfolio?');ax.legend(ncol=2,frameon=False);fig.autofmt_xdate();fig.tight_layout();fig.savefig(ROOT/'figures/wealth.png',dpi=180);plt.close(fig)
print(json.dumps(facts,indent=2))
