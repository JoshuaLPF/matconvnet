function deeplab_demo(varargin)
%DEEPLAB_DEMO Minimalistic demonstration of a pretrained deeplab model
%   DEEPLAB_DEMO a semantic segmentation demo with a deeplab model
%
%   DEEPLAB_DEMO(..., 'option', value, ...) accepts the following
%   options:
%
%   `modelPath`:: ''
%    Path to a valid deeplab matconvnet model. If none is provided, a model
%    will be downloaded.
%
%   `gpus`:: []
%    Device on which to run network 
%
%   `wrapper` :: dagnn
%    The matconvnet wrapper to be used (both dagnn and autonn are supported) 
%
% Copyright (C) 2017 Samuel Albanie
% Licensed under The MIT License [see LICENSE.md for details]

  opts.modelPath = '' ;
  opts.wrapper = 'dagnn' ;
  opts = vl_argparse(opts, varargin) ;

  % Load or download an example faster-rcnn model:
  modelName = 'deeplab-res101-v2.mat' ; % slower, mutliscale model
  paths = {opts.modelPath, ...
           modelName, ...
           fullfile(vl_rootnn, 'data', 'models-import', modelName)} ;
  ok = find(cellfun(@(x) exist(x, 'file'), paths), 1) ;

  if isempty(ok)
    fprintf('Downloading the DeepLab model ... this may take a while\n') ;
    opts.modelPath = fullfile(vl_rootnn, 'data/models-import', modelName) ;
    mkdir(fileparts(opts.modelPath)) ; base = 'http://www.robots.ox.ac.uk' ;
    url = sprintf('%s/~albanie/models/deeplab/%s', base, modelName) ;
    urlwrite(url, opts.modelPath) ;
  else
    opts.modelPath = paths{ok} ;
  end

  % Load the network with the chosen wrapper
  net = loadModel(opts) ;

  % Load test image
  imPath = fullfile(vl_rootnn, 'contrib/mcnDeepLab/misc/000022.jpg') ;
  origIm = single(imread(imPath)) ;

  % choose variables to track
  predIdx = net.getVarIndex(net.meta.predVar) ;

  % resize to ensure multilpe of 32 and subtract mean
  meanIm = reshape(net.meta.normalization.averageImage, [1 1 3]) ;
  im = bsxfun(@minus, origIm, meanIm) ;
  sz = [size(im,1), size(im,2)] ; 
  sz_ = round(sz / 32)*32 ;
  im = imresize(im, sz_) ;

  % set inputs
  sample = {'data', im} ;
  switch opts.wrapper
    case 'dagnn', inputs = {sample} ; net.mode = 'test' ;
    case 'autonn', inputs = {sample, 'test'} ;
  end

  % run network and retrieve results
  net.eval(inputs{:}) ;
  switch opts.wrapper
    case 'dagnn', preds = squeeze(net.vars(predIdx).value) ;
    case 'autonn', preds = squeeze(net.vars{predIdx}) ;
  end

  % visualise predictions
  [~,labels] = max(preds, [], 3) ;
  figure('pos',[0 0 900 500])
  subplot(1,2,1) ; imagesc(origIm/ 255) ;
  title('original image') ;
  axis off ;
  subplot(1,2,2) ; cmap = VOClabelcolormap ; colormap(cmap) ; 
  imagesc(labels) ; 
  axis off ;
  title('predicted segmentation') ;
  if exist('zs_dispFig', 'file'), zs_dispFig ; end

% ----------------------------
function net = loadModel(opts)
% ----------------------------
  net = load(opts.modelPath) ; net = dagnn.DagNN.loadobj(net) ;
  switch opts.wrapper
    case 'dagnn' 
      net.mode = 'test' ; 
    case 'autonn'
      out = Layer.fromDagNN(net, @extras_autonn_custom_fn) ; net = Net(out{:}) ;
  end
