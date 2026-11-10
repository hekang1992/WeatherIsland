#!/bin/bash
# Exercise Xcode's compiled catalog (.strings + .stringsdict), not the source fallback.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app_bundle="${1:-$root/work/LocalizationBuild/Build/Products/Debug-iphonesimulator/WeatherIsland.app}"
runtime_dir="$(mktemp -d /tmp/WeatherIsland-CompiledLocalization.XXXXXX)"
for language in zh-Hans en vi; do
  cp -R "$app_bundle/$language.lproj" "$runtime_dir/$language.lproj"
done
cat > "$runtime_dir/main.swift" <<'SWIFT'
import Foundation
for language in [AppLanguage.chinese, .english, .vietnamese] {
    precondition(Bundle.main.path(forResource: language.rawValue, ofType: "lproj") != nil)
}
precondition(WeatherLocalization.text("气象岛", language: .english) == "Weather Island")
precondition(WeatherLocalization.text("气象岛", language: .vietnamese) == "Đảo Thời Tiết")
precondition(WeatherLocalization.count("duration.hours", 1, language: .english) == "1 hour")
precondition(WeatherLocalization.count("duration.hours", 2, language: .english) == "2 hours")
precondition(WeatherLocalization.count("duration.minutes", 2, language: .vietnamese) == "2 phút")
precondition(WeatherLocalization.count("duration.hours", 2, language: .chinese) == "2小时")
precondition(WeatherLocalization.format("今天温差 %1$@°。%2$@%3$@", ["8", "Rain.", "UV."], language: .english).contains("Rain. UV."))
print("PASS: compiled zh-Hans/en/vi catalog lookup, plural resources, Vietnamese accents and sentence interpolation")
SWIFT
swiftc -module-cache-path "$runtime_dir/ModuleCache" "$root/Shared/WeatherLocalization.swift" "$runtime_dir/main.swift" -o "$runtime_dir/check"
"$runtime_dir/check"
