// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Bootstrap loader for versioned WebDojo WASM
// Parses clay-version from URL hash and dynamically loads the matching
// webdojo.js + qtloader.js from the correct path on GitHub Pages.
//
(function() {
    var baseUrl = (document.querySelector('meta[name="baseurl"]') || {}).content || '';
    var fallbackBase = baseUrl + '/demo/webdojo/';

    function parseVersion() {
        var hash = window.location.hash.slice(1);
        if (!hash) return null;
        var parts = hash.split('&');
        for (var i = 0; i < parts.length; i++) {
            var eq = parts[i].indexOf('=');
            if (eq !== -1 && parts[i].slice(0, eq) === 'clay-version') {
                return decodeURIComponent(parts[i].slice(eq + 1));
            }
        }
        return null;
    }

    function taggedBase(tag) {
        return baseUrl + '/v/' + tag + '/webdojo/';
    }

    function loadScript(src) {
        return new Promise(function(resolve, reject) {
            var s = document.createElement('script');
            s.src = src;
            s.onload = resolve;
            s.onerror = function() { reject(new Error('Failed to load: ' + src)); };
            document.head.appendChild(s);
        });
    }

    function loadFrom(base) {
        window.__wasmBasePath = base;
        return loadScript(base + 'webdojo.js')
            .then(function() { return loadScript(base + 'qtloader.js'); })
            .then(function() {
                window.__wasmScriptsReady = true;
                window.dispatchEvent(new Event('wasm-scripts-ready'));
            });
    }

    function loadWithFallback(primary) {
        return loadFrom(primary).catch(function(err) {
            console.warn('[webdojo-loader] ' + err.message + ', falling back to dev');
            if (primary !== fallbackBase) {
                return loadFrom(fallbackBase);
            }
        });
    }

    // Resolve the WASM base path for the requested version
    function resolveAndLoad(version) {
        if (!version || version === 'dev') {
            return loadFrom(fallbackBase);
        }

        if (version === 'latest') {
            // Fetch versions manifest to resolve latest tag
            return fetch(baseUrl + '/v/versions.json')
                .then(function(r) { return r.ok ? r.json() : Promise.reject(); })
                .then(function(data) {
                    if (data.latest) {
                        return loadWithFallback(taggedBase(data.latest));
                    }
                    return loadFrom(fallbackBase);
                })
                .catch(function() {
                    console.warn('[webdojo-loader] Could not resolve latest, using dev');
                    return loadFrom(fallbackBase);
                });
        }

        // Specific version tag
        var tag = version.charAt(0) === 'v' ? version : 'v' + version;
        return loadWithFallback(taggedBase(tag));
    }

    resolveAndLoad(parseVersion() || 'latest');
})();
