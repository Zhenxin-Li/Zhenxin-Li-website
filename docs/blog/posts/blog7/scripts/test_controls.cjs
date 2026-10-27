// State-based test of the exact generated controls; does not launch a browser.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const html=fs.readFileSync(path.join(root,'figures/rent_burden.html'),'utf8');
const spec=JSON.parse(fs.readFileSync(path.join(root,'figures/figure_spec.json'),'utf8'));
const script=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
const elements=new Map();
for(const id of ['metric-view','region-filter','count-filter','state-filter','error-bars','reset-chart','chart-status','interval-note']){
 elements.set(id,{value:'all',checked:false,textContent:'',handlers:{},addEventListener(k,f){this.handlers[k]=f;}});
}
elements.get('metric-view').value='change';elements.get('count-filter').value='10';elements.get('error-bars').checked=true;
const chart={data:structuredClone(spec.data),layout:structuredClone(spec.layout)};elements.set('rent-chart',chart);
function setKey(obj,key,value){const parts=key.replace(/\[(\d+)\]/g,'.$1').split('.');let t=obj;for(const p of parts.slice(0,-1))t=t[p]??={};t[parts.at(-1)]=value;}
const Plotly={async update(target,data,layout){
 for(const [key,value] of Object.entries(data))target.data.forEach((trace,i)=>setKey(trace,key,Array.isArray(value)?value[i]:value));
 for(const [key,value] of Object.entries(layout))setKey(target.layout,key,value);
}};
const context=vm.createContext({document:{getElementById:id=>elements.get(id)},Plotly});vm.runInContext(script,context);
const names=()=>Array.from(chart.data[0].customdata,r=>r[0]);
const change=async(id,value)=>{elements.get(id).value=value;await elements.get(id).handlers.change();};
function aligned(){const t=chart.data[0];assert.equal(t.x.length,t.y.length);assert.equal(t.x.length,t.customdata.length);assert.equal(t.x.length,t.error_x.array.length);assert.equal(t.x.length,chart.layout.yaxis.ticktext.length);}
(async()=>{
 assert.equal(names().length,10);assert.deepEqual(names().slice(0,3),['Nevada','Maine','Florida']);
 await change('metric-view','level');aligned();assert.equal(names()[0],'Florida');assert.ok(names().includes('California'));
 assert.ok(chart.data[0].x.every((x,i)=>x===chart.data[0].customdata[i][3]));
 assert.ok(chart.data[0].error_x.array.every((x,i)=>x===chart.data[0].customdata[i][7]));
 assert.equal(chart.layout.shapes[0].visible,false);assert.equal(chart.layout.xaxis.ticksuffix,'%');
 await change('region-filter','Northeast');assert.equal(names().length,9);assert.ok(chart.data[0].customdata.every(r=>r[1]==='Northeast'));
 await change('metric-view','change');assert.equal(names()[0],'Maine');assert.ok(chart.data[0].x.every((x,i)=>x===chart.data[0].customdata[i][4]));
 assert.equal(chart.layout.shapes[0].visible,true);
 await change('region-filter','all');assert.equal(names().length,10);assert.equal(names()[0],'Nevada');
 await change('count-filter','all');aligned();assert.equal(names().length,50);assert.equal(new Set(names()).size,50);
 assert.ok(chart.layout.height>620);assert.equal(names().at(-1),'Vermont');
 assert.ok(chart.data[0].x.every((x,i,a)=>i===0||a[i-1]>=x));
 await change('state-filter','12');assert.deepEqual(names(),['Florida']);assert.equal(elements.get('region-filter').value,'all');
 await change('metric-view','level');assert.deepEqual(names(),['Florida']);assert.equal(chart.data[0].x[0],chart.data[0].customdata[0][3]);
 elements.get('error-bars').checked=false;await elements.get('error-bars').handlers.change();assert.equal(chart.data[0].error_x.visible,false);
 await elements.get('reset-chart').handlers.click();aligned();assert.equal(names().length,10);assert.equal(names()[0],'Nevada');
 assert.equal(elements.get('state-filter').value,'all');assert.equal(elements.get('count-filter').value,'10');assert.equal(elements.get('metric-view').value,'change');
 assert.equal(chart.data[0].error_x.visible,true);assert.equal(JSON.stringify(chart.layout.xaxis.range),'[-12,12]');assert.equal(chart.layout.height,spec.layout.height);
 assert.match(elements.get('interval-note').textContent,/change intervals/);
 assert.match(elements.get('chart-status').textContent,/10 of 50/);
 console.log('PASS: default ranking, 2024 reranking and annual intervals, regional top N, all 50 and scrolling height, state preservation, interval toggle, complete reset, exact units/data alignment. Logic test only.');
})().catch(e=>{console.error(e);process.exitCode=1;});
