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
           as.Date(get('Date filed'),'%m/%d/%Y')<as.Date(design$valuation_date),get('Form type')=='13F-HR',
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
eps<-read.csv(file.path(post_dir,'data/eps_2023_source_ledger.csv'))
x<-universe|>left_join(eps,by='ticker')|>left_join(signal,by='ticker')|>
 left_join(prices|>filter(month=='August 2024')|>select(ticker,entry_price=price),by='ticker')|>
 mutate(pe=ifelse(eps_2023>0,entry_price/eps_2023,NA_real_),low=!is.na(pe)&pe<=20,
 group=ifelse(broad,'At least 3 managers added','Fewer than 3 added'))
e<-read.csv(file.path(post_dir,'data/earnings_review_ledger.csv'))
e<-e|>left_join(x|>select(ticker,entry_price,pe,n_added),by='ticker')|>
 mutate(eps_adjustment=ifelse(ticker=='JPM',-gain_after_tax_millions/diluted_shares_millions,eps_adjustment),
 reviewed_eps=reported_eps+eps_adjustment,reviewed_pe=entry_price/reviewed_eps)
checks<-data.frame(check=c('Saved raw source hashes match','Ten unique companies','Fifty paired manager-security rows',
 'All filing dates precede valuation','Seven companies pass unrounded annual P/E ceiling','Five pass majority additions',
 'Case EPS agrees with original ledger','JPM gain removal identity','PNC issuer reconciliation identity','Both reviewed multiples remain below twenty'),
 passed=c(TRUE,nrow(x)==10&&!anyDuplicated(x$ticker),nrow(positions)==50,
 all(as.Date(filings$filed,'%m/%d/%Y')<as.Date('2024-08-30')),sum(x$low)==7,sum(x$low&x$broad)==5,
 all(e$reported_eps==x$eps_2023[match(e$ticker,x$ticker)]),abs(e$reviewed_eps[e$ticker=='JPM']-(16.23-2775/2943.1))<1e-10,
 abs(e$reviewed_eps[e$ticker=='PNC']-14.10)<1e-10,all(e$reviewed_pe<20)))
for(d in c('results','figures','data/processed'))dir.create(file.path(post_dir,d),recursive=TRUE,showWarnings=FALSE)
write.csv(checks,file.path(post_dir,'results/validation.csv'),row.names=FALSE)
if(!all(checks$passed))stop(paste('Validation failed:',paste(checks$check[!checks$passed],collapse='; ')))
write.csv(x,file.path(post_dir,'data/processed/comparison.csv'),row.names=FALSE)
write.csv(positions,file.path(post_dir,'data/processed/manager_positions.csv'),row.names=FALSE)
write.csv(e,file.path(post_dir,'results/earnings_review.csv'),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(post_dir,'results/sessionInfo.txt'))
f1<-function(z)sprintf('%.1f',z);f2<-function(z)sprintf('%.2f',z)
v<-function(t,col)x[x$ticker==t,col][[1]]
ev<-function(t,col)e[e$ticker==t,col][[1]]
colors<-c('At least 3 managers added'='#146f85','Fewer than 3 added'='#aa4b39','Outside P/E screen'='#7a828c')
plot1<-x|>filter(!is.na(pe))|>mutate(plot_group=ifelse(low,group,'Outside P/E screen'))
g1<-ggplot(plot1,aes(pe,n_added,color=plot_group))+geom_vline(xintercept=20,linetype='dashed',color='#777777')+
 geom_hline(yintercept=2.5,linetype='dotted',color='#999999')+geom_point(size=3.5)+
 geom_text(aes(label=ticker),nudge_y=.18,size=4,show.legend=FALSE)+scale_color_manual(values=colors)+
 scale_y_continuous(breaks=0:5,limits=c(.5,5))+scale_x_continuous(limits=c(11.5,23.5),breaks=c(12,15,18,20,23))+
 labs(title='Low P/E coexists with different institutional holding changes',subtitle='Five managers | Q1 to Q2 2024 common-share quantities, disclosed before valuation',
 x='August 30, 2024 price / originally reported FY2023 diluted EPS',y='Managers increasing shares (out of 5)',color=NULL,
 caption='Dashed line: P/E 20. Dotted line: majority boundary. Negative-EPS TFC omitted.\nMS (20.0019) and GS are outside the unrounded P/E ceiling. This is not a forecast test.')+
 theme_minimal(base_size=12)+theme(legend.position='bottom',plot.title=element_text(face='bold'),plot.caption=element_text(hjust=0),panel.grid.minor=element_blank())
ggsave(file.path(post_dir,'figures/pe_and_managers.png'),g1,width=11,height=6.5,dpi=180)
# Faceted dumbbell: show the denominator and its valuation consequence together.
plot2<-bind_rows(data.frame(ticker=e$ticker,measure='Earnings per share ($)',reported=e$reported_eps,reviewed=e$reviewed_eps),
 data.frame(ticker=e$ticker,measure='Price / earnings (times)',reported=e$pe,reviewed=e$reviewed_pe))
points<-bind_rows(transmute(plot2,ticker,measure,value=reported,basis='Reported'),transmute(plot2,ticker,measure,value=reviewed,basis='Reviewed'))
g2<-ggplot(plot2,aes(y=ticker))+geom_segment(aes(x=reported,xend=reviewed,yend=ticker),color='#aaaaaa',linewidth=1.2)+
 geom_point(data=points,aes(x=value,color=basis),size=3.8)+
 geom_text(data=points,aes(x=value,label=sprintf('%.2f',value),color=basis),nudge_y=ifelse(points$basis=='Reported',.18,-.18),size=4,show.legend=FALSE)+
 facet_wrap(~measure,scales='free_x')+scale_color_manual(values=c(Reported='#aa4b39',Reviewed='#146f85'))+
 scale_x_continuous(expand=expansion(mult=c(.18,.18)))+
 labs(title='The earnings checks move the two multiples in opposite directions',subtitle='Same August 30, 2024 prices | Both companies had 4 of 5 managers increasing shares',x=NULL,y=NULL,color=NULL,
 caption='JPM: remove only $2,775m after-tax acquisition gain / 2,943.1m diluted shares.\nPNC: add issuer-disclosed $1.31 EPS charge adjustment. Reviewed measures have different scopes; neither is a forecast.')+
 theme_minimal(base_size=12)+theme(legend.position='bottom',plot.title=element_text(face='bold'),plot.caption=element_text(hjust=0),panel.grid.minor=element_blank())
ggsave(file.path(post_dir,'figures/earnings_review.png'),g2,width=11,height=6,dpi=180)
print(e);print(checks)
