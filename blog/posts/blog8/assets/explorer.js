/* Local Plotly explorer. All values come from frozen, independently checked draws. */
(() => {
  'use strict';
  const d = window.BLOG8_DATA;
  const el = id => document.getElementById(id);
  if (!d || !window.Plotly) return; // Static figures remain readable if JS is unavailable.
  const colors = {teal:'#247b83', blue:'#174a68', orange:'#bc5834', gold:'#916526', gray:'#a6b4c0'};
  const formatValue = x => x.toFixed(2);
  const pct = x => (100*x).toFixed(1)+'%';
  const pformat = x => x < .001 ? '< 0.001' : '= '+x.toFixed(3);
  const vertical = (x,color,dash='solid') => ({type:'line',xref:'x',yref:'paper',x0:x,x1:x,y0:0,y1:1,line:{color,width:1.7,dash}});
  const legendLine = (name,color,dash) => ({type:'scatter',x:[null],y:[null],mode:'lines',name,line:{color,width:2,dash},hoverinfo:'skip'});
  const config = {responsive:true,displaylogo:false,modeBarButtonsToRemove:['lasso2d','select2d'],toImageButtonOptions:{format:'png',scale:2}};
  function layout(title,xlabel,height=430) {
    return {title:{text:title,font:{size:17}},height,autosize:true,
      margin:{l:60,r:18,t:52,b:100},paper_bgcolor:'white',plot_bgcolor:'white',
      font:{family:'system-ui, sans-serif',size:12,color:'#243b49'},
      xaxis:{title:{text:xlabel},zeroline:false,gridcolor:'#e7edf0'},
      yaxis:{title:{text:'Density'},gridcolor:'#e7edf0',rangemode:'tozero'},
      legend:{orientation:'h',y:-.28,x:0,font:{size:11}},hovermode:'closest'};
  }
  function histogram(h,name,color) {
    return {type:'bar',x:h.x,y:h.density,width:h.width,name,marker:{color},
      customdata:h.count,hovertemplate:'Statistic: %{x:.2f}<br>Density: %{y:.3f}<br>Draws in bin: %{customdata:,}<extra></extra>'};
  }
  let generation=0;
  async function draw() {
    const ticket=++generation;
    const n=el('b8-n').value, level=el('b8-level').value, shade=el('b8-shade').value;
    const c=d.cases[n], q=c.levels[level], alpha=1-Number(level)/100;
    window.BLOG8_STATUS={ready:false,n:Number(n),level:Number(level),shade,mean:c.mean,
      low:q.low,high:q.high,p:c.p,coverage:q.coverage,critical:q.critical,reject:c.p<=alpha};
    el('b8-sample-summary').textContent=`${Number(n).toLocaleString()} observations | sample mean ${formatValue(c.mean)} | true population mean 3.00`;
    el('b8-ci-summary').textContent=`${level}% percentile interval: ${formatValue(q.low)} to ${formatValue(q.high)}. ${q.low<=0 && q.high>=0 ? 'Zero is inside this interval.' : 'Zero is outside this interval.'}`;
    el('b8-coverage-summary').textContent=`${q.covered.toLocaleString()} / ${d.M.toLocaleString()} intervals contain 3: ${pct(q.coverage)} (${level}% target). Average interval width: ${formatValue(q.average_width)}. Monte Carlo SE of coverage: ${(100*q.coverage_mcse).toFixed(2)} percentage points.`;
    el('b8-test-summary').textContent=`Observed t = ${c.t.toFixed(2)}; p ${pformat(c.p)} (${c.tail_count.toLocaleString()} of ${d.D.toLocaleString()} null draws at least as extreme; +1 correction). ${c.p<=alpha ? 'Reject' : 'Do not reject'} a zero population mean at alpha = ${alpha.toFixed(2)}.`;
    const bootLayout=layout('One sample, many bootstrap means','Bootstrap sample mean');
    bootLayout.shapes=[{type:'rect',xref:'x',yref:'paper',x0:q.low,x1:q.high,y0:0,y1:1,fillcolor:'#d5eeeb',opacity:.7,line:{width:0},layer:'below'},
      vertical(q.low,colors.teal,'dash'),vertical(q.high,colors.teal,'dash'),vertical(c.mean,colors.blue),vertical(d.mu,colors.gold,'dot')];
    const bootTraces=[histogram(c.bootstrap_hist,'Bootstrap means','#326a88'),
      legendLine('Observed mean',colors.blue,'solid'),legendLine(`${level}% interval`,colors.teal,'dash'),legendLine('True mean',colors.gold,'dot')];
    const coverageTraces=[true,false].map(hit=>{
      const x=[],y=[],text=[];
      q.show.filter(a=>a.hit===hit).forEach(a=>{
        x.push(a.low,a.high,null);y.push(a.run,a.run,null);
        const t=`Experiment ${a.run}<br>${formatValue(a.low)} to ${formatValue(a.high)}<br>${hit?'Contains':'Misses'} 3`;
        text.push(t,t,'');
      });
      return {type:'scatter',mode:'lines+markers',x,y,text,hoverinfo:'text',
        marker:{size:3,color:hit?colors.teal:colors.orange},line:{width:1.6,color:hit?colors.teal:colors.orange},
        name:hit?'Contains 3':'Misses 3',connectgaps:false};
    });
    const covLayout=layout(`Fresh samples: first 100 of ${d.M.toLocaleString()} intervals`,`${level}% interval for population mean`,540);
    covLayout.yaxis={title:{text:'Experiment'},range:[101,0],tickvals:[1,20,40,60,80,100],gridcolor:'#edf1f3'};
    covLayout.shapes=[vertical(d.mu,'#253d4c','dash')];
    const nullLayout=layout('What a zero population mean would produce','Studentized mean, t');
    const edges=c.null_hist.edges, cut=shade==='p'?Math.abs(c.t):q.critical;
    const fill=shade==='p'?'#3d8cae':'#cf714c';
    nullLayout.shapes=[{type:'rect',xref:'x',yref:'paper',x0:edges[0],x1:-cut,y0:0,y1:1,fillcolor:fill,opacity:.22,line:{width:0}},
      {type:'rect',xref:'x',yref:'paper',x0:cut,x1:edges[edges.length-1],y0:0,y1:1,fillcolor:fill,opacity:.22,line:{width:0}},
      vertical(-Math.abs(c.t),'#14678f'),vertical(Math.abs(c.t),'#14678f'),
      vertical(-q.critical,'#b24632','dash'),vertical(q.critical,'#b24632','dash')];
    const nullTraces=[histogram(c.null_hist,'Null t statistics',colors.gray),
      legendLine('±|observed t|','#14678f','solid'),legendLine(`Rejection boundary (alpha ${alpha.toFixed(2)})`,'#b24632','dash')];
    const panels=[['b8-bootstrap','b8-fig-bootstrap',bootTraces,bootLayout],
      ['b8-coverage','b8-fig-coverage',coverageTraces,covLayout],['b8-null','b8-fig-null',nullTraces,nullLayout]];
    try {
      await Promise.all(panels.map(async ([id,fig,traces,l])=>{
        el(id).style.display='block';
        await Plotly.react(id,traces,l,config);
        el(fig).classList.add('is-live');
      }));
      if(ticket===generation) window.BLOG8_STATUS.ready=true;
    } catch(error) {
      console.error('Explorer: static figures retained',error);
      panels.forEach(([id,fig])=>{el(id).style.display='none';el(fig).classList.remove('is-live');});
      window.BLOG8_STATUS.error=String(error);
    }
  }
  ['b8-n','b8-level','b8-shade'].forEach(id=>el(id).addEventListener('change',draw));
  el('b8-reset').addEventListener('click',()=>{
    el('b8-n').value='200';el('b8-level').value='95';el('b8-shade').value='p';draw();
  });
  draw();
})();
