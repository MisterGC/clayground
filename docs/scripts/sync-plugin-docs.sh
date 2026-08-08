#!/bin/bash
# Sync plugin README files into the docs site.
# This avoids Jekyll's symlink issues while maintaining single source of truth.
#
# Two destinations, because the site has two plugin trees:
#
#   docs/plugins/<p>.md       legacy, permalink /plugins/<p>/, gitignored,
#                             nav_exclude'd but still the target of a few
#                             in-page links, so it keeps being generated.
#   docs/docs/plugins/<p>.md  the live pages the sidebar links to, tracked in
#                             git. These were written once by the docs
#                             restructure and then went stale for six months
#                             because this script only ever wrote the legacy
#                             tree - which is why they are generated here now.
#
# The live pages carry a hand-written API Reference include at the end; it is
# reproduced here so regenerating a page does not drop it.

set -u

echo "Syncing plugin documentation..."

mkdir -p plugins docs/plugins

# Plugin slugs, and the title each live page uses. The titles are not derivable
# by capitalising the slug - "AI", "Canvas3D" and "GameController" all differ
# from what a naive title-case would produce.
plugins=(
    "ai:AI"
    "algorithm:Algorithm"
    "common:Common"
    "storage:Storage"
    "text:Text"
    "svg:SVG"
    "canvas:Canvas"
    "canvas3d:Canvas3D"
    "physics:Physics"
    "world:World"
    "behavior:Behavior"
    "gamecontroller:GameController"
    "network:Network"
    "sound:Sound"
)

# Live pages that are hand-written rather than README-derived. Generating over
# these loses content: docs/docs/plugins/network.md covers ClayMultiplayer,
# ClayNetworkUser, topologies and a worked multiplayer example that the plugin
# README does not carry. They still get a legacy page from the README.
hand_written_live=" network "

for entry in "${plugins[@]}"; do
    plugin="${entry%%:*}"
    plugin_title="${entry##*:}"
    source_file="../plugins/clay_${plugin}/README.md"

    if [ ! -f "$source_file" ]; then
        echo "⚠ Warning: $source_file not found"
        continue
    fi

    # The README's own first line is a heading; Jekyll's title replaces it.
    body=$(tail -n +2 "$source_file")

    # Legacy tree
    {
        echo "---"
        echo "layout: page"
        echo "title: ${plugin_title} Plugin"
        echo "permalink: /plugins/${plugin}/"
        echo "nav_exclude: true"
        echo "---"
        echo ""
        echo "$body"
    } > "plugins/${plugin}.md"

    # Live tree
    if [[ "$hand_written_live" == *" ${plugin} "* ]]; then
        echo "✓ Synced ${plugin} (legacy only - live page is hand-written)"
        continue
    fi

    {
        echo "---"
        echo "layout: docs"
        echo "title: ${plugin_title} Plugin"
        echo "permalink: /docs/plugins/${plugin}/"
        echo "---"
        echo ""
        echo "$body"
        if [ -f "_includes/api/${plugin}.html" ]; then
            echo ""
            echo "## API Reference"
            echo ""
            echo "{% include api/${plugin}.html %}"
        fi
    } > "docs/plugins/${plugin}.md"

    echo "✓ Synced ${plugin}"
done

echo "Documentation sync complete!"
