// Tests the exact generated controls with a state harness, not a browser.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const html=fs.readFileSync(path.join(root,'figures/rent_burden.html'),'utf8');
const spec=JSON.parse(fs.readFileSync(path.join(root,'figures/figure_spec.json'),'utf8'));
const script=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
const elements=new Map();
for(const id of ['region-filter','change-filter','state-filter','error-bars','state-labels','reset-chart','chart-status']){
 elements.set(id,{value:'all',checked:false,textContent:'',handlers:{},addEventListener(k,f){this.handlers[k]=f;}});
}
const chart={data:structuredClone(spec.data),layout:structuredClone(spec.layout)};elements.set('rent-chart',chart);
const Plotly={async restyle(target,updates){for(const [key,value] of Object.entries(updates)){
 target.data.forEach((trace,i)=>{const parts=key.split('.');let t=trace;for(const p of parts.slice(0,-1))t=t[p]??={};t[parts.at(-1)]=Array.isArray(value)?value[i]:value;});
}}};
const context=vm.createContext({document:{getElementById:id=>elements.get(id)},Plotly});vm.runInContext(script,context);
const names=()=>chart.data.flatMap(t=>t.customdata.map(x=>x[0]));
const change=async(id,value)=>{elements.get(id).value=value;await elements.get(id).handlers.change();};
const check=async(id)=>{elements.get(id).checked=true;await elements.get(id).handlers.change();};
(async()=>{
 await change('region-filter','West');assert.equal(names().length,13);
 await change('change-filter','increase');assert.deepEqual(names().sort(),['Arizona','Nevada']);
 await change('region-filter','all');assert.deepEqual(names().sort(),['Arizona','Florida','Maine','Nebraska','Nevada']);
 await check('error-bars');assert.ok(chart.data.every(t=>t.error_x.visible&&t.error_y.visible));
 chart.data.forEach(t=>{assert.equal(t.error_x.array.length,t.x.length);assert.equal(t.error_y.array.length,t.y.length);});
 await check('state-labels');assert.ok(chart.data.every(t=>t.mode==='markers+text'));
 await change('state-filter','12');assert.deepEqual(names(),['Florida']);
 assert.equal(elements.get('region-filter').value,'all');assert.equal(elements.get('change-filter').value,'all');
 const fl=chart.data.flatMap(t=>t.customdata)[0];const xy=chart.data.filter(t=>t.x.length)[0];assert.ok(Math.abs(fl[1]-(xy.y[0]-xy.x[0]))<1e-10);
 await change('change-filter','decrease');await change('region-filter','South');assert.equal(names().length,0);
 assert.match(elements.get('chart-status').textContent,/No states match/);
 await elements.get('reset-chart').handlers.click();assert.equal(names().length,50);assert.equal(new Set(names()).size,50);
 assert.ok(chart.data.every(t=>!t.error_x.visible&&!t.error_y.visible&&t.mode==='markers'));
 assert.equal(elements.get('state-filter').value,'all');assert.deepEqual(chart.layout.xaxis.range,[30,66]);assert.deepEqual(chart.layout.yaxis.range,[30,66]);
 chart.data.forEach(t=>t.customdata.forEach((r,i)=>assert.ok(Math.abs(r[1]-(t.y[i]-t.x[i]))<1e-10)));
 console.log('PASS: region filter, national top-five intersections, state selection, labels, error arrays, empty subset, reset, exact hover changes, fixed axes. Logic test only.');
})().catch(e=>{console.error(e);process.exitCode=1;});
