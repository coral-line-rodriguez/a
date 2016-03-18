#################################################
# Author: Robin Elahi
# Date: 160315
# Testing the sensitivity of IPM results to variation in 
# Ea on x-intercept of fecundity function (which has
# downstream effects on size at maturity, establishment probability)
#################################################

rm(list=ls(all=TRUE)) 

##### LOAD PACKAGES ETC #####
source("./R/bael_params.R")
source("./R/ipmFunctions.R")
source("R/get_histo_ipm_data.R")

##### MAX AND MIN SIZES #####
# Will use slightly larger size range for IPM because
# it is otherwise artificially truncated
min.size <- 0.02
max.size <- 1.52

binSize <- 0.02
binN <- (max.size - min.size)/binSize
binN

##### IPMs WITH FOR LOOP THROUGH EAS #####
data_in <- loopDat
N <- dim(data_in)[1]

# Lists to store the results of IPMs
ipm_out <- result <- vector("list", N) 
res_out <- result <- vector("list", N) 

# Dataframe to store Ea and the log-likelihood of the size distribution (ssd2) to the observed size-frequency distribution

# Use same bin sizes and range as IPM
histBreaks <- seq(min.size, max.size, binSize)

areaH_07 <- hist(hist10$area, breaks = histBreaks)
areaH_10 <- hist(hist10$area, breaks = histBreaks)
areaH_0710 <- hist(hist0710$area, breaks = histBreaks)

dns07 <- areaH_07$density
dns10 <- areaH_10$density
dns0710 <- areaH_0710$density

data_out <- data.frame(Ea = data_in$Ea, 
                       LL07 = NA, 
                       LL10 = NA, 
                       LL0710 = NA)

# Initialize parameter dataframe
paramDF <- paramsWA # the cells will be modified in the loop

for (i in 1:N){
  # Create new paramDF, with modified fecundity parameters
  params.i <- data_in[i, ]
  paramDF$estab.prob.mean <- params.i$estab.prob.mean
  paramDF$estab.prob.sd <- params.i$estab.prob.sd
  paramDF$embryo.int <- params.i$embryo.int
  paramDF$mature.size <- params.i$mature.size
  
  # Now run IPM
  ipm1 <- bigmatrix(n = binN, params = paramDF)
  res1 <- popF(ipm1, binSize)
  
  # Store log likelihood results in data_out
  Ea.i <- as.character(params.i$Ea)
  LL07.i <- - sum(dns07 * log(res1$ssd2))
  LL10.i <- - sum(dns10 * log(res1$ssd2))
  LL0710.i <- - sum(dns0710 * log(res1$ssd2))
  data_out[i, ] <- c(Ea.i, LL07.i, LL10.i, LL0710.i)

  # Store IPM results in lists  
  ipm_out[[i]] <- ipm1
  res_out[[i]] <- res1
  
}

head(data_out)
str(ipm_out[[1]])
str(res_out[[1]])

##### IPMs for WA and CA #####
### Base IPM, original parameters
ipm1 <- bigmatrix(n = binN, params = paramsWA)
res1 <- popF(ipm1, binSize)
res1[1:8]

### Modified IPM, with modified embryo and recruitment parameters
ipm2 <- bigmatrix(n = binN, params = paramsCA)
res2 <- popF(ipm2, binSize)
res2

##### CALCULATE LL #####
# Use 2010 data
area.h <- hist(hist10$area, breaks = seq(0.02, 1.5, 0.02))
area.h
cnt <- area.h$counts 
dns <- area.h$density
sum(cnt) 
sum(dns); length(dns)
sum(dns * 0.05)

# using density
mod1LL <- - sum(dns * log(res1$ssd2)); mod1LL # LL for empirical data is -1.2

### Plot LL's
head(data_out)
names(data_out) <- c("Ea", "SizeDistribution_2007", 
                     "SizeDistribution_2010", "SizeDistribution_bothYears")

logLikLong <- data_out %>% gather(key = Year, value = LogLik, 
                                  SizeDistribution_2007:SizeDistribution_bothYears) %>% 
  mutate(LogLik = as.numeric(LogLik), Ea = as.numeric(Ea))

str(logLikLong)

##### PLOT LL RESULTS #####

ggplot(logLikLong, aes(Ea, LogLik)) +
  geom_point(size = 0.5) + geom_line(color = 'red') +
  facet_wrap(~ Year, scales = "fixed") +
  ylab("Log likelihood") + xlab("Activation energy (Ea)") +
  geom_point(data = logLikLong[logLikLong$Ea == 0.65, ],
             aes(Ea, LogLik), color = "blue")

ggsave("figs/fecundityParams_Ea_LogLik_3.pdf",
       height = 3.5, width = 7)

bothYears <- logLikLong %>% filter(Year == "SizeDistribution_bothYears") %>%
  filter(LogLik < 50)

ggplot(bothYears, aes(Ea, LogLik)) +
  geom_point(size = 0.5) + geom_line(color = 'red') +
  ylab("Log likelihood") + xlab("Activation energy (Ea)") +
  geom_point(data = logLikLong[logLikLong$Ea == 0.65, ],
             aes(Ea, LogLik), color = "blue")

ggsave("figs/fecundityParams_Ea_LogLik_1.pdf",
       height = 3.5, width = 3.5)

bothYears %>% filter(Ea > 0.64) %>%
  ggplot(., aes(Ea, LogLik)) +
  geom_point(size = 0.5) + geom_line(color = 'red') +
  ylab("Log likelihood") + xlab("Activation energy (Ea)") +
  geom_point(data = logLikLong[logLikLong$Ea == 0.65, ],
             aes(Ea, LogLik), color = "blue")

##### MINIMIZE LOG-LIKELIHOOD, SELECT EA #####

# Get 5 lowest LL values for each Year, then take the median value
llDF <- logLikLong %>% group_by(Year) %>% 
  arrange(LogLik) %>% slice(1:5)

medianEa <- llDF %>% ungroup() %>% summarise(median = median(Ea))
medianEa

# This is the lowest LogLik (i.e. optimized)
llDF %>% ungroup() %>% arrange(LogLik) %>% slice(1:1)

medianEa

# medianEa_position <- which(data_out$Ea == 0.65)

medianEa_position <- which(data_out$Ea == as.numeric(medianEa))

##### CREATE COLOR RAMP #####
range01 <- function(x)(x - min(x))/diff(range(x))
heatRamp <- function(x) {
  cols <- colorRamp(heat.colors(3)) (range01(x))
  apply(cols, 1, function(xt)rgb(xt[1], xt[2], xt[3], maxColorValue = 255))
}
vec_colorsRev <- heatRamp(data_in$Ea)
vec_colors <- rev(vec_colorsRev)

##### PLOTTING #####
pdf("./figs/ipm_histo_fit.pdf", 7, 3.5)
set_graph_pars(ptype = "panel2")
xlab2 <- expression(paste("Size (", cm^2, ")"))

#### Panel A ####

plot(mx.coral ~ areaR, data = ltDat, xlim = c(0, 1.5), ylim = c(-0.025, 40),
     xlab = xlab2, ylab = "Embryo number", las = 1, type = "n")

add_panel_label(ltype = "a")

# for(i in 1:N){
#   curve(slopeCA * x + 
#           data_in$embryo.int[i], from = 0, to = 1.4, add = TRUE, 
#         col = vec_colors[i], lwd = 1)
# }

# abline(mxRegWA, lwd=2, lty=1, col = "darkgray")
abline(mxRegCA, lwd=2, lty=1)
abline(a = 0, b = 0, lty=3, lwd=2, col="darkgray")
points(mx.coral ~ areaR, data = ltDat)

curve(slopeCA * x + data_in$embryo.int[medianEa_position], 
      from = 0, to = 1.5, add = TRUE,
        col = "darkgray", lwd = 2)


add_panel_label(ltype = "a")
legend("bottomright", "n = 12", cex = 1.1, bty = "n", adj = c(0,-2))

leg.txt <- c("Original", "Modified")
legend("topleft", leg.txt, lwd = 2, bty = "n", 
       col = c("black", "darkgray"), lty = 1, 
       cex = 1, text.col = c("black", "darkgray"))

#### Panel B ####
quantile(hist0710$area, probs = c(0.95, 0.99))
obs99 <- quantile(hist0710$area, probs = 0.99)

# hist(hist0710$area, breaks = seq(0.02, 1.5, 0.02), freq = FALSE,
#      xlab = xlab2, ylab="Probability density", col = "gray87", main = "",
#      ylim = c(-0.025, 2.5), xlim = c(0, 1.5), border = "gray90", las = 1)

# Used larger bins to reduce noise
hist(hist0710$area, breaks = seq(0.0, 1.5, 0.05), freq = FALSE,
     xlab = xlab2, ylab="Probability density", col = "gray87", main = "",
     ylim = c(-0.025, 2), xlim = c(0, 1.4), border = "gray90", las = 1)

box()

# for(i in 1:N){
#   points(ipm_out[[i]]$meshpts , res_out[[i]]$ssd2, type="l", lty=1, lwd = 1, 
#          col = vec_colors[i])
# }

# # Ea = 0.65 
# points(ipm1$meshpts , res1$ssd2, type="l", lty=1, lwd = 2, 
#        col = "darkgray")

# California parameters
points(ipm2$meshpts , res2$ssd2, type="l", lty=1, lwd = 2, 
       col = "black")

# Optimized Ea = 0.658
points(ipm_out[[medianEa_position]]$meshpts , 
       res_out[[medianEa_position]]$ssd2, type="l", lty=1, lwd = 2, 
       col = "darkgray")

# arrows(res2$max95, 0.4, res2$max95, 0.05, col = "black", 
#        length = 0.1, lwd = 1, angle = 20, lty = 1)		
arrows(res2$max99, 0.4, res2$max99, 0.13, col = "black", 
         length = 0.1, lwd = 1, angle = 20, lty = 1)

# arrows(res_out[[medianEa_position]]$max95, 0.4, 
#          res_out[[medianEa_position]]$max95, 0.05, col = "darkgray", 
#          length = 0.1, lwd = 1, angle = 20, lty = 1)	

arrows(res_out[[medianEa_position]]$max99, 0.4, 
         res_out[[medianEa_position]]$max99, 0.13, col = "darkgray", 
         length = 0.1, lwd = 1, angle = 20, lty = 1)	

# points(obs99, 0, pch = 21, col = "darkgray", lwd = 2)

add_panel_label(ltype = "b")

legend("topright", leg.txt, lwd = 2, bty = "n", 
       col = c("black", "darkgray"), lty = 1, 
       cex = 1, text.col = c("black", "darkgray"))

dev.off()
