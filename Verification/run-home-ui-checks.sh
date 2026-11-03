#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
home_device="${1:?Usage: bash Verification/run-home-ui-checks.sh SIMULATOR_UDID}"
home_qa_dir="$(mktemp -d /tmp/WeatherIsland-HomeQA.XXXXXX)"
python3 - "$project_dir" "$home_qa_dir" <<'PY'
import pathlib, sys
root, work = map(pathlib.Path, sys.argv[1:])
project = work / 'HomeQA.xcodeproj'
(project / 'xcshareddata/xcschemes').mkdir(parents=True)
source = root / 'Verification/WeatherHomeInsightsUITests.swift'
(project / 'project.pbxproj').write_text('''// !$*UTF8*$!
{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {
A00000000000000000000001 = {isa = PBXProject; buildConfigurationList = A00000000000000000000010; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = A00000000000000000000002; productRefGroup = A00000000000000000000003; projectDirPath = ""; targets = (A00000000000000000000004); };
A00000000000000000000002 = {isa = PBXGroup; children = (A00000000000000000000005, A00000000000000000000003); sourceTree = "<group>"; };
A00000000000000000000003 = {isa = PBXGroup; children = (A00000000000000000000006); name = Products; sourceTree = "<group>"; };
A00000000000000000000004 = {isa = PBXNativeTarget; buildConfigurationList = A00000000000000000000011; buildPhases = (A00000000000000000000007); buildRules = (); dependencies = (); name = HomeQA; productName = HomeQA; productReference = A00000000000000000000006; productType = "com.apple.product-type.bundle.ui-testing"; };
A00000000000000000000005 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "SOURCE_PATH"; sourceTree = "<absolute>"; };
A00000000000000000000006 = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = HomeQA.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
A00000000000000000000007 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (A00000000000000000000008); runOnlyForDeploymentPostprocessing = 0; };
A00000000000000000000008 = {isa = PBXBuildFile; fileRef = A00000000000000000000005; };
A00000000000000000000010 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000012); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
A00000000000000000000011 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000013); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug; };
A00000000000000000000012 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.6; SWIFT_VERSION = 6.0; ALWAYS_SEARCH_USER_PATHS = NO; }; name = Debug; };
A00000000000000000000013 = {isa = XCBuildConfiguration; buildSettings = {PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = com.weather.app.homeqa; GENERATE_INFOPLIST_FILE = YES; TARGETED_DEVICE_FAMILY = 1; SWIFT_VERSION = 6.0; CODE_SIGNING_ALLOWED = NO; }; name = Debug; };
}; rootObject = A00000000000000000000001; }
'''.replace('SOURCE_PATH', str(source).replace('"', '\\"')))
(project / 'xcshareddata/xcschemes/HomeQA.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000004" BuildableName="HomeQA.xctest" BlueprintName="HomeQA" ReferencedContainer="container:HomeQA.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000004" BuildableName="HomeQA.xctest" BlueprintName="HomeQA" ReferencedContainer="container:HomeQA.xcodeproj"/></TestableReference></Testables></TestAction>
</Scheme>
''')
PY
xcodebuild -project "$project_dir/WeatherIsland.xcodeproj" -scheme WeatherIsland -configuration Debug -destination "platform=iOS Simulator,id=$home_device" -derivedDataPath "$home_qa_dir/AppBuild" CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build > "$home_qa_dir/app-build.log" 2>&1
xcrun simctl install "$home_device" "$home_qa_dir/AppBuild/Build/Products/Debug-iphonesimulator/WeatherIsland.app"
xcodebuild -project "$home_qa_dir/HomeQA.xcodeproj" -scheme HomeQA -destination "platform=iOS Simulator,id=$home_device" -parallel-testing-enabled NO -derivedDataPath "$home_qa_dir/TestBuild" -resultBundlePath "$home_qa_dir/Home.xcresult" CODE_SIGNING_ALLOWED=NO test
printf 'Home QA output: %s\n' "$home_qa_dir"
