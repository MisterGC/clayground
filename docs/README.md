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

### Running Locally

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