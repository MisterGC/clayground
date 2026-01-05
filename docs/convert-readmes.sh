#!/bin/bash
# Convert plugin README.md files to styled HTML for API docs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGINS_DIR="$SCRIPT_DIR/../plugins"
OUTPUT_DIR="$SCRIPT_DIR/api/readme"

# HTML header with dark theme styling
HTML_HEADER='<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <link rel="stylesheet" href="../style.css">
    <style>
        body { padding: 2rem; max-width: 800px; }
        h1 { margin-top: 0; }
        ul { padding-left: 1.5rem; }
        li { margin: 0.3rem 0; }
    </style>
</head>
<body>'

HTML_FOOTER='</body></html>'

for readme in "$PLUGINS_DIR"/clay_*/README.md; do
    if [ -f "$readme" ]; then
        # Extract plugin name (e.g., clay_canvas3d -> canvas3d)
        plugin_dir=$(dirname "$readme")
        name=$(basename "$plugin_dir" | sed 's/clay_//')

        echo "Converting: $name"

        # Create HTML file
        output="$OUTPUT_DIR/$name.html"
        echo "$HTML_HEADER" > "$output"

        # Simple markdown to HTML conversion
        sed -E '
            s/^# (.*)/<h1>\1<\/h1>/
            s/^## (.*)/<h2>\1<\/h2>/
            s/^### (.*)/<h3>\1<\/h3>/
            s/^- (.*)/<li>\1<\/li>/
            s/```qml/<pre><code>/
            s/```javascript/<pre><code>/
            s/```/<\/code><\/pre>/
            s/`([^`]+)`/<code>\1<\/code>/g
            s/\*\*([^*]+)\*\*/<strong>\1<\/strong>/g
            s/\*([^*]+)\*/<em>\1<\/em>/g
        ' "$readme" >> "$output"

        echo "$HTML_FOOTER" >> "$output"
    fi
done

echo "Done! README files converted to: $OUTPUT_DIR"
