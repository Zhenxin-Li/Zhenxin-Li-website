# An analytical teaching example; no empirical data or network access required.
post <- get("post_dir", inherits = TRUE)
fig <- file.path(post, "figures")
out <- file.path(post, "results")
dir.create(fig, showWarnings = FALSE, recursive = TRUE)
dir.create(out, showWarnings = FALSE, recursive = TRUE)
value <- function(income) 2 * log(income / 2)
multiplier <- function(income) 2 / income
budgets <- c(10, 11, 20)
optimal <- data.frame(income = budgets, x = budgets/2, y = budgets/2,
                      utility = value(budgets), lambda = multiplier(budgets))
write.csv(optimal, file.path(out, "optimal_bundles.csv"), row.names = FALSE)
delta <- c(.01, 1, 10)
comparison <- data.frame(extra_budget = delta,
                        exact_gain = value(10+delta)-value(10),
                        marginal_prediction = multiplier(10)*delta)
write.csv(comparison, file.path(out, "finite_changes.csv"), row.names = FALSE)

# Independent one-dimensional numerical optimization and derivative verification.
numerical_x <- vapply(budgets, function(i) {
  optimize(function(x) log(x)+log(i-x), c(1e-6, i-1e-6), maximum=TRUE,
           tol=1e-10)$maximum
}, numeric(1))
h <- 1e-5
derivative <- (value(budgets+h)-value(budgets-h))/(2*h)
checks <- data.frame(check = c("Numerical and analytical optimum agree",
 "Budget exhausted", "Envelope derivative equals multiplier", "Tangent overpredicts finite positive gain"),
 passed = c(max(abs(numerical_x-budgets/2)) < 1e-5,
 all(optimal$x+optimal$y==budgets),
 max(abs(derivative-multiplier(budgets))) < 1e-8,
 all(comparison$exact_gain < comparison$marginal_prediction)))
write.csv(checks, file.path(out, "validation.csv"), row.names=FALSE)
stopifnot(all(checks$passed))
writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))

png(file.path(fig,"budget_tangency.png"), width=1500, height=1500, res=180)
par(mar=c(4.5,4.5,3.8,1), family="sans", las=1, col.axis="#334155", col.lab="#334155",
    pty="s", xaxs="i", yaxs="i")
plot(NA, xlim=c(0,11.5), ylim=c(0,11.5), asp=1, xlab="Good x (units)", ylab="Good y (units)",
 main="More budget moves the best attainable bundle", bty="l")
polygon(c(0,10,0),c(0,0,10), col="#eaf2f7", border=NA)
abline(a=10,b=-1,col="#176b91",lwd=2.5)
abline(a=11,b=-1,col="#b45309",lwd=2.5,lty=2)
x <- seq(.1,11.5,length.out=1000)
lines(x,25/x,col="#176b91",lwd=2)
lines(x,30.25/x,col="#b45309",lwd=2,lty=2)
points(c(5,5.5),c(5,5.5),pch=19,col=c("#176b91","#b45309"),cex=1.2)
text(5,5,"A: (5, 5)",pos=2,offset=.8,cex=.9)
text(5.5,5.5,"B: (5.5, 5.5)",pos=4,offset=.8,cex=.9)
legend("topright",c("Budget $10", "Budget $11"),
 col=c("#176b91","#b45309"),lty=c(1,2),lwd=2,bty="n",cex=.8)
mtext("Prices are both $1; U(x,y) = log(x) + log(y). Shading: initial affordable set.",side=3,line=.4,cex=.75)
dev.off()

png(file.path(fig,"marginal_vs_finite.png"),width=1800,height=1200,res=180)
par(mar=c(4.5,4.5,4,1), family="sans",las=1,col.axis="#334155",col.lab="#334155")
d <- seq(0,10,length.out=401)
plot(d,multiplier(10)*d,type="n",xlab="Extra budget beyond $10 (dollars)",
 ylab="Gain in maximized utility (utility units)",main="A shadow price is a local prediction",bty="l",ylim=c(0,2.12))
abline(h=seq(0,2,.5),col="#e5e7eb",lwd=.8)
lines(d,value(10+d)-value(10),col="#176b91",lwd=3)
lines(d,multiplier(10)*d,col="#b45309",lwd=2.5,lty=2)
points(c(1,10),value(10+c(1,10))-value(10),pch=19,col="#176b91")
text(1,value(11)-value(10),"$1 extra: actual 0.191; prediction 0.200",pos=4,offset=.7,cex=.8)
text(10,value(20)-value(10),"$10 extra: actual 1.386",pos=2,offset=.7,cex=.8)
legend("topleft",c("Exact gain: V(10 + extra) - V(10)","Initial multiplier x extra budget"),
 col=c("#176b91","#b45309"),lty=c(1,2),lwd=c(3,2.5),bty="n",cex=.85)
mtext("At budget 10, lambda = 0.200 utility units per dollar; it falls as the budget grows.",side=3,line=.5,cex=.75)
dev.off()
