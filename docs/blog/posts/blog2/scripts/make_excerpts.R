library(rvest)
library(jsonlite)
if(!exists('post_dir'))post_dir<-normalizePath('.',winslash='/')
source(file.path(post_dir,'scripts/dates.R'),local=environment())
if(!exists('capture_dir'))capture_dir<-file.path(post_dir,'data/private/full_html')
raw<-file.path(post_dir,'data/raw');dir.create(raw,recursive=TRUE,showWarnings=FALSE)
universe<-read.csv(file.path(raw,'nyfed_universe.csv'),stringsAsFactors=FALSE)
tickers<-head(universe$ticker[toupper(universe$us_listed_parent)=='TRUE'],10)
escape<-function(x)gsub('&','&amp;',x,fixed=TRUE)
wrap<-function(body,url)paste0('<!doctype html><html><head><meta charset="utf-8"><link rel="canonical" href="',escape(url),'"></head><body><p>Selected factual excerpt; full source retained privately.</p>',body,'</body></html>')
master<-as.data.frame(fromJSON(file.path(capture_dir,'Vanguard_2024Q1.json'))$data,stringsAsFactors=FALSE)
master<-master[master[[1]]%in%tickers & is.na(master[[9]]),,drop=FALSE]
stopifnot(nrow(master)==10,!anyDuplicated(master[[1]]),!anyDuplicated(master[[4]]))
identity<-data.frame(ticker=master[[1]],cusip=master[[4]],issuer=master[[2]],class=master[[3]])
write.csv(identity,file.path(post_dir,'data/security_identity.csv'),row.names=FALSE)
filings<-list()
for(m in c('Vanguard','BlackRock','StateStreet','FMR','Geode'))for(q in 1:2){
 n<-paste0(m,'_2024Q',q);h<-read_html(file.path(capture_dir,paste0(n,'.html')))
 k<-trimws(html_text2(html_elements(h,'dt')));v<-trimws(html_text2(html_elements(h,'dd')));get<-function(key)v[k==key][1]
 u<-html_attr(html_element(h,'table[data-url]'),'data-url');accession<-basename(u)
 canonical<-html_attr(html_element(h,'link[rel="canonical"]'),'href')
 if(is.na(canonical))canonical<-paste0('https://13f.info/13f/',accession)
 meta<-paste(as.character(html_elements(h,'dl')),collapse='\n')
 table<-paste0('<table data-url="',u,'"></table>')
 writeLines(wrap(paste0(meta,table),canonical),file.path(raw,paste0(n,'.html')))
 all<-fromJSON(file.path(capture_dir,paste0(n,'.json')))$data
 selected<-all[all[,4]%in%identity$cusip,,drop=FALSE]
 write_json(list(source_total_rows=nrow(all),data=selected),file.path(raw,paste0(n,'.json')),pretty=TRUE,na='null')
 filings[[length(filings)+1]]<-data.frame(manager=m,quarter=paste0('2024Q',q),accession=accession,source_url=canonical,data_url=paste0('https://13f.info',u),filed=get('Date filed'),report_date=get('Holdings as of'),form_type=get('Form type'),full_rows=nrow(all))
}
write.csv(do.call(rbind,filings),file.path(raw,'filings.csv'),row.names=FALSE)
for(t in tickers){
 h<-read_html(file.path(capture_dir,paste0(t,'_prices.html')));rr<-html_elements(h,'table tr')
 first<-vapply(rr,function(x)html_text2(html_element(x,'td,th')),character(1))
 pick<-rr[first%in%c('Date','August 2024')];stopifnot(length(pick)==2)
 writeLines(wrap(paste0('<table>',paste(as.character(pick),collapse='\n'),'</table>'),paste0('https://www.digrin.com/stocks/detail/',t,'/price')),file.path(raw,paste0(t,'_prices.html')))

}
files<-list.files(capture_dir,full.names=TRUE);files<-files[file.info(files)$isdir==FALSE]
write.csv(data.frame(file=basename(files),bytes=file.info(files)$size,md5=unname(tools::md5sum(files))),file.path(raw,'capture_checksums.csv'),row.names=FALSE)
files<-list.files(raw,full.names=TRUE);files<-files[basename(files)!='manifest.csv']
write.csv(data.frame(file=basename(files),md5=unname(tools::md5sum(files))),file.path(raw,'manifest.csv'),row.names=FALSE)
