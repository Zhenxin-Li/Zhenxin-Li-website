library(jsonlite)
library(ggplot2)
if (!exists('post_dir')) post_dir <- normalizePath('.')
all_data <- fromJSON(file.path(post_dir,'results/explorer.json'), simplifyVector=FALSE)
facts <- fromJSON(file.path(post_dir,'results/facts.json'), simplifyVector=FALSE)
case <- all_data$cases[['200']]
default <- case$levels[['95']]
v <- function(x) as.numeric(unlist(x))
fmt_value <- function(x)sprintf('%.2f',x)
hist_frame <- function(h) data.frame(x=v(h$x),density=v(h$density),width=v(h$width))
base <- theme_minimal(base_size=13)+theme(plot.title=element_text(face='bold'),
  plot.caption=element_text(hjust=0),panel.grid.minor=element_blank(),legend.position='bottom')
dir.create(file.path(post_dir,'figures'),showWarnings=FALSE)
g1 <- ggplot(hist_frame(case$bootstrap_hist),aes(x,density))+
  annotate('rect',xmin=default$low,xmax=default$high,ymin=-Inf,ymax=Inf,fill='#d5eeeb',alpha=.7)+
  geom_col(width=case$bootstrap_hist$width[[1]],fill='#326a88',alpha=.85)+
  geom_vline(xintercept=c(default$low,default$high),color='#117a72',linetype='dashed')+
  geom_vline(xintercept=case$mean,color='#174a68',linewidth=.9)+
  geom_vline(xintercept=3,color='#916526',linetype='dotted')+
  labs(title='Resample one dataset to estimate uncertainty',
       subtitle=sprintf('n = 200 | 9,999 bootstrap means | 95%% interval [%s, %s]',fmt_value(default$low),fmt_value(default$high)),
       x='Bootstrap sample mean',y='Density',
       caption='Solid: observed mean. Dashed: percentile interval. Dotted: known population mean (3).')+base
ggsave(file.path(post_dir,'figures/bootstrap.png'),g1,width=10,height=5,dpi=170)
ci <- do.call(rbind,lapply(default$show,function(a)data.frame(run=a$run,low=a$low,high=a$high,hit=a$hit)))
ci$status <- ifelse(ci$hit,'Contains 3','Misses 3')
g2 <- ggplot(ci,aes(y=run,color=status))+geom_segment(aes(x=low,xend=high,yend=run),linewidth=.7)+
  geom_vline(xintercept=3,linetype='dashed',color='#1e3140')+scale_y_reverse()+
  scale_color_manual(values=c('Contains 3'='#247b83','Misses 3'='#bc5834'))+
  labs(title='Repeat the entire sampling-and-interval procedure',
       subtitle=sprintf('%d / 2,000 intervals contain 3: %.1f%% (95%% target)',default$covered,100*default$coverage),
       x='95% interval for population mean',y='Experiment',color=NULL,
       caption='First 100 experiments shown in original order; coverage uses all 2,000.')+base
ggsave(file.path(post_dir,'figures/coverage.png'),g2,width=10,height=6,dpi=170)
h <- hist_frame(case$null_hist)
g3 <- ggplot(h,aes(x,density))+geom_col(width=h$width[1],fill='#a6b4c0')+
  annotate('rect',xmin=-Inf,xmax=-abs(case$t),ymin=-Inf,ymax=Inf,fill='#3d8cae',alpha=.24)+
  annotate('rect',xmin=abs(case$t),xmax=Inf,ymin=-Inf,ymax=Inf,fill='#3d8cae',alpha=.24)+
  geom_vline(xintercept=c(-default$critical,default$critical),color='#b24632',linetype='dashed')+
  geom_vline(xintercept=c(-abs(case$t),abs(case$t)),color='#14678f')+
  labs(title='Simulate what a zero population mean would produce',
       subtitle=sprintf('50,000 null samples | observed t = %.2f | two-sided Monte Carlo p = %.3f',case$t,case$p),
       x='Studentized mean, t',y='Density',
       caption='Blue shading: p-value tails. Red dashed lines: 5% rejection-region boundaries.')+base
ggsave(file.path(post_dir,'figures/null_test.png'),g3,width=10,height=5,dpi=170)
writeLines(capture.output(sessionInfo()),file.path(post_dir,'results/sessionInfo.txt'))
