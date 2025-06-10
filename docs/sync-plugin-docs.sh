#!/bin/bash
# Sync plugin README files to docs/plugins directory
# This avoids Jekyll's symlink issues while maintaining single source of truth

echo "Syncing plugin documentation..."

# Create plugins directory if it doesn't exist
mkdir -p plugins

# List of plugins
plugins=(
    "common"
    "storage"
    "text"
    "svg"
    "canvas"
    "canvas3d"
    "physics"
    "world"
    "behavior"
    "gamecontroller"
    "network"
)

# Copy each plugin's README
for plugin in "${plugins[@]}"; do
    source_file="../plugins/clay_${plugin}/README.md"
    dest_file="plugins/${plugin}.md"
    
    if [ -f "$source_file" ]; then
        # Copy the file and add Jekyll front matter
        # Capitalize first letter of plugin name
        plugin_title=$(echo "$plugin" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
        
        echo "---" > "$dest_file"
        echo "layout: page" >> "$dest_file"
        echo "title: ${plugin_title} Plugin" >> "$dest_file"
        echo "permalink: /plugins/${plugin}/" >> "$dest_file"
        echo "nav_exclude: true" >> "$dest_file"
        echo "---" >> "$dest_file"
        echo "" >> "$dest_file"
        
        # Skip the first line if it's a heading (we use Jekyll's title instead)
        tail -n +2 "$source_file" >> "$dest_file"
        
        echo "✓ Synced ${plugin}"
    else
        echo "⚠ Warning: $source_file not found"
    fi
done

echo "Documentation sync complete!"