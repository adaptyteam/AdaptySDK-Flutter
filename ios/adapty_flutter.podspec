#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint adapty_flutter.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'adapty_flutter'
  s.version          = '2.9.1'
  s.summary          = 'Adapty flutter plugin.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://adapty.io/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Adapty' => 'contact@adapty.io' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.ios.dependency 'Adapty', '2.9.3'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.3'
end
