{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    var loadingEl = document.getElementById('flutter-loading-screen');
    if (loadingEl) loadingEl.remove();
  }
});
