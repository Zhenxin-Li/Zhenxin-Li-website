# Reanalyse the preserved historical rvest output; ordinary rendering is offline.
library(dplyr)
library(ggplot2)
raw_dir <- file.path(post_dir,"data","raw")
results_dir <- file.path(post_dir,"results")
fig_dir <- file.path(post_dir,"figures")
dir.create(results_dir,recursive=TRUE,showWarnings=FALSE)
dir.create(fig_dir,recursive=TRUE,showWarnings=FALSE)
raw <- read.csv(file.path(raw_dir,"finviz_original.csv"),stringsAsFactors=FALSE)
required <- c("ticker","company_name","sector","industry","country","market_cap","pe","inst_own","short_float")
stopifnot(all(required %in% names(raw)))
num <- function(x) suppressWarnings(as.numeric(gsub("[%x,]","",x)))
cap <- function(x) {
  v <- suppressWarnings(as.numeric(sub("[BMT]$","",x)))
  v * ifelse(grepl("T$",x),1e12,ifelse(grepl("B$",x),1e9,ifelse(grepl("M$",x),1e6,NA_real_)))
}
unique_rows <- distinct(raw)
stopifnot(!anyDuplicated(unique_rows$company_name))
parsed <- unique_rows |>
  rename(source_row_number=ticker) |>
  mutate(pe_num=num(pe),inst_pct=num(inst_own),cap_usd=cap(market_cap))
us <- parsed |> filter(country=="USA",!grepl("Exchange Traded Fund|Shell Companies",industry))
sized <- us |> filter(is.finite(cap_usd),cap_usd>=300e6,cap_usd<10e9)
earning <- sized |> filter(is.finite(pe_num),pe_num>0,pe_num<=200)
complete <- earning |> filter(is.finite(inst_pct),inst_pct>=0)
df <- complete |> filter(inst_pct<=100)
stopifnot(nrow(df)>0)
inst_cut <- median(df$inst_pct)
df <- df |> mutate(low_pe=pe_num<=10,lower_inst=inst_pct<inst_cut,
                   review_flag=low_pe & lower_inst)
audit <- data.frame(stage=c("Original merged rows","Exact duplicate rows removed","Unique companies",
 "USA companies excluding ETFs and shells","Market cap 300m to below 10bn",
 "Positive P/E at most 200","Nonmissing nonnegative institutional ownership","Ownership at most 100%"),
 n=c(nrow(raw),nrow(raw)-nrow(unique_rows),nrow(unique_rows),nrow(us),nrow(sized),nrow(earning),nrow(complete),nrow(df)))
write.csv(audit,file.path(results_dir,"sample_flow.csv"),row.names=FALSE)
write.csv(df |> select(source_row_number,company_name,sector,industry,country,cap_usd,pe_num,inst_pct,low_pe,lower_inst,review_flag),
 file.path(results_dir,"clean_companies.csv"),row.names=FALSE)
shortlist <- df |> filter(low_pe) |> arrange(pe_num) |>
 select(company_name,sector,pe_num,inst_pct,lower_inst)
write.csv(shortlist,file.path(results_dir,"low_pe_companies.csv"),row.names=FALSE)
sensitivity <- bind_rows(lapply(c(8,10,12),function(cutoff) data.frame(pe_cutoff=cutoff,
 low_pe_n=sum(df$pe_num<=cutoff),below_median_ownership_n=sum(df$pe_num<=cutoff & df$lower_inst))))
write.csv(sensitivity,file.path(results_dir,"threshold_sensitivity.csv"),row.names=FALSE)
wide_inst <- median(complete$inst_pct)
write.csv(data.frame(sample=c("Main: ownership <=100%","Sensitivity: retain >100% reports"),
 n=c(nrow(df),nrow(complete)),inst_median=c(inst_cut,wide_inst),
 low_pe_n=c(sum(df$low_pe),sum(complete$pe_num<=10)),
 below_median_ownership_n=c(sum(df$review_flag),sum(complete$pe_num<=10 & complete$inst_pct<wide_inst))),
 file.path(results_dir,"ownership_sensitivity.csv"),row.names=FALSE)
thresholds <- data.frame(pe_cutoff=10,inst_median_pct=inst_cut,n=nrow(df),low_pe_n=sum(df$low_pe),
 below_median_ownership_n=sum(df$review_flag))
write.csv(thresholds,file.path(results_dir,"thresholds.csv"),row.names=FALSE)
checks <- data.frame(check=c("Unique company records","Source IDs identified as row numbers", "USA only",
 "Explicit market cap range", "Complete analysis fields", "Low PE subset follows declared rule"),
 passed=c(!anyDuplicated(df$company_name),all(grepl("^[0-9]+$",raw$ticker)),all(df$country=="USA"),
 all(df$cap_usd>=300e6 & df$cap_usd<10e9),all(is.finite(as.matrix(df[c("pe_num","inst_pct")]))),
 all(shortlist$pe_num<=10)))
stopifnot(all(checks$passed))
write.csv(checks,file.path(results_dir,"validation.csv"),row.names=FALSE)
write.csv(data.frame(file="finviz_original.csv",md5=unname(tools::md5sum(file.path(raw_dir,"finviz_original.csv")))),
 file.path(results_dir,"snapshot_checksum.csv"),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(results_dir,"sessionInfo.txt"))
theme_set(theme_minimal(base_size=12))
fig1 <- ggplot(df,aes(pe_num,inst_pct)) +
 geom_point(aes(colour=low_pe),size=3,alpha=.85) +
 geom_vline(xintercept=10,linetype="dashed",colour="#334155") +
 geom_hline(yintercept=inst_cut,linetype="dotted",colour="#334155") +
 scale_x_log10(breaks=c(5,10,20,50,100,200)) +
 scale_colour_manual(values=c("FALSE"="#176b91","TRUE"="#b45309"),labels=c("P/E above 10","P/E at most 10")) +
 labs(title="Low P/E companies do not have identical ownership",subtitle=paste0(nrow(df)," historical sample companies; each point is one company"),
 x="Trailing P/E (logarithmic scale)",y="Reported institutional ownership (%)",colour=NULL,
 caption="Dashed: P/E = 10. Dotted: sample median ownership. Source: preserved Finviz scrape; capture date unverified.") +
 theme(legend.position="bottom",plot.caption=element_text(size=9))
ggsave(file.path(fig_dir,"company_screen.png"),fig1,width=10,height=6,dpi=180)
