"""Offline analysis and self-contained Plotly figure, using a saved official snapshot."""
import csv
import hashlib
import json
import platform
from pathlib import Path

import plotly
import plotly.graph_objects as go
from download_data import validate

ROOT = Path(__file__).resolve().parents[1]
COUNTRIES = {'CAN': 'Canada', 'FRA': 'France', 'DEU': 'Germany', 'ITA': 'Italy',
             'JPN': 'Japan', 'GBR': 'United Kingdom', 'USA': 'United States'}
ORDER = list(COUNTRIES)
COLORS = ['#0072B2', '#009E73', '#D55E00', '#CC79A7', '#6A51A3', '#8C6D31', '#222222']


def write_csv(path, rows):
    with path.open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def build():
    for directory in ['results', 'figures', 'data/processed']:
        (ROOT / directory).mkdir(parents=True, exist_ok=True)
    raw = (ROOT / 'data/raw/wdi_life_expectancy.json').read_bytes()
    obj = validate(raw)
    manifest = json.loads((ROOT / 'data/raw/manifest.json').read_text(encoding='utf-8'))
    assert hashlib.sha256(raw).hexdigest() == manifest['sha256'], 'Snapshot hash mismatch'
    values = {(r['countryiso3code'], int(r['date'])): float(r['value']) for r in obj[1]}
    rows, summary = [], []
    for country in ORDER:
        baseline = values[country, 2019]
        for year in range(2019, 2024):
            value = values[country, year]
            rows.append(dict(iso3=country, country=COUNTRIES[country], year=year,
                             life_expectancy=value, baseline_2019=baseline, gap_years=value-baseline))
        trough_year = min(range(2020, 2024), key=lambda y: values[country, y])
        summary.append(dict(iso3=country, country=COUNTRIES[country], baseline_2019=baseline,
                            life_expectancy_2023=values[country, 2023],
                            gap_2023=values[country, 2023]-baseline, trough_year=trough_year,
                            trough_value=values[country, trough_year],
                            rebound_to_2023=values[country, 2023]-values[country, trough_year]))
    write_csv(ROOT / 'data/processed/life_expectancy.csv', rows)
    write_csv(ROOT / 'results/country_summary.csv', summary)
    facts = {
        'n_countries': 7, 'n_observations': len(rows), 'baseline_year': 2019, 'end_year': 2023,
        'source_sha256': manifest['sha256'], 'api_last_updated': manifest['api_last_updated'],
        'france_gap_years': next(x['gap_2023'] for x in summary if x['iso3'] == 'FRA'),
        'within_tenth_year': sum(abs(x['gap_2023']) <= .1 for x in summary),
        'python': platform.python_version(), 'plotly': plotly.__version__
    }
    (ROOT / 'results/facts.json').write_text(json.dumps(facts, indent=2) + '\n', encoding='utf-8')

    fig = go.Figure()
    for country, color in zip(ORDER, COLORS):
        subset = [r for r in rows if r['iso3'] == country]
        fig.add_trace(go.Scatter(
            x=[r['year'] for r in subset], y=[r['gap_years'] for r in subset],
            name=COUNTRIES[country], mode='lines+markers',
            line=dict(color=color, width=2.7, dash='dash' if country == 'JPN' else 'solid'),
            marker=dict(size=8, symbol='diamond' if country == 'USA' else 'circle'),
            customdata=[[r['life_expectancy'], r['baseline_2019'], r['gap_years']] for r in subset],
            hovertemplate=('%{fullData.name}<br>Life expectancy: %{customdata[0]:.2f} years'
                           '<br>2019 level: %{customdata[1]:.2f} years'
                           '<br>Change from 2019: %{customdata[2]:+.3f} years<extra></extra>')))
    fig.update_layout(
        template='plotly_white', autosize=True, height=505,
        margin=dict(l=65, r=24, t=25, b=100),
        font=dict(family='Arial, sans-serif', size=13, color='#223447'),
        hovermode='x unified', dragmode=False,
        xaxis=dict(title=None, tickmode='array', tickvals=list(range(2019, 2024)),
                   range=[2018.9, 2023.1], fixedrange=True, showgrid=False),
        yaxis=dict(title='Change from 2019 (years)', range=[-2.65, .4], fixedrange=True,
                   zeroline=False, tickformat='.1f', gridcolor='#e6ebef', automargin=True),
        legend=dict(orientation='h', y=-.17, x=0, font=dict(size=12), itemclick='toggle', itemdoubleclick='toggleothers'),
        shapes=[dict(type='line', xref='paper', x0=0, x1=1, yref='y', y0=0, y1=0,
                     line=dict(color='#566877', width=1.5, dash='dot'))],
        transition=dict(duration=0))
    config = dict(displayModeBar=False, responsive=True, scrollZoom=False, displaylogo=False)
    figure = fig.to_html(full_html=False, include_plotlyjs=True, div_id='life-chart', config=config)
    # Standard HTML controls add keyboard access; all plotting is performed by Plotly.
    data = json.dumps({'gap': [[r['gap_years'] for r in rows if r['iso3'] == c] for c in ORDER],
                       'level': [[r['life_expectancy'] for r in rows if r['iso3'] == c] for c in ORDER]})
    options = '<option value="all">All seven countries</option>' + ''.join(
        f'<option value="{i}">{COUNTRIES[c]}</option>' for i, c in enumerate(ORDER))
    html = '''<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>G7 life expectancy: levels and change from 2019</title>
<style>
*{box-sizing:border-box}body{margin:0;font:14px/1.5 Arial,sans-serif;color:#223447;background:white}
.controls{display:flex;flex-wrap:wrap;gap:9px;align-items:center;padding:12px 10px;background:#f4f7fa;border-radius:8px}
button,select{font:inherit;border:1px solid #a6b5c2;border-radius:5px;padding:7px 10px;background:white;color:#223447;cursor:pointer;max-width:100%}
button[aria-pressed="true"]{background:#16456b;color:white;border-color:#16456b}
button:focus-visible,select:focus-visible{outline:3px solid #d9822b;outline-offset:2px}
.label{font-weight:600}.status{padding:9px 12px 0;color:#526576;font-size:12px}
#life-chart{width:100%}.hint{font-size:12px;color:#526576;padding:0 12px 6px;margin:0}
@media(max-width:480px){.controls{gap:6px;padding:8px}button,select{font-size:12px;padding:6px}.status{font-size:11px}}
</style></head><body>
<div class="controls" aria-label="Chart controls">
<span class="label">Measure</span>
<button id="gap-mode" aria-pressed="true">Change from 2019</button>
<button id="level-mode" aria-pressed="false">Life expectancy</button>
<label for="country-filter" class="label">Country</label>
<select id="country-filter">''' + options + '''</select>
<button id="reset-chart">Reset chart</button></div>
<div id="chart-status" class="status" role="status" aria-live="polite">Change from 2019 | All seven countries</div>
''' + figure + '''
<p class="hint">Hover a year for exact values. Click legend names to hide/show countries; double-click to isolate one. Axes stay fixed within each measure.</p>
<noscript>This chart needs JavaScript. Use the CSV download and endpoint table in the article.</noscript>
<script>
const chart=document.getElementById('life-chart');
const measures=''' + data + ''';
let mode='gap';
function status(){
 const count=chart.data.filter(t=>t.visible!==false&&t.visible!=='legendonly').length;
 document.getElementById('chart-status').textContent=(mode==='gap'?'Change from 2019':'Life expectancy')+' | '+count+' countries shown';
}
async function setMeasure(next){
 mode=next;
 await Plotly.update(chart,{y:measures[mode]}, {
  'yaxis.title.text':mode==='gap'?'Change from 2019 (years)':'Life expectancy at birth (years)',
  'yaxis.range':mode==='gap'?[-2.65,.4]:[75.8,85],
  'shapes[0].visible':mode==='gap'
 });
 document.getElementById('gap-mode').setAttribute('aria-pressed',String(mode==='gap'));
 document.getElementById('level-mode').setAttribute('aria-pressed',String(mode==='level'));
 status();
}
document.getElementById('gap-mode').addEventListener('click',()=>setMeasure('gap'));
document.getElementById('level-mode').addEventListener('click',()=>setMeasure('level'));
document.getElementById('country-filter').addEventListener('change',async e=>{
 await Plotly.restyle(chart,{visible:chart.data.map((_,i)=>e.target.value==='all'||i===Number(e.target.value))});status();
});
chart.on('plotly_restyle',status);
chart.on('plotly_legendclick',()=>{document.getElementById('country-filter').value='all';});
document.getElementById('reset-chart').addEventListener('click',async()=>{
 document.getElementById('country-filter').value='all';
 await Plotly.restyle(chart,{visible:chart.data.map(()=>true)});
 await setMeasure('gap');
});
</script></body></html>'''
    (ROOT / 'figures/life_expectancy.html').write_text(html, encoding='utf-8')
    (ROOT / 'figures/figure_spec.json').write_text(fig.to_json(), encoding='utf-8')

    checks = [
        dict(check='API snapshot: unique complete 7 by 9 records', passed=True),
        dict(check='Analysis: 35 unique country-year rows', passed=len(rows) == 35 and len({(r['iso3'], r['year']) for r in rows}) == 35),
        dict(check='2019 changes exactly zero', passed=all(r['gap_years'] == 0 for r in rows if r['year'] == 2019)),
        dict(check='Every plotted value equals raw minus own 2019 level', passed=all(abs(r['gap_years']-(values[r['iso3'],r['year']]-values[r['iso3'],2019])) < 1e-12 for r in rows)),
        dict(check='Seven traces with five years and raw hover values', passed=len(fig.data) == 7 and all(len(t.x) == len(t.y) == len(t.customdata) == 5 for t in fig.data)),
        dict(check='France within 0.01 year, others below 2019 in 2023', passed=0 < facts['france_gap_years'] < .01 and all(x['gap_2023'] < 0 for x in summary if x['iso3'] != 'FRA')),
        dict(check='US lowest 2021; Canada lowest 2022', passed=next(x['trough_year'] for x in summary if x['iso3']=='USA') == 2021 and next(x['trough_year'] for x in summary if x['iso3']=='CAN') == 2022),
        dict(check='Chart embeds Plotly, without a CDN dependency', passed='<script src=' not in html and 'plotly.js v' in html)
    ]
    write_csv(ROOT / 'results/validation.csv', checks)
    assert all(row['passed'] for row in checks), checks
    print('Built 35 observations, seven country summaries, and a self-contained Plotly chart; eight checks passed.')


if __name__ == '__main__':
    build()
