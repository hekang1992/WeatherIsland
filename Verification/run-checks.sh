#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_binary="$(mktemp -t weather-island-checks)"
trap 'rm -f "$check_binary"' EXIT
sources=("$project_dir/Shared/WeatherLocalization.swift" "$project_dir/Shared/IslandWidgetData.swift" "$project_dir/Shared/IslandWidgetViews.swift" "$project_dir/WeatherIsland/WeatherWidgetGallery.swift")
for name in BusinessEntry WeatherConnection WeatherBranding WeatherModels WeatherService WeatherHomeView WeatherEffects WeatherDetailView WeatherExplorerView WeatherPlace PaperScenes WeatherExtras WeatherApplication LocationSearch CityGeocodingService RegionalWeatherHome WeatherHomeInsights WeatherPersonalTools SceneGallery WeatherTabsView WeatherMapData; do
  sources+=("$project_dir/WeatherIsland/$name.swift")
done
swiftc -parse-as-library -module-cache-path "$project_dir/work/branding/ModuleCache" -Xfrontend -disable-sandbox "${sources[@]}" "$project_dir/Verification/WeatherLocalizationChecks.swift" "$project_dir/Verification/WeatherConnectionChecks.swift" "$project_dir/Verification/WeatherLocationChecks.swift" "$project_dir/Verification/CitySearchChecks.swift" "$project_dir/Verification/WeatherSettingsChecks.swift" "$project_dir/Verification/WeatherMapChecks.swift" "$project_dir/Verification/WeatherWidgetChecks.swift" "$project_dir/Verification/WeatherHomeInsightChecks.swift" "$project_dir/Verification/WeatherServiceChecks.swift" -o "$check_binary"
WEATHER_ISLAND_LANGUAGE=zh-Hans "$check_binary" "$project_dir/Verification/shanghai-response.json" "$@"

swiftc -parse-as-library -swift-version 6 -module-cache-path "${TMPDIR:-/tmp}/WeatherIsland-BusinessEntry-ModuleCache" "$project_dir/WeatherIsland/BusinessEntry.swift" "$project_dir/Verification/BusinessEntryChecks.swift" -o "$check_binary"
"$check_binary"
