"""Cache public Yahoo daily charts. Never overwrite a successful capture by default."""
from pathlib import Path
import re, json, urllib.request, time, datetime, hashlib, csv
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'scripts/classroom_original.R').read_text()
tickers=re.findall(r'"([A-Z]+)"',source.split('tickers <- c(')[1].split('prices <-')[0])+['SPY']
def stamp(s): return int(datetime.datetime.fromisoformat(s).replace(tzinfo=datetime.timezone.utc).timestamp())
log=[]
for symbol in tickers:
    p=ROOT/f'data/raw/{symbol}.json'
    url=f'https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?period1={stamp("2022-01-01")}&period2={stamp("2026-01-01")}&interval=1d&events=div%2Csplits&includeAdjustedClose=true'
    if not p.exists():
        request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
        with urllib.request.urlopen(request,timeout=45) as response: data=response.read()
        obj=json.loads(data)
        assert obj['chart']['result'],symbol
        p.write_bytes(data)
        time.sleep(.4)
    log.append(dict(symbol=symbol,url=url,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    print(symbol,flush=True)
with (ROOT/'data/raw/manifest.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=log[0]);w.writeheader();w.writerows(log)
(ROOT/'data/raw/capture.json').write_text(json.dumps({'retrieved_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'start':'2022-01-01','end_exclusive':'2026-01-01','symbols':len(tickers)},indent=2))
