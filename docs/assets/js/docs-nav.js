/**
 * Docs navigation JS - handles sidebar, search, SPA content loading
 */
(function() {
  var initialized = false;

  function initDocsSidebar() {
    if (initialized) return;
    initialized = true;

    var sidebar = document.getElementById('docs-sidebar');
    var toggle = document.getElementById('sidebar-toggle');

    if (toggle && sidebar) {
      toggle.addEventListener('click', function() {
        sidebar.classList.toggle('open');
        toggle.classList.toggle('active');
      });

      document.addEventListener('click', function(e) {
        if (window.innerWidth <= 768 &&
            !sidebar.contains(e.target) &&
            !toggle.contains(e.target) &&
            sidebar.classList.contains('open')) {
          sidebar.classList.remove('open');
          toggle.classList.remove('active');
        }
      });
    }

    // Initialize Pagefind search (with retry for async loading)
    function initPagefindSearch() {
      if (typeof PagefindModularUI === 'undefined') return false;

      var baseurlMeta = document.querySelector('meta[name="baseurl"]');
      var baseurl = baseurlMeta ? baseurlMeta.getAttribute('content') : '';
      var searchInstance = new PagefindModularUI.Instance({
        bundlePath: baseurl + "/_pagefind/",
        showSubResults: true,
        showImages: false
      });

      searchInstance.add(new PagefindModularUI.Input({
        containerElement: "#search"
      }));

      searchInstance.add(new PagefindModularUI.ResultList({
        containerElement: "#search-results"
      }));

      var style = document.createElement('style');
      style.textContent = '.pagefind-modular-list-thumb { display: none !important; }';
      document.head.appendChild(style);

      var results = document.getElementById("search-results");
      var article = document.getElementById("docs-article");
      var searchHeader = document.getElementById("search-results-header");

      function updateSearchUI(searchInput) {
        var term = searchInput ? searchInput.value : '';
        if (term && term.length > 0) {
          results.style.display = "block";
          if (searchHeader) searchHeader.style.display = "block";
          article.style.display = "none";
          // Update URL with search query
          var searchUrl = '/docs/?q=' + encodeURIComponent(term);
          if (window.location.pathname + window.location.search !== searchUrl) {
            history.pushState({ isSearch: true, searchTerm: term }, '', searchUrl);
          }
        } else {
          results.style.display = "none";
          if (searchHeader) searchHeader.style.display = "none";
          article.style.display = "block";
        }
      }

      function setupSearchListener() {
        var searchInput = document.querySelector('.pagefind-modular-input');
        if (searchInput) {
          searchInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
              updateSearchUI(searchInput);
            }
          });
          searchInput.addEventListener('input', function() {
            if (!searchInput.value || searchInput.value.length === 0) {
              updateSearchUI(null);
            }
          });
        } else {
          setTimeout(setupSearchListener, 50);
        }
      }
      setupSearchListener();

      // Restore search from URL on page load
      function restoreSearchFromUrl() {
        var params = new URLSearchParams(window.location.search);
        var query = params.get('q');
        if (query) {
          var searchInput = document.querySelector('.pagefind-modular-input');
          if (searchInput) {
            searchInput.value = query;
            searchInput.dispatchEvent(new Event('input', { bubbles: true }));
            results.style.display = 'block';
            if (searchHeader) searchHeader.style.display = 'block';
            article.style.display = 'none';
          }
        }
      }
      // Delay slightly to let Pagefind render the input
      setTimeout(restoreSearchFromUrl, 100);

      var countObserver = new MutationObserver(function() {
        var countEl = document.getElementById('search-results-count');
        var resultItems = results.querySelectorAll('.pagefind-modular-list-link');
        if (countEl && resultItems.length > 0) {
          countEl.textContent = 'Found ' + resultItems.length + ' pages matching the search query.';
        }
      });
      countObserver.observe(results, { childList: true, subtree: true });

      return true;
    }

    // Try immediately, then retry up to 1 second
    if (!initPagefindSearch()) {
      var retries = 0;
      var retryInterval = setInterval(function() {
        if (initPagefindSearch() || ++retries >= 20) {
          clearInterval(retryInterval);
        }
      }, 50);
    }

    // ==========================================================================
    // SPA-style navigation for sidebar links, API links, and search results
    // ==========================================================================

    var article = document.getElementById('docs-article');
    var results = document.getElementById('search-results');
    var searchHeader = document.getElementById('search-results-header');

    function loadContentFromUrl(url, source, skipPush) {
      fetch(url)
        .then(function(res) { return res.text(); })
        .then(function(html) {
          var parser = new DOMParser();
          var doc = parser.parseFromString(html, 'text/html');

          var content;
          if (source === 'api') {
            content = doc.querySelector('body').innerHTML;
          } else {
            var docArticle = doc.querySelector('.docs-article');
            content = docArticle ? docArticle.innerHTML : doc.querySelector('body').innerHTML;
          }

          article.innerHTML = content;
          article.style.display = 'block';

          results.style.display = 'none';
          if (searchHeader) searchHeader.style.display = 'none';

          article.scrollIntoView({ behavior: 'instant' });

          if (!skipPush) {
            history.pushState({ url: url, source: source }, '', url);
          }

          // After loading API content, intercept internal links and transform breadcrumbs
          if (source === 'api' || source === 'search') {
            interceptArticleLinks();
            transformBreadcrumbs();
          }
        })
        .catch(function(err) {
          console.error('Failed to load content:', err);
          window.location.href = url;
        });
    }

    // Intercept links within API article content that point to other API pages
    function interceptArticleLinks() {
      article.querySelectorAll('a[href]').forEach(function(link) {
        var href = link.getAttribute('href');
        if (href && !link.dataset.intercepted) {
          // Handle anchor links - scroll within current content
          if (href.startsWith('#')) {
            link.dataset.intercepted = 'true';
            link.addEventListener('click', function(e) {
              e.preventDefault();
              var target = article.querySelector(href);
              if (target) {
                target.scrollIntoView({ behavior: 'smooth' });
              }
            });
          }
          // Match API page links (relative like qml-*.html, clayground-*.html, or absolute /api/*.html)
          else if (href.match(/^qml-.*\.html/) || href.match(/^clayground-.*\.html/) ||
                   (href.includes('/api/') && href.endsWith('.html'))) {
            link.dataset.intercepted = 'true';
            link.addEventListener('click', function(e) {
              e.preventDefault();
              var fullHref = href.startsWith('/') ? href : '/api/' + href;
              loadContentFromUrl(fullHref, 'api');
            });
          }
        }
      });
    }

    // Transform QDoc's raw breadcrumb <li> elements into Qt-style breadcrumb
    function transformBreadcrumbs() {
      // Find the raw <li> elements QDoc generates (direct children of article that are <li>)
      var headerNav = article.querySelector('.header-nav');
      if (!headerNav) return;

      // Collect breadcrumb items (siblings of header-nav that are <li>)
      var breadcrumbItems = [];
      var sibling = headerNav.nextElementSibling;
      while (sibling && sibling.tagName === 'LI') {
        var next = sibling.nextElementSibling;
        breadcrumbItems.push(sibling);
        sibling = next;
      }

      if (breadcrumbItems.length === 0) return;

      // Build Qt-style breadcrumb: "Clayground 2025.2 > Module > Type"
      var nav = document.createElement('nav');
      nav.className = 'api-breadcrumb';

      // Find version and module from collected items
      var version = '';
      var module = null;
      var typeName = '';

      breadcrumbItems.forEach(function(li) {
        var text = li.textContent.trim();
        var link = li.querySelector('a');

        if (li.id === 'buildversion' && link) {
          // Extract version: "Clayground 2025.2" -> "2025.2"
          version = text.replace('Clayground ', '');
        } else if (link && link.href.includes('-qmlmodule.html')) {
          module = { text: text, href: link.getAttribute('href') };
        } else if (!link && text !== 'index.html') {
          typeName = text;
        }
      });

      // Build breadcrumb HTML
      var parts = [];
      parts.push('<span class="bc-version">Clayground ' + version + '</span>');
      if (module) {
        parts.push('<span class="bc-sep">›</span>');
        parts.push('<a href="' + module.href + '" class="bc-module">' + module.text + '</a>');
      }
      if (typeName) {
        parts.push('<span class="bc-sep">›</span>');
        parts.push('<span class="bc-current">' + typeName + '</span>');
      }

      nav.innerHTML = parts.join('');

      // Intercept module link for SPA
      var moduleLink = nav.querySelector('.bc-module');
      if (moduleLink) {
        moduleLink.addEventListener('click', function(e) {
          e.preventDefault();
          loadContentFromUrl('/api/' + moduleLink.getAttribute('href'), 'api');
        });
      }

      // Remove old <li> elements and insert new breadcrumb
      breadcrumbItems.forEach(function(li) { li.remove(); });
      headerNav.insertAdjacentElement('afterend', nav);
    }

    // Use event delegation for ALL sidebar nav links
    sidebar.addEventListener('click', function(e) {
      // Handle API type links (.nav-api-types a)
      var apiLink = e.target.closest('.nav-api-types a');
      if (apiLink) {
        e.preventDefault();
        loadContentFromUrl(apiLink.getAttribute('href'), 'api');
        return;
      }

      // Handle section title links (.nav-section-title) for API section
      var sectionTitle = e.target.closest('.nav-section-title');
      if (sectionTitle) {
        var href = sectionTitle.getAttribute('href');
        if (href && href.includes('/api')) {
          e.preventDefault();
          loadContentFromUrl(href, 'api');
          return;
        }
      }

      // Handle plugin links (nav-item-header a) for docs pages
      var pluginLink = e.target.closest('.nav-item-header a');
      if (pluginLink) {
        var href = pluginLink.getAttribute('href');
        // Only intercept docs/plugins links, not external
        if (href && (href.includes('/docs/') || href.includes('/plugins/'))) {
          e.preventDefault();
          loadContentFromUrl(href, 'docs');
          return;
        }
      }
    });

    // Intercept search result clicks using MutationObserver
    var resultsObserver = new MutationObserver(function() {
      results.querySelectorAll('a').forEach(function(link) {
        if (!link.dataset.intercepted) {
          link.dataset.intercepted = 'true';
          link.addEventListener('click', function(e) {
            e.preventDefault();
            var href = this.getAttribute('href');
            loadContentFromUrl(href, 'search');
          });
        }
      });
    });
    resultsObserver.observe(results, { childList: true, subtree: true });

    // Handle browser back/forward navigation
    window.addEventListener('popstate', function(e) {
      // Check URL for search query
      var params = new URLSearchParams(window.location.search);
      var query = params.get('q');
      if (query) {
        // Restore search results view
        var searchInput = document.querySelector('.pagefind-modular-input');
        if (searchInput) {
          searchInput.value = query;
          searchInput.dispatchEvent(new Event('input', { bubbles: true }));
          results.style.display = 'block';
          if (searchHeader) searchHeader.style.display = 'block';
          article.style.display = 'none';
        }
      } else if (e.state && e.state.url) {
        loadContentFromUrl(e.state.url, e.state.source, true);
      } else {
        location.reload();
      }
    });

    // ==========================================================================
    // Expand/collapse logic for plugin types (accordion behavior)
    // ==========================================================================

    function collapseAll() {
      document.querySelectorAll('.nav-api-types.expanded').forEach(function(list) {
        list.classList.remove('expanded');
        var icon = list.parentElement.querySelector('.toggle-icon');
        if (icon) icon.textContent = '\u25B6';
        localStorage.setItem('nav-' + list.dataset.plugin, 'false');
      });
    }

    function expandPlugin(plugin) {
      var typesList = document.querySelector('.nav-api-types[data-plugin="' + plugin + '"]');
      var btn = document.querySelector('.nav-toggle[data-plugin="' + plugin + '"]');
      if (typesList && btn) {
        typesList.classList.add('expanded');
        var icon = btn.querySelector('.toggle-icon');
        if (icon) icon.textContent = '\u25BC';
        localStorage.setItem('nav-' + plugin, 'true');
      }
    }

    collapseAll();
    var currentExpanded = null;
    document.querySelectorAll('.nav-toggle').forEach(function(btn) {
      var currentLink = btn.parentElement.querySelector('a.current');
      if (currentLink) {
        currentExpanded = btn.dataset.plugin;
      }
    });
    if (currentExpanded) {
      expandPlugin(currentExpanded);
    }

    // Event delegation for toggle clicks
    sidebar.addEventListener('click', function(e) {
      var btn = e.target.closest('.nav-toggle');
      if (!btn) return;

      e.preventDefault();
      e.stopPropagation();

      var plugin = btn.dataset.plugin;
      var typesList = document.querySelector('.nav-api-types[data-plugin="' + plugin + '"]');

      if (!typesList) return;

      var isCurrentlyExpanded = typesList.classList.contains('expanded');

      collapseAll();

      if (!isCurrentlyExpanded) {
        expandPlugin(plugin);
      }
    });
  }

  // Initialize on DOMContentLoaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initDocsSidebar);
  } else {
    initDocsSidebar();
  }
})();
