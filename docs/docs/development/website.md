---
layout: docs
title: Website Architecture
permalink: /docs/development/website/
---

This document explains the Clayground documentation website architecture, build pipeline, and how to make changes.

## Build Pipeline

The documentation site is built through a multi-stage pipeline:

```
QDoc → Python Scripts → Jekyll → Pagefind
```

### Stage 1: QDoc API Generation

QDoc parses QML source files with documentation comments and generates:
- `clayground.index` - XML index of all documented types
- `qml-*.html` - Individual type reference pages

Run with: `cmake --build build --target docs`

### Stage 2: Post-processing Scripts

After QDoc completes, two scripts run:

1. **convert-readmes.sh** - Converts plugin README.md files to HTML for the API browser
2. **generate_api_includes.py** - Parses `clayground.index` and generates Jekyll includes

The Python script creates `_includes/api/<plugin>.html` files that embed API reference directly into plugin documentation pages.

### Stage 3: Jekyll Build

Jekyll processes the Markdown content with:
- Custom layouts (`_layouts/docs.html`)
- Includes (`_includes/api/*.html`, `_includes/docs_sidebar.html`)
- Navigation data (`_data/docs_nav.yml`)
- SCSS styling (`assets/main.scss`)

### Stage 4: Pagefind Indexing

Pagefind creates the search index for the site. Configuration is in `pagefind.yml`.

## Directory Structure

```
docs/
├── _config.yml           # Jekyll configuration
├── _data/
│   └── docs_nav.yml      # Documentation navigation structure
├── _includes/
│   ├── api/              # Generated API reference includes
│   ├── docs_sidebar.html # Documentation sidebar
│   └── header.html       # Site header
├── _layouts/
│   └── docs.html         # Documentation page layout
├── api/                  # QDoc-generated API reference
│   ├── clayground.index  # XML index (source for includes)
│   ├── index.html        # API browser entry point
│   └── qml-*.html        # Individual type pages
├── assets/
│   ├── main.scss         # Styles including API reference
│   └── images/           # Site images
├── docs/                 # Documentation content (Markdown)
│   ├── getting-started/
│   ├── manual/
│   ├── plugins/          # Plugin documentation
│   └── development/      # Developer documentation
├── scripts/
│   ├── generate_api_includes.py  # API include generator
│   ├── serve.sh          # Jekyll dev server launcher
│   └── serve_dev.py      # Local development server
└── pagefind.yml          # Search configuration
```

## API Reference Integration

Plugin documentation pages include embedded API reference through Jekyll includes:

```markdown
## API Reference

{% raw %}{% include api/world.html %}{% endraw %}
```

The `generate_api_includes.py` script parses `clayground.index` and generates HTML with:
- Collapsible `<details>` elements for each QML type
- Tables for properties, methods, and signals
- Links to full API documentation pages
- Badges for required/readonly properties

### Module Mapping

The script maps QDoc module names to plugin identifiers:

```python
MODULE_TO_PLUGIN = {
    "Clayground.Common": "common",
    "Clayground.Canvas": "canvas",
    "Clayground.World": "world",
    # ...
}
```

## Local Development

Always use `serve_dev.py` for local development:

```bash
cd docs && python3 scripts/serve_dev.py
```

This server provides:
- COOP/COEP headers for SharedArrayBuffer (required for WASM threading)
- Cache-Control headers to disable caching during development
- Overlay of `docs/` directory for live edits

**Never use plain `python3 -m http.server`** - it lacks the required headers for WASM demos.

### Rebuilding Documentation

After changing QML documentation comments:

```bash
cmake --build build --target docs
```

This regenerates:
1. QDoc output in `docs/api/`
2. API includes in `docs/_includes/api/`

Jekyll will automatically pick up changes on next page load.

## Adding a New Plugin

1. Create plugin documentation at `docs/docs/plugins/<name>.md`
2. Add module mapping in `generate_api_includes.py`
3. Add navigation entry in `_data/docs_nav.yml`
4. Add `{% raw %}{% include api/<name>.html %}{% endraw %}` at bottom of plugin page
5. Rebuild docs: `cmake --build build --target docs`

## GitHub Pages Deployment

The site deploys automatically via GitHub Actions when changes are pushed to main. The workflow:

1. Builds the Jekyll site
2. Runs Pagefind to create search index
3. Deploys to GitHub Pages

The site is served from the custom domain `clayground.mistergc.dev`.

## Styling

All styles are in `assets/main.scss` using CSS custom properties for theming:

```scss
:root {
  --bg-dark: #0D1117;
  --accent-primary: #00D9FF;
  --accent-secondary: #FF3366;
  --accent-highlight: #FFD93D;
  // ...
}
```

The API reference styles are at the bottom of the file under the "API Reference Embedded in Plugin Pages" section.
