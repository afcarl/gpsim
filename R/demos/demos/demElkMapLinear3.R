library(gpsim)

options(error = recover)

expType <- "demElkMapLinear"
expNo <- 3

trainingData <- gpsimLoadElkData(3)
y <- trainingData$y
yvar <- trainingData$yvar
genes <- trainingData$genes
times <- trainingData$times
scale <- trainingData$scale
rm(trainingData)

Nrep <- length(y)
Ngenes <- length(genes)
Ntf <- 1

options <- list(includeNoise=1, optimiser="CG")
options$proteinPrior <- list(values=array(0), times=array(0))
options$kern <- "mlp"
options$nonLinearity <- "linear"
options$startPoint <- 0
options$endPoint <- 8
options$times <- times
options$intPoints <- (options$endPoint-options$startPoint)/0.1+1

options$fix$index <- c(3)
options$fix$value <- expTransform(c(1), "xtoa")

model <- list(type="cgpsimMap")
for ( i in seq(length=Nrep) ) {
  options$S <- array(1, Ngenes)
  set.seed(1)
  options$D <- runif(Ngenes)
  mu <- apply(y[[i]], 2, mean)
  options$B <- options$D*mu

#  display <- TRUE
#  sopt <- TRUE
#  options <- gpsimMapInitParam(y[[i]], yvar[[i]], options, display, sopt)
  repNames <- names(model$comp)
  model$comp[[i]] <- gpsimMapCreate(Ngenes, Ntf, times, y[[i]], yvar[[i]], options)
  names(model$comp) <- c(repNames, paste("rep", i, sep=""))
  if ( options$kern == "mlp" ) {
    model$comp[[i]]$kern$weightVariance <- 30
    model$comp[[i]]$kern$biasVariance <- 20
    params <- gpsimMapExtractParam(model$comp[[i]])
    model$comp[[i]] <- gpsimMapExpandParam(model$comp[[i]], params)
  }
}

param <- 0
Nrep <- length(model$comp)
paramvec <- list()

for ( i in seq(length=Nrep) ) {
  paramvec <- gpsimMapExtractParam(model$comp[[i]], 2)
  paramVals <- paramvec$values
  param <- param+paramVals
}

param <- param/Nrep

optOptions <- optimiDefaultOptions()
optOptions$maxit <- 300
optOptions$optimiser <- "SCG"

optimResult <- SCGoptim(param, fn=gpsimMapObjective, grad=gpsimMapGradients, optOptions, model)

for ( i in seq(length=Nrep) ) {
  optimiFoptions <- optimiFdefaultOptions()
  model$comp[[i]] <- gpsimMapExpandParam(model$comp[[i]], optimResult$xmin)
  model$comp[[i]] <- gpsimMapUpdateF(model$comp[[i]], optimiFoptions)
  model$comp[[i]] <- gpsimMapUpdateYpredVar(model$comp[[i]])
}

fileName <- paste(expType, expNo, ".Rdata", sep="")
save(model, expType, expNo, genes, scale, file=fileName)

displayOption <- 1
gpsimMapElkResults(model, expType, expNo, genes, scale, displayOption)



