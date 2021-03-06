
# Welcome to the first of two scripts looking at GLLVMs through an ecological lens. Today we'll focus largely on
# the use of ordinations, while tomorrow will focus a bit more on JSDMs. This script was written to be fully 
# self-containing, and while the lecture slides that go with it add a bit of info, you should be able
# to run everything here independently. There's also an R markdown document that will have the figures produced
# by the scripts below.

# We start by loading all the requisite packages.

library(gllvm)
library(dplyr)
library(grDevices)

# The data we're using for this session was collected largely by the ECOSPAT Group at the University of 
# Lausanne. It looks at co-occurrence patterns in different plants in the Swiss Alps. The original dataset 
# can be found at https://doi.org/10.5061/dryad.8mv11, which also contains links to a fantastic paper 
# by Manuela D'Amen, Heidi Mod, Nicholas Gotelli and Antoine Guisan which uses the data, entitled 
# "Disentangling biotic interactions, environmental filters, and dispersal limitation as drivers of 
# species co-occurrence". The elevational data has been provided by SwissTopo.

# As a very basic overview, the original data includes presence-absence data for 183 plants over 912
# sites, andthe following environmental covariates. The dataset included below is a subset, so that 
# this all runs a bit fasterduring the workshop. Obviously subsetting like this isn't always recommended,
# but if you'd like to run it with the full dataset we're happy to provide it.

# These are our environmental covariates.

# DDEG0 - Days over zero degrees
# SOLRAD - Summed annual solar radiation
# SLOPE - Slope angle in degrees
# MIND - Moisture index
# TPI - Topographic position index
# ELEVATION - Number of kangaroos present at site (joking it's just elevation)

# Each of these envionmental covariates has been standardised to a mean of 0 and SD of 1. This is just to help
# model convergence.

load("WorkshopData.RDA")

Y <- WorkshopData$Y
X <- WorkshopData$X

# For starters, let's run a basic gllvm using no environmental variables. Note that sd.errors
# is set to FALSE, since we're not really interested in the effect size of environmental covariates 
# in this particular session.

time1 <- Sys.time()
fit_base <- gllvm(Y, num.lv = 2, family = binomial(link="probit"), sd.errors = FALSE)
Sys.time()-time1

# Before we look at our latent variables, let's have a look at collinearity. The following
# code shows any significant collinearity between our environmental covariates.

source("http://www.sthda.com/upload/rquery_cormat.r")
colin <- rquery.cormat(X, type = "flatten", graph = FALSE)
colin$r %>% filter(abs(cor) > 0.5)

# row    column   cor        p
# 1 DDEG0      MIND -0.89 6.9e-141
# 2 DDEG0 ELEVATION -0.99  0.0e+00
# 3  MIND ELEVATION  0.90 4.0e-148

# The high cor values and low p values indicate some serious collinearity between positive degree days, 
# elevation and moisture index. 

# Let's see if our latent variables correspond to any of these covariates.

# We define colours according to the values of covariates. The darker blue indicates a higher value
# of the relevant covariate.

par(mfrow=c(2,2))
for (i in 1:length(colnames(X))) {
  covariate <- X[,i]
  rbPal <- colorRampPalette(c('mediumspringgreen', 'blue'))
  Colorsph <- rbPal(20)[as.numeric(cut(covariate, breaks = 20))]
  breaks <- seq(min(covariate), max(covariate), length.out = 30)

  ordiplot(fit_base, main = paste0("Ordination of sites, color: ",colnames(X)[i]),
           symbols = TRUE, s.colors = Colorsph, xlim = c(-1.2,1.2), ylim = (c(-1.2, 1.2)))
}

# We can see some quite clear gradients related to the four collinear variables we mentioned
# above. At this point let's take one of the two climate related covariates that could have a
# direct impact on vegetation (DDEG0) and SLOPE, since MIND is so collinear to DDEG0, and
# slope might have a more direct impact than elevation on our community.

# Let's use these two and use some code from last session to figure out how many latent
# variables would be appropriate. Basically we're running the same model again and again, but 
# increasing the number of latent variables each time. I'm using the lowest AICc value to determine the
# model which fits best.

fit_list <- list()
for(i in 0:3){
  fit_sub <- gllvm(Y, X, family = binomial(link="probit"), num.lv = i, sd.errors = FALSE, 
                formula = ~ SLOPE + MIND, seed = 1234)
  fit_list[[i+1]] <- fit_sub
}

# Let's have a look at how our AICc values look.

AICc <- sapply(fit_list, function(X) {summary(X)$AICc})
data.frame(AICc, model= paste0("LV-",0:3))

# AICc      model
# 14687.36  LV-0
# 12957.51  LV-1
# 12625.36  LV-2
# 12970.21  LV-3

# We can see that the best model here uses 2 latent variables. Let's have a look at 
# how these variables compares to our remaining environmental covariates. 

par(mfrow = c(2, 2), mar = c(4, 4, 2, 1))
remaining_covariates <- c("DDEG0","SOLRAD","ELEVATION","TPI")

for(i in 1:length(remaining_covariates)) {
  covariate <- X[,remaining_covariates[i]]
  rbPal <- colorRampPalette(c('mediumspringgreen', 'blue'))
  Colorsph <- rbPal(20)[as.numeric(cut(covariate, breaks = 20))]
  breaks <- seq(min(covariate), max(covariate), length.out = 30)
  ordiplot(fit_list[[3]], main = paste0("Ordination of sites, color: ",remaining_covariates[i]),
         symbols = TRUE, s.colors = Colorsph, xlim = c(-1.2,1.2), ylim = (c(-1.2, 1.2)))
}

# From this we can see that there is still a bit of variation explained by positive degree days,
# despite its collinearity with moisture index (and by elevation, but we'll focus on that tomorrow).
# Let's see what happens when we include degree days over zero.

fit_DegreeDays <- gllvm(Y, X, family = binomial(link="probit"), num.lv = 2, sd.errors = FALSE, 
              formula = ~ SLOPE + MIND + DDEG0, seed = 1234)

summary(fit_DegreeDays)$AICc

# [1] 12743.35

# We can see the AICc values stay pretty much the same, even rising a bit. But leaving it out means 
# we may attribute variation to our latent variable that is the result of the environment.


### EXTENDED QUESTION ####
# Have a look at the coefficient effects using the basic command below, after switching sd.errors to 
# TRUE in your gllvm commands. How do the covariate effects change with the introduction of new variables?

# coefplot(fit_Elevation, cex.ylab = 0.5)

###################################################
# Breakout questions #
# What is a species association?
# If we accounted for all possible covariates producing environmental variation, 
# would we still see species associations?
###################################################

# What I've previously done here is group species together based on approximately what elevation
# their occurrence peaks at. This left us with three groups; montane, subalpine and alpine species.
# The colour plots below mean we can see each group easily in our ordination plots.

# NB: The 'ordiplot' function below is a product of a recent update. If you find that it's not 
# working, I've attached a fully coded function at the end of this script as a substitute.

colour.groups <- c("red","blue","green")[WorkshopData$elevation_classes]

par(mfrow=c(1,1))
ordiplot(fit_base, biplot=TRUE, main = "Ordination of sites: no covariates",
         symbols = TRUE, s.colors = "white", xlim = c(-4,4),ylim=c(-3,3), spp.colors=colour.groups)

# There are some very obvious trends here. Let's see what happens when we introduce MIND and DDEG0.

ordiplot(fit_list[[3]], biplot=TRUE, main = "Ordination of sites: two covariates",
         symbols = TRUE, s.colors = "white", xlim = c(-4,4),ylim=c(-3,3), spp.colors=colour.groups)

# And now when we introduce degree days as an extra covariate.

ordiplot(fit_DegreeDays, biplot=TRUE, main = "Ordination of species: three covariates",
         symbols = TRUE, s.colors = "white", xlim = c(-4,4),ylim=c(-3,3), spp.colors=colour.groups)


# You can see that the species group together more clearly, as the effect of the latent variable becomes
# weaker.

### EXTENDED QUESTION ####
# What happens when we incorporate elevation into the equation as well?

# Lastly, just for a taste of tomorrow, let's check out a co-occurrence plot.

colline_species <- WorkshopData$colline_species

cr1 <- getResidualCor(fit_list[[3]])
corrplot(cr1[colline_species,colline_species], diag = FALSE, type = "lower", 
         method = "square", tl.cex = 0.5, tl.srt = 45, tl.col = "red")

# The blue squares indicate positive associations, which means that the two species are positively
# associated. Red squares indicate the two species are unlikely to co-occur. Larger, darker 
# squares indicate stronger relationships.

#######################################################
# Have any extra questions? Get in touch with us via the conference app!
# You can also contact me directly via email at sam.perrin@ntnu.no or
# on Twitter at @samperrinNTNU.
######################################################



ordiplot.col <- function (object, biplot = FALSE, ind.spp = NULL, alpha = 0.5,
                          main = NULL, which.lvs = c(1, 2), predict.region = FALSE,
                          level = 0.95, jitter = FALSE, jitter.amount = 0.2, s.colors = 1,
                          symbols = FALSE, cex.spp = 0.7, spp.colors = "blue", lwd.ellips = 0.5, col.ellips = 4,
                          lty.ellips = 1, ...)
{
  if (any(class(object) != "gllvm"))
    stop("Class of the object isn't 'gllvm'.")
  a <- jitter.amount
  n <- NROW(object$y)
  p <- NCOL(object$y)
  num.lv <- object$num.lv
  if (!is.null(ind.spp)) {
    ind.spp <- min(c(p, ind.spp))
  }
  else {
    ind.spp <- p
  }
  if(length(spp.colors)==1){
    spp.colors <- rep(spp.colors,p)
  }else if(length(spp.colors)!=p){
    stop("spp.colors needs to be of length p or 1.")
  }
  if (object$num.lv == 0)
    stop("No latent variables to plot.")
  if (is.null(rownames(object$params$theta)))
    rownames(object$params$theta) = paste("V", 1:p)
  if (object$num.lv == 1) {
    plot(1:n, object$lvs, ylab = "LV1", xlab = "Row index")
  }
  if (object$num.lv > 1) {
    do_svd <- svd(object$lvs)
    svd_rotmat_sites <- do_svd$v
    svd_rotmat_species <- do_svd$v
    choose.lvs <- object$lvs
    choose.lv.coefs <- object$params$theta
    bothnorms <- sqrt(colSums(choose.lvs^2)) * sqrt(colSums(choose.lv.coefs^2))
    scaled_cw_sites <- t(t(choose.lvs)/sqrt(colSums(choose.lvs^2)) *
                           (bothnorms^alpha))
    scaled_cw_species <- t(t(choose.lv.coefs)/sqrt(colSums(choose.lv.coefs^2)) *
                             (bothnorms^(1 - alpha)))
    choose.lvs <- scaled_cw_sites %*% svd_rotmat_sites
    choose.lv.coefs <- scaled_cw_species %*% svd_rotmat_species
    B <- (diag((bothnorms^alpha)/sqrt(colSums(object$lvs^2))) %*%
            svd_rotmat_sites)
    Bt <- (diag((bothnorms^(1 - alpha))/sqrt(colSums(object$params$theta^2))) %*%
             svd_rotmat_species)
    if (!biplot) {
      plot(choose.lvs[, which.lvs], xlab = paste("Latent variable ",
                                                 which.lvs[1]), ylab = paste("Latent variable ",
                                                                             which.lvs[2]), main = main, type = "n",
           ...)
      if (predict.region) {
        if (length(col.ellips) != n) {
          col.ellips = rep(col.ellips, n)
        }
        if (object$method == "LA") {
          for (i in 1:n) {
            covm <- (t(B) %*% object$prediction.errors$lvs[i,
                                                           , ] %*% B)[which.lvs, which.lvs]
            ellipse(choose.lvs[i, which.lvs], covM = covm,
                    rad = sqrt(qchisq(level, df = object$num.lv)),
                    col = col.ellips[i], lwd = lwd.ellips,
                    lty = lty.ellips)
          }
        }
        else {
          sdb <- sdA(object)
          object$A <- sdb + object$A
          r = 0
          if (object$row.eff == "random")
            r = 1
          for (i in 1:n) {
            if (!object$TMB && object$Lambda.struc ==
                "diagonal") {
              covm <- (t(B) %*% diag(object$A[i, 1:num.lv +
                                                r]) %*% B)[which.lvs, which.lvs]
            }
            else {
              covm <- (t(B) %*% object$A[i, 1:num.lv +
                                           r, 1:num.lv + r] %*% B)[which.lvs, which.lvs]
            }
            ellipse(choose.lvs[i, which.lvs], covM = covm,
                    rad = sqrt(qchisq(level, df = object$num.lv)),
                    col = col.ellips[i], lwd = lwd.ellips,
                    lty = lty.ellips)
          }
        }
      }
      if (!jitter)
        if (symbols) {
          points(choose.lvs[, which.lvs], col = s.colors,
                 ...)
        }
      else {
        text(choose.lvs[, which.lvs], label = 1:n,
             cex = 1.2, col = s.colors)
      }
      if (jitter)
        if (symbols) {
          points(choose.lvs[, which.lvs][, 1] + runif(n,
                                                      -a, a), choose.lvs[, which.lvs][, 2] + runif(n,
                                                                                                   -a, a), col = s.colors, ...)
        }
      else {
        text((choose.lvs[, which.lvs][, 1] + runif(n,
                                                   -a, a)), (choose.lvs[, which.lvs][, 2] +
                                                               runif(n, -a, a)), label = 1:n, cex = 1.2,
             col = s.colors)
      }
    }
    if (biplot) {
      largest.lnorms <- order(apply(object$params$theta^2,
                                    1, sum), decreasing = TRUE)[1:ind.spp]
      plot(rbind(choose.lvs[, which.lvs], choose.lv.coefs[,
                                                          which.lvs]), xlab = paste("Latent variable ",
                                                                                    which.lvs[1]), ylab = paste("Latent variable ",
                                                                                                                which.lvs[2]), main = main, type = "n",
           ...)
      if (predict.region) {
        if (length(col.ellips) != n) {
          col.ellips = rep(col.ellips, n)
        }
        if (object$method == "LA") {
          for (i in 1:n) {
            covm <- (t(B) %*% object$prediction.errors$lvs[i,
                                                           , ] %*% B)[which.lvs, which.lvs]
            ellipse(choose.lvs[i, which.lvs], covM = covm,
                    rad = sqrt(qchisq(level, df = object$num.lv)),
                    col = col.ellips[i], lwd = lwd.ellips,
                    lty = lty.ellips)
          }
        }
        else {
          sdb <- sdA(object)
          object$A <- sdb + object$A
          r = 0
          if (object$row.eff == "random")
            r = 1
          for (i in 1:n) {
            if (!object$TMB && object$Lambda.struc ==
                "diagonal") {
              covm <- (t(B) %*% diag(object$A[i, 1:num.lv +
                                                r]) %*% B)[which.lvs, which.lvs]
            }
            else {
              covm <- (t(B) %*% object$A[i, 1:num.lv +
                                           r, 1:num.lv + r] %*% B)[which.lvs, which.lvs]
            }
            ellipse(choose.lvs[i, which.lvs], covM = covm,
                    rad = sqrt(qchisq(level, df = object$num.lv)),
                    col = col.ellips[i], lwd = lwd.ellips,
                    lty = lty.ellips)
          }
        }
      }
      if (!jitter) {
        if (symbols) {
          points(choose.lvs[, which.lvs], col = s.colors,
                 ...)
        }
        else {
          text(choose.lvs[, which.lvs], label = 1:n,
               cex = 1.2, col = s.colors)
        }
        spp.colors <- spp.colors[largest.lnorms][1:ind.spp]
        text(matrix(choose.lv.coefs[largest.lnorms, which.lvs],
                    nrow = length(largest.lnorms)), label = rownames(object$params$theta)[largest.lnorms],
             col = spp.colors, cex = cex.spp)
      }
      if (jitter) {
        if (symbols) {
          points(choose.lvs[, which.lvs[1]] + runif(n,
                                                    -a, a), (choose.lvs[, which.lvs[2]] + runif(n,
                                                                                                -a, a)), col = s.colors, ...)
        }
        else {
          text((choose.lvs[, which.lvs[1]] + runif(n,
                                                   -a, a)), (choose.lvs[, which.lvs[2]] + runif(n,
                                                                                                -a, a)), label = 1:n, cex = 1.2, col = s.colors)
        }
        spp.colors <- spp.colors[largest.lnorms][1:ind.spp]
        text((matrix(choose.lv.coefs[largest.lnorms,
                                     which.lvs], nrow = length(largest.lnorms)) +
                runif(2 * length(largest.lnorms), -a, a)),
             label = rownames(object$params$theta)[largest.lnorms],
             col = spp.colors, cex = cex.spp)
      }
    }
  }
}

