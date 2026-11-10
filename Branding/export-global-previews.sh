#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
export_binary="$(mktemp -t weather-island-global-export)"
trap 'rm -f "$export_binary"' EXIT
sources=("$project_dir/Shared/WeatherLocalization.swift" "$project_dir/Shared/IslandWidgetData.swift" "$project_dir/Shared/IslandWidgetViews.swift" "$project_dir/WeatherIsland/WeatherWidgetGallery.swift")
for name in WeatherConnection WeatherBranding WeatherModels WeatherService WeatherHomeView WeatherEffects WeatherDetailView WeatherExplorerView WeatherPlace PaperScenes WeatherExtras WeatherApplication LocationSearch CityGeocodingService RegionalWeatherHome WeatherHomeInsights WeatherPersonalTools SceneGallery WeatherTabsView WeatherMapData; do
  sources+=("$project_dir/WeatherIsland/$name.swift")
done
swiftc -parse-as-library -module-cache-path "$project_dir/work/branding/ModuleCache" -Xfrontend -disable-sandbox "${sources[@]}" "$project_dir/Branding/ExportGlobalPreviews.swift" -o "$export_binary"
"$export_binary" "$project_dir" "$@"
