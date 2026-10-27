# Deterministic Braess network, teaching example; no empirical data or packages.
post <- get("post_dir", inherits=TRUE)
fig <- file.path(post,"figures")
out <- file.path(post,"results")
dir.create(fig,recursive=TRUE,showWarnings=FALSE)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
N <- 3000L
fixed <- 35
travel <- function(n) n/100
before_time <- travel(N/2)+fixed
after_time <- 2*travel(N)
deviation_time <- travel(N)+fixed

# u/l/z count upper-only, lower-only, and connector users respectively.
costs <- function(u,l,z) c(upper=travel(u+z)+fixed,
                         lower=fixed+travel(l+z),
                         connector=travel(u+z)+travel(l+z))
flows <- data.frame(network=c("Before","Before","After","After","After"),
 route=c("Home-A-Work","Home-B-Work","Home-A-Work","Home-B-Work","Home-A-B-Work"),
 drivers=c(N/2,N/2,0,0,N),
 minutes=c(before_time,before_time,deviation_time,deviation_time,after_time))
write.csv(flows,file.path(out,"route_times.csv"),row.names=FALSE)

# Include the deviator's own effect: compute the cost after each switch.
before_switch <- fixed+travel(N/2+1)
connector_at_old_split <- travel(N/2)+travel(N/2+1)
upper_to_connector_gain <- fixed-travel(seq_len(N))
lower_to_connector_gain <- fixed-travel(seq_len(N))
checks <- data.frame(check=c("Before: unilateral old-route switch is slower",
 "After: either old-route switch is slower",
 "Any old-route user can improve via the connector",
 "Old split is not an equilibrium with connector available",
 "Both networks conserve all drivers",
 "New equilibrium is slower for everyone"),
 passed=c(before_switch>before_time,deviation_time>after_time,
 all(upper_to_connector_gain>0)&all(lower_to_connector_gain>0),
 connector_at_old_split<before_time,
 sum(flows$drivers[flows$network=="Before"])==N &
 sum(flows$drivers[flows$network=="After"])==N,
 after_time>before_time))
stopifnot(all(checks$passed))
write.csv(checks,file.path(out,"validation.csv"),row.names=FALSE)
write.csv(data.frame(before=before_time,after=after_time,
 old_route_deviation=deviation_time,before_switch=before_switch,
 connector_at_old_split=connector_at_old_split,
 extra_minutes=after_time-before_time),file.path(out,"summary.csv"),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,"sessionInfo.txt"))

# Draw each network with the same node positions and direct labels.
draw <- function(connector=FALSE) {
 file <- if(connector) "network_after.png" else "network_before.png"
 png(file.path(fig,file),width=1800,height=1200,res=180)
 par(mar=c(1,1,4,1),family="sans",xpd=NA)
 plot.new(); plot.window(xlim=c(-.2,10.2),ylim=c(-.65,6.6),asp=1)
 title(main=if(connector) "After: everyone takes the connector" else "Before: traffic splits between two routes",
       sub="",cex.main=1.3,col.main="#172b4d")
 pos <- list(H=c(0,3),A=c(5,6),B=c(5,0),W=c(10,3))
 blue <- "#176b91"; amber <- "#b45309"; grey <- "#77869a"
 edge <- function(a,b,col,lwd=3,lty=1) {
  v <- pos[[b]]-pos[[a]]; unit <- v/sqrt(sum(v*v))
  p <- pos[[a]]+.34*unit; q <- pos[[b]]-.34*unit
  arrows(p[1],p[2],q[1],q[2],length=.15,col=col,lwd=lwd,lty=lty)
 }
 edge("H","A",blue); edge("B","W",blue)
 edge("A","W",if(connector) grey else blue,lty=if(connector) 2 else 1)
 edge("H","B",if(connector) grey else blue,lty=if(connector) 2 else 1)
 if(connector) edge("A","B",amber,4)
 n <- if(connector) N else N/2
 t <- travel(n)
 text(2.15,5.2,sprintf("n / 100 = %g min\n%s drivers",t,format(n,big.mark=",",trim=TRUE)),col=blue,cex=1.02)
 text(7.85,.8,sprintf("n / 100 = %g min\n%s drivers",t,format(n,big.mark=",",trim=TRUE)),col=blue,cex=1.02)
 text(7.85,5.2,if(connector) "35 min\nUnused" else "35 min\n1,500 drivers",col=if(connector) grey else blue,cex=1.02)
 text(2.15,.8,if(connector) "35 min\nUnused" else "35 min\n1,500 drivers",col=if(connector) grey else blue,cex=1.02)
 if(connector) text(5.4,3,"New connector\n0 min\n3,000 drivers",adj=c(0,.5),col=amber,cex=1.03)
 for(k in names(pos)) {
  points(pos[[k]][1],pos[[k]][2],pch=21,bg="white",col="#172b4d",cex=4.2,lwd=2)
  text(pos[[k]][1],pos[[k]][2],switch(k,H="Home",W="Work",k),cex=if(k %in% c("H","W")) .72 else 1)
 }
 text(5,-.65,if(connector) "30 + 0 + 30 = 60 minutes per driver" else "15 + 35 = 50 minutes per driver",font=2,cex=1.25,col="#172b4d")
 mtext("3,000 drivers; one-way arrows; n is the number using that road.",side=3,line=.3,cex=.86)
 dev.off()
}
draw(FALSE); draw(TRUE)
