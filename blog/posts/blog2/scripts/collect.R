# Optional collection only. Normal analysis/rendering never sources this file.
library(rvest)
library(httr2)
if(!exists('post_dir'))post_dir<-normalizePath('.',winslash='/')
if(file.exists(file.path(post_dir,'data/raw/manifest.csv')))stop('Use a fresh directory; never overwrite the frozen public snapshot.')
capture_dir<-file.path(post_dir,'data/private/full_html')
dir.create(capture_dir,recursive=TRUE,showWarnings=FALSE)
dir.create(file.path(post_dir,'data/raw'),recursive=TRUE,showWarnings=FALSE)
logfile<-file.path(post_dir,'data/raw/request_log.csv')
fetch<-function(url,name){
 f<-file.path(capture_dir,name);if(file.exists(f))return(f)
 Sys.sleep(5)
 stamp<-format(Sys.time(),tz='UTC',format='%Y-%m-%dT%H:%M:%SZ')
 response<-request(url)|>req_user_agent('Codex-AcademicBlog-AIAgent/1.0 (+https://github.com/Zhenxin-Li/Zhenxin-Li-website)')|>
  req_timeout(60)|>req_error(is_error=function(x)FALSE)|>req_perform()
 status<-resp_status(response)
 write.table(data.frame(url=url,file=name,retrieved_utc=stamp,status=status),logfile,sep=',',row.names=FALSE,col.names=!file.exists(logfile),append=file.exists(logfile))
 if(status!=200)stop('HTTP error. Stop; do not retry, change identities, or bypass restrictions.')
 writeBin(resp_body_raw(response),f);f
}
# Review these rules before proceeding with any new collection.
for(site in c('https://13f.info','https://www.digrin.com','https://stockanalysis.com','https://www.newyorkfed.org')){
 n<-if(grepl('13f',site))'13f' else if(grepl('digrin',site))'digrin' else if(grepl('stockanalysis',site))'stockanalysis' else 'nyfed'
 f<-fetch(paste0(site,'/robots.txt'),paste0(n,'_robots.txt'))
 if(any(grepl('^Disallow:\\s*/\\s*$',readLines(f,warn=FALSE),ignore.case=TRUE)))stop('Root-level robots disallow: stop collection.')
 file.copy(f,file.path(post_dir,'data/raw',basename(f)),overwrite=TRUE)
}
fetch('https://www.digrin.com/terms/','digrin_terms.html')
terms<-fetch('https://stockanalysis.com/terms-of-use/','stockanalysis_terms.html')
stopifnot(grepl('This does not apply to search engines, AI agents, or other crawlers that follow our robots.txt file.',html_text2(read_html(terms)),fixed=TRUE))
manager_ids<-c(Vanguard='0000102909-vanguard-group-inc',BlackRock='0001364742-blackrock-inc',StateStreet='0000093751-state-street-corp',FMR='0000315066-fmr-llc',Geode='0001214717-geode-capital-management-llc')
for(m in names(manager_ids)){
 h<-read_html(fetch(paste0('https://13f.info/manager/',manager_ids[[m]]),paste0(m,'_history.html')))
 a<-html_elements(h,'a[href]');labels<-html_text2(a);links<-html_attr(a,'href')
 for(q in 1:2){
  u<-unique(links[labels==paste0('Q',q,' 2024')]);stopifnot(length(u)==1)
  n<-paste0(m,'_2024Q',q);f<-fetch(paste0('https://13f.info',u),paste0(n,'.html'))
  hq<-read_html(f);keys<-trimws(html_text2(html_elements(hq,'dt')));values<-trimws(html_text2(html_elements(hq,'dd')))
  stopifnot(values[keys=='Form type']=='13F-HR',as.Date(values[keys=='Date filed'],'%m/%d/%Y')<as.Date('2024-08-30'))
  endpoint<-html_attr(html_element(hq,'table[data-url]'),'data-url');stopifnot(!is.na(endpoint))
  fetch(paste0('https://13f.info',endpoint),paste0(n,'.json'))
 }
}
for(t in c('JPM','BAC','C','WFC','GS','MS','USB','PNC','TFC','COF','KBE')){
 fetch(paste0('https://www.digrin.com/stocks/detail/',t,'/price'),paste0(t,'_prices.html'))
 u<-if(t=='KBE')'https://stockanalysis.com/etf/kbe/dividend/' else paste0('https://stockanalysis.com/stocks/',tolower(t),'/dividend/')
 fetch(u,paste0(t,'_dividends.html'))
}
fetch('https://www.newyorkfed.org/medialibrary/media/research/banking_research/QuarterlyTrends2023Q4.pdf?hash=085DF7EB1CAEE14D2FCC011A20B37FD7&sc_lang=en','NYFed_2023Q4.pdf')
message('Next: run extract_universe.py, then make_excerpts.R, then analysis.R; see README.')
