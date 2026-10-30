library(httr2);library(rvest)
if(!exists('post'))post <- normalizePath('.',winslash='/')
private <- file.path(post,'data/private/full_html');logfile<-file.path(post,'data/raw/requests.csv')
if(file.exists(logfile) && !file.exists(file.path(private,'holdings.html')))stop('Published snapshot present: collect in a fresh directory; never mix dates.')
dir.create(private,recursive=TRUE,showWarnings=FALSE)
ua <- 'Codex-AcademicBlog-AIAgent/1.0 (+https://github.com/Zhenxin-Li/Zhenxin-Li-website)'
fetch <- function(url,name){p<-file.path(private,name);if(file.exists(p))return(p);Sys.sleep(5);stamp<-format(Sys.time(),tz='UTC',format='%Y-%m-%dT%H:%M:%SZ');r<-request(url)|>req_user_agent(ua)|>req_timeout(45)|>req_error(is_error=function(x)FALSE)|>req_perform();code<-resp_status(r);row<-data.frame(url=url,file=name,retrieved_utc=stamp,status=code,content_type=resp_header(r,'content-type'));write.table(row,logfile,sep=',',row.names=FALSE,col.names=!file.exists(logfile),append=file.exists(logfile),qmethod='double');cat(name,code,'\n');if(code!=200L)stop('Stopped at HTTP error; do not retry or bypass.');writeBin(resp_body_raw(r),p);p}
# Already-reviewed public robots paths, now archive the current responses.
fetch('https://13f.info/robots.txt','13f_robots.txt')
fetch('https://www.digrin.com/robots.txt','digrin_robots.txt')
fetch('https://www.digrin.com/terms/','digrin_terms.html')
fetch('https://stockanalysis.com/robots.txt','stockanalysis_robots.txt')
fetch('https://stockanalysis.com/terms-of-use/','stockanalysis_terms.html')
p<-fetch('https://13f.info/13f/000095012324008740-berkshire-hathaway-inc-q2-2024','holdings.html')
u<-html_attr(html_element(read_html(p),'table[data-url]'),'data-url');stopifnot(u=='/data/13f/000095012324008740');fetch(paste0('https://13f.info',u),'holdings.json')
for(t in c('BAC','C','COF','ALLY','AXP','KBE')){
 fetch(paste0('https://www.digrin.com/stocks/detail/',t,'/price'),paste0(t,'_prices.html'))
 url<-if(t=='KBE')'https://stockanalysis.com/etf/kbe/dividend/' else paste0('https://stockanalysis.com/stocks/',tolower(t),'/dividend/')
 fetch(url,paste0(t,'_dividends.html'))
}
cat('Market data captured.\n')

source(file.path(post,'scripts','make_excerpts.R'),local=TRUE)
