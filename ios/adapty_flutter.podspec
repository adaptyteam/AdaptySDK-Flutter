#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint adapty_flutter.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'adapty_flutter'
  s.version          = '3.2.4'
  s.summary          = 'Adapty flutter plugin.'
  s.description      = <<-DESC
Win back churned subscribers in your iOS app.
Adapty helps you track business metrics, and lets you run ad campaigns targeted at churned users faster
                       DESC
  s.homepage         = 'https://adapty.io/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Adapty' => 'contact@adapty.io' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  
  s.ios.dependency 'Adapty', '3.2.2'
  s.ios.dependency 'AdaptyUI', '3.2.2'
  s.ios.dependency 'AdaptyPlugin', '3.2.2'
  
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.9'
end
