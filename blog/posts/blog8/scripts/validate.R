# Independent numerical checks using R's quantiles and Student t distribution.
library(jsonlite)
if (!exists('post_dir')) post_dir <- normalizePath('.')
d <- fromJSON(file.path(post_dir,'results/explorer.json'),simplifyVector=FALSE)
households <- read.csv(file.path(post_dir,'data/simulated/households.csv'))
ci <- read.csv(file.path(post_dir,'results/coverage_intervals.csv'))
checks <- list()
add <- function(label,ok) checks[[length(checks)+1]] <<- data.frame(check=label,passed=isTRUE(ok))
for(n in c(50,200,800)){
  a <- households$saving_usd[seq_len(n)]
  c <- d$cases[[as.character(n)]]
  boot <- read.csv(file.path(post_dir,sprintf('data/simulated/bootstrap_n%d.csv',n)))$mean_saving
  null <- read.csv(file.path(post_dir,sprintf('data/simulated/null_n%d.csv',n)))$t_statistic
  add(paste(n,'sample mean and t'),abs(mean(a)-c$mean)<1e-12 && abs(mean(a)/(sd(a)/sqrt(n))-c$t)<1e-12)
  # Exact conditional bootstrap moments for a sample mean.
  expected_variance <- sum((a-mean(a))^2)/n^2
  add(paste(n,'bootstrap mean within Monte Carlo noise'),abs(mean(boot)-mean(a))<5*sqrt(expected_variance/length(boot)))
  add(paste(n,'bootstrap variance agrees with exact conditional variance'),abs(var(boot)/expected_variance-1)<.08)
  exact_p <- 2*pt(-abs(c$t),df=n-1)
  mcse <- sqrt(max(exact_p,1/length(null))*(1-exact_p)/length(null))
  add(paste(n,'Monte Carlo p agrees with analytic normal-model t test'),abs(c$p-exact_p)<5*mcse+1/length(null))
  add(paste(n,'raw null tail p'),abs(c$p-(1+sum(abs(null)>=abs(c$t)))/(length(null)+1))<1e-12)
  for(level in c(90,95,99)){
    z <- c$levels[[as.character(level)]]
    limits <- quantile(boot,c((1-level/100)/2,1-(1-level/100)/2),type=7)
    add(paste(n,level,'independent percentile bounds'),max(abs(limits-c(z$low,z$high)))<1e-10)
    rows <- ci[ci$n==n & abs(ci$confidence-level/100)<1e-8,]
    hits <- rows$lower<=3 & rows$upper>=3
    add(paste(n,level,'coverage recomputed across fresh samples'),nrow(rows)==2000 && sum(hits)==z$covered && abs(mean(hits)-z$coverage)<1e-12)
  }
}
answer <- do.call(rbind,checks)
write.csv(answer,file.path(post_dir,'results/independent_validation.csv'),row.names=FALSE)
stopifnot(all(answer$passed))
print(answer)
