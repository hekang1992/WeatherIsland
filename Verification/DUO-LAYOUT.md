# iPhone Duo UI adaptation — 2026-11-02

Layout uses available view dimensions, with no device-name checks:

- Home scene preserves its 360:248 aspect ratio; the reading area supports up to 720 points.
- Detail temperature and illustration use a horizontal layout with a vertical fallback. The daylight curve follows the available width.
- Weather and scene grids select their column counts from available width.
- Settings and informational pages keep a centered reading area.
- Map controls use a horizontal rail on short portrait displays and a separate right rail in landscape. Short landscape layouts use smaller panels; the forecast time and duration controls can wrap.
- iPhone supports portrait and both landscape orientations.

## Verification

- Simulator Debug build passed with signing disabled. Log: `/tmp/WeatherIsland-Duo-build-compact.log`.
- `bash Verification/run-checks.sh` passed, including settings, location, regional data, map and weather-service checks. Log: `/tmp/WeatherIsland-Duo-checks.log`.
- `git diff --check` passed.
- App launched with offline data on an iPhone Duo / iOS 27.1 simulator. The captured home weather cards fit beside the system navigation rail: `Previews/Weather-Duo-Home-Cards.png`. This capture covers the visible cards only.
- Added `WeatherAdaptiveLayoutUITests.swift` for home, detail, theatre and map rotation checks. Test execution did not complete: one attempt encountered SpringBoard / runner launch failures, and the fresh-device attempt stalled after “Running tests…” and was interrupted. These tests are not recorded as passing.
- Folding/unfolding, both Duo displays, rotation interactions and complete page-by-page visual acceptance remain unverified. Display power controls are not a verified folding mechanism.
