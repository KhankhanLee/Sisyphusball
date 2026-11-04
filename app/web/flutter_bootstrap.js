{{flutter_js}}
{{flutter_build_config}}

// Rendering can be switched from the URL, to find what works inside WebViews
// we cannot inspect (the Pi Browser):
//   ?renderer=skwasm | canvaskit    which engine to use
//   ?ck=full | chromium             CanvasKit variant
//   ?cpu=1                          CanvasKit without the GPU (software)
(function () {
  var params = new URLSearchParams(window.location.search);
  var config = {};
  var renderer = params.get('renderer');
  if (renderer === 'skwasm' || renderer === 'canvaskit') config.renderer = renderer;
  var variant = params.get('ck');
  if (variant === 'full' || variant === 'chromium') config.canvasKitVariant = variant;
  if (params.get('cpu') === '1') config.canvasKitForceCpuOnly = true;

  if (window.sisyphusReport) window.sisyphusReport('engine', JSON.stringify(config));
  _flutter.loader.load({ config: config });
})();
