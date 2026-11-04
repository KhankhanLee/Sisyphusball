{{flutter_js}}
{{flutter_build_config}}

// Which rendering engine to use. The Pi Browser drops query strings, so the
// server can set it too (FLUTTER_ENGINE in its .env, served at /api/engine).
// URL parameters, where they reach the page, take precedence:
//   ?renderer=skwasm | canvaskit    which engine to use
//   ?ck=full | chromium             CanvasKit variant
//   ?cpu=1                          CanvasKit without the GPU (software)
(function () {
  function fromUrl() {
    var params = new URLSearchParams(window.location.search);
    var config = {};
    var renderer = params.get('renderer');
    if (renderer === 'skwasm' || renderer === 'canvaskit') config.renderer = renderer;
    var variant = params.get('ck');
    if (variant === 'full' || variant === 'chromium') config.canvasKitVariant = variant;
    if (params.get('cpu') === '1') config.canvasKitForceCpuOnly = true;
    return config;
  }

  function start(config, source) {
    if (window.sisyphusReport) window.sisyphusReport('engine', source + ' ' + JSON.stringify(config));
    _flutter.loader.load({ config: config });
  }

  var config = fromUrl();
  if (Object.keys(config).length) return start(config, 'url');
  fetch('api/engine', { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : {}; })
    .catch(function () { return {}; })
    .then(function (server) { start(server || {}, 'server'); });
})();
