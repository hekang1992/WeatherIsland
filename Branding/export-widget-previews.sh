#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
export_binary="$(mktemp -t weather-widget-export)"
trap 'rm -f "$export_binary"' EXIT
swiftc -parse-as-library -module-cache-path "$project_dir/work/branding/ModuleCache" "$project_dir/Shared/WeatherLocalization.swift" "$project_dir/Shared/IslandWidgetData.swift" "$project_dir/Shared/IslandWidgetViews.swift" "$project_dir/Branding/ExportWidgetPreviews.swift" -o "$export_binary"
"$export_binary" "${1:-$project_dir/Previews}"
