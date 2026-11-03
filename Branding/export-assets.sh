#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
export_binary="$(mktemp -t weather-island-brand-export)"
trap 'rm -f "$export_binary"' EXIT
sources=()
for name in WeatherConnection WeatherBranding WeatherModels WeatherService WeatherHomeView WeatherEffects WeatherDetailView WeatherExplorerView WeatherPlace PaperScenes WeatherExtras WeatherApplication LocationSearch RegionalWeatherHome WeatherHomeInsights SceneGallery WeatherTabsView; do
  sources+=("$project_dir/WeatherIsland/$name.swift")
done
swiftc -parse-as-library -module-cache-path "$project_dir/work/branding/ModuleCache" -Xfrontend -disable-sandbox "${sources[@]}" "$project_dir/Branding/ExportBrandAssets.swift" -o "$export_binary"
"$export_binary" "$project_dir"
