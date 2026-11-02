"""Verify frozen inputs; use --refresh only after intentionally regenerating draws."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import numpy as np
from simulate import bootstrap_means

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--refresh',action='store_true')
args = parser.parse_args()
files = sorted((root/'data/simulated').glob('*.csv'))
files += [root/'results'/n for n in ['facts.json','explorer.json','summary.csv','coverage_intervals.csv','validation.csv']]
files += [root/'assets/simulation-data.js']
if args.refresh:
    manifest = {str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (root/'results/manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    with (root/'results/render_manifest.csv').open('w',newline='',encoding='utf8') as f:
        w=csv.writer(f);w.writerow(['file','md5'])
        for p in files:w.writerow([str(p.relative_to(root)).replace('\\','/'),hashlib.md5(p.read_bytes()).hexdigest()])
manifest=json.loads((root/'results/manifest.json').read_text())
assert all(hashlib.sha256((root/name).read_bytes()).hexdigest()==digest for name,digest in manifest.items())
# Substantive edge checks: replacement can duplicate an observation; a constant
# sample must not acquire artificial bootstrap variation.
toy=bootstrap_means(np.array([0.,2.]),2000,np.random.default_rng(7))
assert set(np.unique(toy))=={0.,1.,2.}
assert np.all(bootstrap_means(np.full(10,7.),100,np.random.default_rng(8))==7.)
payload=json.loads((root/'results/explorer.json').read_text())
for n,c in payload['cases'].items():
    assert sum(c['bootstrap_hist']['count'])==9999
    assert sum(c['null_hist']['count'])==50000
    for key,z in c['levels'].items():
        assert len(z['show'])==100
        assert all(a['run']==i+1 and a['hit']==(a['low']<=3<=a['high']) for i,a in enumerate(z['show']))
print(f'{len(manifest)} frozen input hashes verified; replacement, constant-sample and figure-count checks passed.')
