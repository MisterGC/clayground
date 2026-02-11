#!/usr/bin/env python3
"""
Generate Jekyll HTML includes from QDoc-generated clayground.index XML.

Parses the QDoc index file and generates HTML partials for each plugin module,
embedding API reference documentation directly into plugin pages.
"""

import xml.etree.ElementTree as ET
from pathlib import Path
from html import escape
from collections import defaultdict

# Map QDoc module names to plugin directory names
MODULE_TO_PLUGIN = {
    "Clayground.Common": "common",
    "Clayground.Canvas": "canvas",
    "Clayground.Canvas3D": "canvas3d",
    "Clayground.Physics": "physics",
    "Clayground.World": "world",
    "Clayground.Behavior": "behavior",
    "Clayground.GameController": "gamecontroller",
    "Clayground.Network": "network",
    "Clayground.Storage": "storage",
    "Clayground.Text": "text",
    "Clayground.Svg": "svg",
    "Clayground.Ai": "ai",
}


def parse_index(index_path: Path) -> dict:
    """Parse clayground.index XML and extract QML type information."""
    tree = ET.parse(index_path)
    root = tree.getroot()

    # Group types by module
    modules = defaultdict(list)

    for qmlclass in root.iter("qmlclass"):
        module = qmlclass.get("qml-module-name", "")
        if not module:
            # Try to infer from fullname
            fullname = qmlclass.get("fullname", "")
            if "." in fullname:
                module = fullname.rsplit(".", 1)[0]

        name = qmlclass.get("name", "")
        brief = qmlclass.get("brief", "")
        href = qmlclass.get("href", "")

        # Extract properties
        properties = []
        for prop in qmlclass.findall("qmlproperty"):
            properties.append({
                "name": prop.get("name", ""),
                "type": prop.get("type", ""),
                "brief": prop.get("brief", ""),
                "writable": prop.get("writable", "true") == "true",
                "required": prop.get("required", "false") == "true",
            })

        # Extract methods and signals
        methods = []
        signals = []
        for func in qmlclass.findall("function"):
            meta = func.get("meta", "")
            func_info = {
                "name": func.get("name", ""),
                "type": func.get("type", "void"),
                "brief": func.get("brief", ""),
                "parameters": [],
            }
            for param in func.findall("parameter"):
                func_info["parameters"].append({
                    "name": param.get("name", ""),
                    "type": param.get("type", ""),
                })

            if meta == "qmlmethod":
                methods.append(func_info)
            elif meta == "qmlsignal":
                signals.append(func_info)

        type_info = {
            "name": name,
            "brief": brief,
            "href": href,
            "properties": sorted(properties, key=lambda x: x["name"]),
            "methods": sorted(methods, key=lambda x: x["name"]),
            "signals": sorted(signals, key=lambda x: x["name"]),
        }

        if module:
            modules[module].append(type_info)

    # Sort types within each module
    for module in modules:
        modules[module].sort(key=lambda x: x["name"])

    return dict(modules)


def generate_html(types: list, plugin_name: str) -> str:
    """Generate HTML for a plugin's API reference section."""
    if not types:
        return "<!-- No API types found for this plugin -->\n"

    lines = ['<div class="api-reference">']

    for type_info in types:
        name = escape(type_info["name"])
        brief = escape(type_info["brief"]) if type_info["brief"] else ""
        href = type_info["href"]

        # Type header with collapsible details (id for anchor linking)
        lines.append(f'  <details class="api-type" id="{escape(type_info["name"].lower())}">')
        lines.append(f'    <summary>')
        lines.append(f'      <span class="type-name">{name}</span>')
        if brief:
            lines.append(f'      <span class="type-brief">{brief}</span>')
        lines.append(f'    </summary>')
        lines.append(f'    <div class="api-type-content">')

        # Link to full API docs
        if href:
            lines.append(f'      <p class="api-link"><a href="/api/{href}">View full documentation</a></p>')

        # Properties section
        if type_info["properties"]:
            lines.append('      <div class="api-section">')
            lines.append('        <h4>Properties</h4>')
            lines.append('        <table class="api-table">')
            lines.append('          <thead><tr><th>Name</th><th>Type</th><th>Description</th></tr></thead>')
            lines.append('          <tbody>')
            for prop in type_info["properties"]:
                prop_name = escape(prop["name"])
                prop_type = escape(prop["type"])
                prop_brief = escape(prop["brief"]) if prop["brief"] else ""
                badges = []
                if prop["required"]:
                    badges.append('<span class="api-badge required">required</span>')
                if not prop["writable"]:
                    badges.append('<span class="api-badge readonly">readonly</span>')
                badge_str = " ".join(badges)
                lines.append(f'            <tr><td><code>{prop_name}</code>{" " + badge_str if badge_str else ""}</td><td><code>{prop_type}</code></td><td>{prop_brief}</td></tr>')
            lines.append('          </tbody>')
            lines.append('        </table>')
            lines.append('      </div>')

        # Methods section
        if type_info["methods"]:
            lines.append('      <div class="api-section">')
            lines.append('        <h4>Methods</h4>')
            lines.append('        <table class="api-table">')
            lines.append('          <thead><tr><th>Method</th><th>Returns</th><th>Description</th></tr></thead>')
            lines.append('          <tbody>')
            for method in type_info["methods"]:
                method_name = escape(method["name"])
                params = ", ".join(f'{escape(p["type"])} {escape(p["name"])}' for p in method["parameters"])
                method_sig = f'{method_name}({params})'
                return_type = escape(method["type"]) if method["type"] else "void"
                method_brief = escape(method["brief"]) if method["brief"] else ""
                lines.append(f'            <tr><td><code>{method_sig}</code></td><td><code>{return_type}</code></td><td>{method_brief}</td></tr>')
            lines.append('          </tbody>')
            lines.append('        </table>')
            lines.append('      </div>')

        # Signals section
        if type_info["signals"]:
            lines.append('      <div class="api-section">')
            lines.append('        <h4>Signals</h4>')
            lines.append('        <table class="api-table">')
            lines.append('          <thead><tr><th>Signal</th><th>Description</th></tr></thead>')
            lines.append('          <tbody>')
            for signal in type_info["signals"]:
                signal_name = escape(signal["name"])
                params = ", ".join(f'{escape(p["type"])} {escape(p["name"])}' for p in signal["parameters"])
                signal_sig = f'{signal_name}({params})'
                signal_brief = escape(signal["brief"]) if signal["brief"] else ""
                lines.append(f'            <tr><td><code>{signal_sig}</code></td><td>{signal_brief}</td></tr>')
            lines.append('          </tbody>')
            lines.append('        </table>')
            lines.append('      </div>')

        lines.append('    </div>')
        lines.append('  </details>')

    lines.append('</div>')
    return "\n".join(lines) + "\n"


def main():
    # Paths relative to docs directory (script runs from docs/)
    script_dir = Path(__file__).parent
    docs_dir = script_dir.parent
    index_path = docs_dir / "api" / "clayground.index"
    output_dir = docs_dir / "_includes" / "api"

    if not index_path.exists():
        print(f"Warning: {index_path} not found. Run 'cmake --build build --target docs' first.")
        return

    print(f"Parsing {index_path}...")
    modules = parse_index(index_path)

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Generate HTML for each plugin
    generated = []
    for module_name, plugin_name in MODULE_TO_PLUGIN.items():
        types = modules.get(module_name, [])
        html = generate_html(types, plugin_name)

        output_path = output_dir / f"{plugin_name}.html"
        output_path.write_text(html)
        generated.append(f"  {plugin_name}.html ({len(types)} types)")

    print(f"Generated {len(generated)} API include files:")
    for item in generated:
        print(item)

    # Generate plugin_types.yml for sidebar navigation
    types_data = {}
    for module_name, plugin_name in MODULE_TO_PLUGIN.items():
        types = modules.get(module_name, [])
        if types:
            types_data[plugin_name] = [
                {
                    "name": t["name"],
                    "href": t["href"]  # QDoc HTML filename
                }
                for t in types
            ]

    yaml_path = docs_dir / "_data" / "plugin_types.yml"
    yaml_path.parent.mkdir(parents=True, exist_ok=True)
    with open(yaml_path, "w") as f:
        for plugin, types in sorted(types_data.items()):
            f.write(f"{plugin}:\n")
            for t in types:
                f.write(f'  - name: "{t["name"]}"\n')
                f.write(f'    href: "{t["href"]}"\n')

    print(f"\nGenerated {yaml_path.name} with types for {len(types_data)} plugins")


if __name__ == "__main__":
    main()
