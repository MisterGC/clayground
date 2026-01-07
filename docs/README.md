# Clayground Documentation Site

This folder contains the Jekyll-based documentation site for Clayground, designed to be hosted on GitHub Pages.

## Local Development

### Prerequisites

1. Install Ruby via Homebrew (macOS):
   ```bash
   brew install ruby
   ```

2. Add Ruby to your PATH (add to ~/.zshrc or ~/.bash_profile):
   ```bash
   export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
   ```

3. Qt 6.x with QDoc (for API documentation):
   ```bash
   # QDoc is included with Qt desktop installation
   # Verify: ~/Qt/6.x.x/macos/bin/qdoc --version
   ```

### Running Locally (Jekyll Only)

For quick iteration on Jekyll content (without API docs rebuild):

1. Install dependencies:
   ```bash
   cd docs
   bundle install
   ```

2. Run the development server:
   ```bash
   ./serve.sh
   ```

   Or manually:
   ```bash
   export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
   bundle exec jekyll serve --baseurl /clayground
   ```

3. Visit http://localhost:4000/clayground/

### Building Complete Website (with API Docs)

For full website including API documentation:

1. Build API documentation:
   ```bash
   # From project root (requires desktop Qt)
   cmake -B build
   cmake --build build --target docs
   ```

2. Build Jekyll site + copy API docs:
   ```bash
   cd docs
   ./sync-plugin-docs.sh
   bundle exec jekyll build
   cp -r api _site/
   ```

3. Serve locally:
   ```bash
   cd _site && python3 -m http.server 8000
   # Visit http://localhost:8000/
   ```

### Full Website Build (WASM + API + Jekyll)

For complete production-like build with WASM demos:

```bash
# Configure with WASM Qt
~/Qt/6.x.x/wasm_multithread/bin/qt-cmake -B build -DCLAY_BUILD_WEBSITE=ON .

# Build everything (requires desktop Qt for QDoc)
cmake --build build --target website-dev

# Serve
cd docs/_site && python3 -m http.server 8000
```

## WASM Demo Keyboard Focus Fix

Qt WASM has a known issue ([QTBUG-91095](https://bugreports.qt.io/browse/QTBUG-91095)) where keyboard input stops working after mouse clicks. This happens because Qt uses a hidden `<input>` element inside a shadow DOM to capture keyboard events, and mouse clicks move browser focus away from it.

**Key insight:** `mouseup` events are captured by Qt WASM before reaching JavaScript, but `pointerup` events work!

### Solution

After Qt loads, find the hidden input and refocus it on every pointer interaction:

```javascript
onLoaded: () => {
    showUi(screen);
    // Fix Qt WASM keyboard focus (QTBUG-91095)
    setTimeout(() => {
        // Find the Qt div (has shadowRoot), not other divs like loading overlays
        const qtDiv = Array.from(screen.querySelectorAll('div')).find(div => div.shadowRoot);
        if (!qtDiv?.shadowRoot) return;
        const qtInput = qtDiv.shadowRoot.querySelector('input.qt-window-input-element');
        if (!qtInput) return;
        screen.addEventListener('pointerup', () => qtInput.focus(), true);
    }, 100);
},
```

### Reusable Module

For convenience, use `assets/js/wasm-focus.js`:

```javascript
// Direct embedding
onLoaded: () => {
    showUi(screen);
    applyQtWasmFocusFix(screen);
},

// Iframe embedding
iframe.addEventListener('load', () => {
    applyQtWasmIframeFocusFix(iframe, container);
});
```

## Structure

- `index.md` - Homepage
- `getting-started.md` - Getting started guide
- `plugins.md` - Plugin overview page
- `plugins/*.md` - Symlinks to actual plugin READMEs
- `assets/css/style.scss` - Custom retro gaming theme
- `_config.yml` - Jekyll configuration

## Deployment

The site automatically deploys via GitHub Pages using GitHub Actions:

1. **One-time setup**:
   - Go to Settings → Pages in your GitHub repo
   - Source: GitHub Actions (not "Deploy from branch")
   - Save

2. **Automatic deployment**:
   - Push changes to the `main` branch
   - GitHub Action automatically:
     - Runs `sync-plugin-docs.sh` to generate plugin docs
     - Builds the Jekyll site
     - Deploys to GitHub Pages
   - No need to manually sync or commit generated files!

The site will be available at: https://[username].github.io/clayground/

## Plugin Documentation

Plugin documentation is automatically generated from the README files in `plugins/clay_*/README.md`. 

- **Locally**: The `serve.sh` script runs `sync-plugin-docs.sh` automatically
- **On GitHub**: The GitHub Action runs `sync-plugin-docs.sh` during deployment
- **Generated files** in `docs/plugins/` are ignored by git (see `.gitignore`)

This ensures single source of truth - you only need to edit the original plugin READMEs!

## Theme

The site uses a custom retro gaming theme built on top of Jekyll's minima theme. The styling includes:
- Dark background with neon accents
- Monospace headers
- Terminal-style code blocks
- Subtle scanline effects

## QML Documentation Guidelines

For properties, methods, and signals to appear in the API navigation sidebar, they must be documented **inline** before each declaration.

**Correct (inline before property):**
```qml
/*!
    \qmlproperty string MyType::name
    \brief The name of the item.
*/
property string name: ""
```

**Wrong (in header block - won't appear in navigation):**
```qml
/*!
    \qmltype MyType
    \qmlproperty string MyType::name
    \brief The name of the item.
*/
Item { ... }
```

See `CLAUDE.md` for complete documentation recipe and `plugins/clay_canvas3d/Box3D.qml` as reference.