platform :ios, '17.0'

project 'WeatherIsland.xcodeproj'

target 'WeatherIsland' do
  use_frameworks! :linkage => :static
  pod 'Adjust', '~> 5.8.2'
end

# Keep the SDK targets aligned with the App's supported iOS version.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
