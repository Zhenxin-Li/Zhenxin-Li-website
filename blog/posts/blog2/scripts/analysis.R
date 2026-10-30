library(rvest)
library(jsonlite)
library(dplyr)
library(ggplot2)
if(!exists('post_dir'))post_dir<-normalizePath('.',winslash='/')
source(file.path(post_dir,'scripts/dates.R'),local=environment())
raw<-file.path(post_dir,'data/raw')
manifest<-read.csv(file.path(raw,'manifest.csv'))
stopifnot(identical(unname(tools::md5sum(file.path(raw,manifest$file))),manifest$md5))
design<-fromJSON(file.path(post_dir,'data/design.json'))
universe<-read.csv(file.path(raw,'nyfed_universe.csv'),stringsAsFactors=FALSE)|>arrange(source_rank)|>filter(toupper(us_listed_parent)=='TRUE')|>slice_head(n=10)
ids<-read.csv(file.path(post_dir,'data/security_identity.csv'),colClasses='character')
tickers<-universe$ticker;managers<-design$managers
num<-function(x)as.numeric(gsub('[^0-9.-]','',x))
filings<-read.csv(file.path(raw,'filings.csv'),colClasses='character')
panels<-list()
for(m in managers)for(q in 1:2){
 n<-paste0(m,'_2024Q',q);h<-read_html(file.path(raw,paste0(n,'.html')))
 k<-trimws(html_text2(html_elements(h,'dt')));v<-trimws(html_text2(html_elements(h,'dd')));get<-function(key)v[k==key][1]
 j<-fromJSON(file.path(raw,paste0(n,'.json')));a<-as.data.frame(j$data,stringsAsFactors=FALSE)
 names(a)<-c('ticker','issuer','class','cusip','value_thousands','weight_rounded','shares','principal','option')
 a<-a|>filter(is.na(option),cusip%in%ids$cusip)|>mutate(shares=num(shares))
 stopifnot(!anyDuplicated(a$cusip),j$source_total_rows>1000,
           num(get('Num holdings'))==j$source_total_rows,
           as.Date(get('Date filed'),'%m/%d/%Y')<as.Date(design$entry),get('Form type')=='13F-HR',
           as.Date(get('Holdings as of'),'%m/%d/%Y')==as.Date(if(q==1)'2024-03-31' else '2024-06-30'))
 # A zero requires a complete, valid filing; it is not a missing-file substitution.
 panel<-ids|>select(ticker,cusip)|>left_join(a|>select(cusip,shares),by='cusip')|>
  mutate(shares=coalesce(shares,0),manager=m,quarter=paste0('Q',q))
 panels[[length(panels)+1]]<-panel
}
long<-bind_rows(panels)
positions<-long|>filter(quarter=='Q1')|>select(ticker,cusip,manager,q1_shares=shares)|>
 left_join(long|>filter(quarter=='Q2')|>select(cusip,manager,q2_shares=shares),by=c('cusip','manager'))|>
 mutate(added=q2_shares>q1_shares,change=ifelse(q1_shares>0,q2_shares/q1_shares-1,NA_real_),
        material_added=ifelse(q1_shares==0,q2_shares>0,change>.01),new_position=q1_shares==0&q2_shares>0,exit=q1_shares>0&q2_shares==0)
signal<-positions|>group_by(ticker)|>summarise(n_managers=n(),n_added=sum(added),n_material_added=sum(material_added),
 total_q1=sum(q1_shares),total_q2=sum(q2_shares),aggregate_change=total_q2/total_q1-1,.groups='drop')|>
 mutate(broad=n_added>=3,breadth=n_added/5)
prices<-bind_rows(lapply(c(tickers,'KBE'),function(t){h<-read_html(file.path(raw,paste0(t,'_prices.html')));a<-html_table(html_element(h,'table'));data.frame(ticker=t,month=a$Date,price=num(a[['Real price']]))}))
divs<-bind_rows(lapply(c(tickers,'KBE'),function(t){a<-html_table(html_elements(read_html(file.path(raw,paste0(t,'_dividends.html'))),'table'),fill=TRUE);a<-Filter(function(x)'Ex-Dividend Date'%in%names(x),a)[[1]];data.frame(ticker=t,ex_date=parse_english_date(a[['Ex-Dividend Date']]),amount=num(a[[2]]))}))
cash<-divs|>filter(ex_date>as.Date(design$entry),ex_date<=as.Date(design$exit))|>group_by(ticker)|>summarise(dividends=sum(amount),n_dividends=n(),.groups='drop')
market<-prices|>filter(month=='August 2024')|>select(ticker,entry_price=price)|>
 left_join(prices|>filter(month=='August 2025')|>select(ticker,exit_price=price),by='ticker')|>
 left_join(cash,by='ticker')|>mutate(return=(exit_price-entry_price+dividends)/entry_price)
eps<-read.csv(file.path(post_dir,'data/eps_2023_source_ledger.csv'))
x<-universe|>left_join(ids|>select(ticker,cusip),by='ticker')|>left_join(eps,by='ticker')|>left_join(signal,by='ticker')|>
 left_join(market,by='ticker')|>mutate(pe=ifelse(eps_2023>0,entry_price/eps_2023,NA_real_),
 low=!is.na(pe)&pe<=design$pe_ceiling,
 group=ifelse(broad,'At least 3 managers added','Fewer than 3 added'))
low<-filter(x,low);benchmark<-market$return[market$ticker=='KBE']
summarise_rule<-function(z,flag,label){
 a<-z$return[flag];b<-z$return[!flag]
 data.frame(rule=label,n_selected=length(a),n_other=length(b),selected_return=if(length(a))mean(a)else NA_real_,other_return=if(length(b))mean(b)else NA_real_,all_return=mean(z$return),difference_pp=if(length(a)&&length(b))100*(mean(a)-mean(b))else NA_real_)
}
primary<-summarise_rule(low,low$broad,'At least 3 of 5 add')
selected_return<-primary$selected_return;other_return<-primary$other_return;all_return<-primary$all_return
cutoffs<-bind_rows(lapply(design$sensitivity_pe,function(cut){z<-filter(x,!is.na(pe)&pe<=cut);cbind(pe_ceiling=cut,summarise_rule(z,z$broad,'At least 3 of 5 add'))}))
leave_out<-bind_rows(lapply(managers,function(m){a<-positions|>filter(manager!=m)|>group_by(ticker)|>summarise(n_added=sum(added),.groups='drop');z<-low|>select(-n_added)|>left_join(a,by='ticker');cbind(omitted=m,summarise_rule(z,z$n_added>=3,'Strict majority: 3 of remaining 4'))}))
definitions<-bind_rows(primary,summarise_rule(low,low$aggregate_change>0,'Sum of five reported positions increases'),summarise_rule(low,low$n_material_added>=3,'At least 3 managers increase >1%'))
individual<-bind_rows(lapply(managers,function(m){a<-positions|>filter(manager==m)|>select(ticker,added);z<-low|>left_join(a,by='ticker');cbind(manager=m,summarise_rule(z,z$added,'Single manager addition'))}))
checks<-data.frame(check=c('All saved source hashes match','Complete fixed ten-company universe','Exactly five managers and ten original filings','All report dates correct and public before entry','Unique common CUSIP per manager and quarter','Fifty paired manager-security observations','Absent positions tracked as zeros only after full filing validation','Original positive EPS required; loss issuer retained outside screen','All original EPS disclosures before entry','Four eligible dividends for all eleven securities','Both primary groups nonempty','All ten outcomes retained','Dividend-inclusive return identity','Equal-weight basket identity','Cutoff sensitivity and five leave-one-out results saved'),passed=c(TRUE,nrow(x)==10&&!anyDuplicated(x$ticker),length(managers)==5&&nrow(filings)==10,all(as.Date(filings$filed,'%m/%d/%Y')<as.Date(design$entry)),!anyDuplicated(long[c('cusip','manager','quarter')]),nrow(positions)==50,all(is.finite(positions$q1_shares))&&all(is.finite(positions$q2_shares)),all(x$eps_2023[x$low]>0)&&sum(x$eps_2023<=0)==1,all(as.Date(x$public_date)<as.Date(design$entry)),all(market$n_dividends==4),primary$n_selected>0&&primary$n_other>0,nrow(market)==11,all(abs(x$return-((x$exit_price+x$dividends)/x$entry_price-1))<1e-12),abs(all_return-mean(low$return))<1e-12,nrow(cutoffs)==length(design$sensitivity_pe)&&nrow(leave_out)==5))
dir.create(file.path(post_dir,'results'),recursive=TRUE,showWarnings=FALSE)
write.csv(checks,file.path(post_dir,'results/validation.csv'),row.names=FALSE)
failed<-checks$check[is.na(checks$passed)|!checks$passed]
if(length(failed))stop(paste0('Validation failed: ',paste(failed,collapse='; '),'. See results/validation.csv.'),call.=FALSE)
for(d in c('results','figures','data/processed'))dir.create(file.path(post_dir,d),recursive=TRUE,showWarnings=FALSE)
write.csv(x,file.path(post_dir,'data/processed/comparison.csv'),row.names=FALSE)
write.csv(positions,file.path(post_dir,'data/processed/manager_positions.csv'),row.names=FALSE)
write.csv(primary,file.path(post_dir,'results/primary_comparison.csv'),row.names=FALSE)
write.csv(cutoffs,file.path(post_dir,'results/threshold_sensitivity.csv'),row.names=FALSE)
write.csv(leave_out,file.path(post_dir,'results/leave_one_manager_out.csv'),row.names=FALSE)
write.csv(individual,file.path(post_dir,'results/single_manager_comparisons.csv'),row.names=FALSE)
write.csv(definitions,file.path(post_dir,'results/signal_definitions.csv'),row.names=FALSE)
write.csv(data.frame(group=c('All low-P/E stocks','KBE bank ETF'),return=c(all_return,benchmark)),file.path(post_dir,'results/benchmarks.csv'),row.names=FALSE)
write.csv(checks,file.path(post_dir,'results/validation.csv'),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(post_dir,'results/sessionInfo.txt'))
f1<-function(z)sprintf('%.1f',z);f2<-function(z)sprintf('%.2f',z)
v<-function(t,col)x[x$ticker==t,col][[1]]
colors<-c('At least 3 managers added'='#146f85','Fewer than 3 added'='#aa4b39','Outside P/E screen'='#7a828c')
plot1<-x|>filter(!is.na(pe))|>mutate(plot_group=ifelse(low,group,'Outside P/E screen'))
g1<-ggplot(plot1,aes(pe,n_added,color=plot_group))+geom_vline(xintercept=20,linetype='dashed',color='#777777')+
 geom_hline(yintercept=2.5,linetype='dotted',color='#999999')+geom_point(size=3.5)+
 geom_text(aes(label=ticker),nudge_y=.18,size=4,show.legend=FALSE)+scale_color_manual(values=colors)+
 scale_y_continuous(breaks=0:5,limits=c(.5,5))+scale_x_continuous(limits=c(11.5,23.5),breaks=c(12,15,18,20,23))+
 labs(title='Low P/E did not always coincide with additions by a majority',subtitle='Five asset managers | Change in common-share quantities, Q1 to Q2 2024',
 x='August 30, 2024 price / originally reported FY2023 diluted EPS',y='Managers adding shares (out of 5)',color=NULL,
 caption='Majority: at least 3 managers. TFC has negative EPS and is omitted.\nMS is just outside the unrounded P/E ceiling (20.0019); GS is also excluded.')+
 theme_minimal(base_size=12)+theme(legend.position='bottom',plot.title=element_text(face='bold'),plot.caption=element_text(hjust=0),panel.grid.minor=element_blank())
ggsave(file.path(post_dir,'figures/pe_and_managers.png'),g1,width=11,height=6.5,dpi=180)
plot2<-low|>arrange(return)|>mutate(label=factor(paste0(ticker,'  (',n_added,'/5 added)'),levels=paste0(ticker,'  (',n_added,'/5 added)')))
g2<-ggplot(plot2,aes(x=100*return,y=label,color=group))+geom_vline(xintercept=0,color='#cccccc')+
 geom_vline(xintercept=100*benchmark,linetype='dotted',color='#816c35')+
 geom_segment(aes(x=0,xend=100*return,yend=label),linewidth=1.1)+geom_point(size=3.5)+
 geom_text(aes(label=paste0(f1(100*return),'%')),hjust=-.2,size=4,show.legend=FALSE)+scale_color_manual(values=colors)+
 scale_x_continuous(limits=c(-2,66),breaks=c(0,20,40,60))+
 labs(title='The two groups earned almost the same average return',subtitle='August 30, 2024 to August 29, 2025 | Includes cash dividend entitlements',
 x='Following-year return (%)',y=NULL,color=NULL,
 caption=paste0('Equal-weight means: majority additions ',f1(100*selected_return),'% (n=',primary$n_selected,'); other stocks ',f1(100*other_return),'% (n=',primary$n_other,').\nAll seven: ',f1(100*all_return),'%. Dotted line: KBE ',f1(100*benchmark),'%. No reinvestment, fees or taxes.'))+
 theme_minimal(base_size=12)+theme(legend.position='bottom',plot.title=element_text(face='bold'),plot.caption=element_text(hjust=0),panel.grid.minor=element_blank())
ggsave(file.path(post_dir,'figures/following_returns.png'),g2,width=11,height=7,dpi=180)
print(x|>select(ticker,eps_2023,pe,n_added,aggregate_change,return,low));print(primary);print(cutoffs);print(leave_out);print(definitions)
