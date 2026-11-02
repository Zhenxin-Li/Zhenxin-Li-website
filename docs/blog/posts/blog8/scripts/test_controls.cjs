/* Offline unit test of the real controller with fake DOM/Plotly adapters.
   This is NOT a browser rendering or interaction test. */
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert');
const root=path.resolve(__dirname,'..');
const payload=JSON.parse(fs.readFileSync(path.join(root,'results/explorer.json'),'utf8'));
const rows=fs.readFileSync(path.join(root,'results/summary.csv'),'utf8').trim().split(/\r?\n/);
const headers=rows.shift().split(',');
const summary=rows.map(line=>Object.fromEntries(line.split(',').map((v,i)=>[headers[i],Number(v)])));
const names=['b8-n','b8-level','b8-shade','b8-reset','b8-sample-summary','b8-ci-summary','b8-coverage-summary','b8-test-summary','b8-bootstrap','b8-coverage','b8-null','b8-fig-bootstrap','b8-fig-coverage','b8-fig-null'];
const nodes=Object.fromEntries(names.map(id=>[id,{value:'',style:{},textContent:'',listeners:{},classList:{add(){},remove(){}},addEventListener(type,fn){this.listeners[type]=fn;}}]));
nodes['b8-n'].value='200';nodes['b8-level'].value='95';nodes['b8-shade'].value='p';
const plots={};
const context={console,document:{getElementById:id=>nodes[id]},window:{BLOG8_DATA:payload},Plotly:{react:async(id,data,layout)=>{plots[id]={data,layout};}}};
context.window.Plotly=context.Plotly;
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(root,'assets/explorer.js'),'utf8'),context);
const settle=async()=>{await Promise.resolve();await Promise.resolve();await new Promise(resolve=>setImmediate(resolve));};
async function change(id,value){nodes[id].value=value;await nodes[id].listeners.change();await settle();}
(async()=>{
 await settle();
 const checks=[],specs=[];
 for(const n of [50,200,800]){
  await change('b8-n',String(n));let unchangedP;
  for(const level of [90,95,99]){
   await change('b8-level',String(level));
   const s=context.window.BLOG8_STATUS,expected=summary.find(r=>r.n===n && r.confidence===level/100);
   assert(s.ready && !s.error);assert(Math.abs(s.mean-expected.sample_mean)<1e-12);
   assert(Math.abs(s.low-expected.lower)<1e-12 && Math.abs(s.high-expected.upper)<1e-12);
   assert(Math.abs(s.p-expected.p_value)<1e-12 && Math.abs(s.coverage-expected.coverage)<1e-12);
   if(unchangedP!==undefined)assert.strictEqual(s.p,unchangedP);unchangedP=s.p;
   assert.strictEqual(s.reject,s.p<=1-level/100);
   assert.strictEqual(plots['b8-bootstrap'].data[0].customdata.reduce((a,b)=>a+b,0),9999);
   assert.strictEqual(plots['b8-null'].data[0].customdata.reduce((a,b)=>a+b,0),50000);
   const traces=plots['b8-coverage'].data;
   assert.strictEqual(traces.reduce((sum,t)=>sum+t.x.filter(x=>x!==null).length,0),200);
   const pBefore=s.p,lowBefore=s.low;
   await change('b8-shade','rejection');
   assert.strictEqual(context.window.BLOG8_STATUS.p,pBefore);assert.strictEqual(context.window.BLOG8_STATUS.low,lowBefore);
   assert(Math.abs(plots['b8-null'].layout.shapes[1].x0-expected.critical_abs_t)<1e-12);
   await change('b8-shade','p');
   assert(Math.abs(plots['b8-null'].layout.shapes[1].x0-Math.abs(expected.observed_t))<1e-12);
   checks.push({n,confidence:level,statistical_values:'match independent summary CSV',p_unchanged_when_confidence_changes:true,shading_does_not_change_results:true});
   specs.push({n,level,plots:JSON.parse(JSON.stringify(plots))});
  }
 }
 await nodes['b8-reset'].listeners.click();await settle();
 assert.strictEqual(nodes['b8-n'].value,'200');assert.strictEqual(nodes['b8-level'].value,'95');assert.strictEqual(nodes['b8-shade'].value,'p');
 assert.strictEqual(context.window.BLOG8_STATUS.ready,true);
 const report={test_type:'offline controller unit tests with mock DOM and Plotly; not browser tests',combinations:checks,reset:'passed',browser_verification:'blocked: browser URL policy prohibits file://; no bypass attempted'};
 fs.writeFileSync(path.join(root,'results/interaction_checks.json'),JSON.stringify(report,null,2));
 fs.writeFileSync(path.join(root,'results/chart_specs.json'),JSON.stringify(specs));
 console.log('Nine sample-size/confidence combinations, both shading modes, and reset passed offline unit tests.');
})().catch(error=>{console.error(error);process.exitCode=1;});
