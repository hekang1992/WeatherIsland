#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_binary="$(mktemp -t weather-island-checks)"
trap 'rm -f "$check_binary"' EXIT
sources=()
for name in WeatherConnection WeatherBranding WeatherModels WeatherService WeatherHomeView WeatherEffects WeatherDetailView WeatherExplorerView WeatherPlace PaperScenes WeatherExtras WeatherApplication LocationSearch RegionalWeatherHome SceneGallery WeatherTabsView WeatherMapData; do
  sources+=("$project_dir/WeatherIsland/$name.swift")
done
swiftc -parse-as-library -module-cache-path "$project_dir/work/branding/ModuleCache" -Xfrontend -disable-sandbox "${sources[@]}" "$project_dir/Verification/WeatherConnectionChecks.swift" "$project_dir/Verification/WeatherLocationChecks.swift" "$project_dir/Verification/WeatherMapChecks.swift" "$project_dir/Verification/WeatherServiceChecks.swift" -o "$check_binary"
"$check_binary" "$project_dir/Verification/shanghai-response.json" "$@"
