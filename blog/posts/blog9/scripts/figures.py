from pathlib import Path
import pandas as pd,numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
metrics=pd.read_csv(ROOT/"results/prediction_metrics.csv").to_dict("records")
back=pd.read_csv(ROOT/"results/monthly_returns.csv")
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
