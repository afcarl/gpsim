function model = gpsimCreate(numGenes, numProteins, times, geneVals, ...
                             geneVars, options)

% GPSIMCREATE Create a GPSIM model.
% The GPSIM model is a model for estimating the protein
% concentration in a small gene network where several genes are
% governed by one protein. The model is based on Gaussian processes
% and simple linear differential equations of the form
%
% dx(t)/dt = B + Cf(t) - Dx(t)
%
% where x(t) is a given genes concentration and f(t) is the protein
% concentration. 
%
% FORMAT
% DESC creates a model for single input motifs with Gaussian
% processes.
% ARG numGenes : number of genes to be modelled in the system.
% ARG numProteins : number of proteins to be modelled in the
% system.
% ARG times : the time points where the data is to be modelled.
% ARG geneVals : the values of each gene at the different time points.
% ARG geneVars : the varuabces of each gene at the different time points.
% ARG options : options structure, the default options can be
% generated using gpsimOptions.
% RETURN model : model structure containing default
% parameterisation.
%
% SEEALSO : modelCreate, gpsimOptions
%
% COPYRIGHT : Neil D. Lawrence, 2006

% GPSIM

if any(size(geneVars)~=size(geneVals))
  error('The gene variances have a different size matrix to the gene values.');
end

if(numGenes ~= size(geneVals, 2))
  error('The number of genes given does not match the dimension of the gene values given.')
end

if(size(times, 1) ~= size(geneVals, 1))
  error('The number of time points given does not match the number of gene values given')
end

model.type = 'gpsim';

kernType1{1} = 'multi';
kernType2{1} = 'multi';
tieParam = [2]; % These are the indices of the inverse widths which
                % need to be constrained to be equal.
for i = 1:numGenes
  kernType1{i+1} = 'sim';
  if i>1
    tieParam = [tieParam tieParam(end)+3];
  end
end

model.y = geneVals(:);
model.yvar = geneVars(:);
model.kern = kernCreate(times, kernType1);
%/~ This is if we need to place priors on parameters ...
% for i = 1:length(model.kern.numBlocks)
%   % Priors on the sim kernels.
%   model.kern.comp{i}.priors = priorCreate('gamma');
%   model.kern.comp{i}.priors.a = 1;
%   model.kern.comp{i}.priors.b = 1;
%   if i == 1
%     % For first kernel place prior on inverse width.
%     model.kern.comp{i}.priors.index = [1 2 3];
%   else
%     % For other kernels don't place prior on inverse width --- as
%     % they are all tied together and it will be counted multiple
%     % times.
%     model.kern.comp{i}.priors.index = [1 3];
%   end
% end

% Prior on the b values.
% model.bprior = priorCreate('gamma');
% model.bprior.a = 1;
% model.bprior.b = 1;
%~/
model.kern = modelTieParam(model.kern, {tieParam});

% The decays and sensitivities are actually stored in the kernel.
% We'll put them here as well for convenience.
for i = 1:model.kern.numBlocks
  model.D(i) = model.kern.comp{i}.decay;
  model.S(i) = sqrt(model.kern.comp{i}.variance);
end

model.numParams = numGenes + model.kern.nParams;
model.numGenes = numGenes;
model.mu = mean(geneVals);
model.B = model.D.*model.mu;
model.m = model.y;
model.t = times;

model.optimiser = options.optimiser;

if isfield(options, 'fix')
  model.fix = options.fix;
end

% The basal transcriptions rates must be postitive.
model.bTransform = 'negLogLogit';

% This forces kernel compute.
params = gpsimExtractParam(model);
model = gpsimExpandParam(model, params);
