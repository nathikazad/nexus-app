Pod::Spec.new do |s|
  s.name = 'opus_flutter_ios'
  s.version = '3.0.1'
  s.summary = 'libopus for Flutter on iOS.'
  s.description = 'Nexus-maintained opus_flutter iOS implementation with device and arm64 simulator slices.'
  s.homepage = 'https://github.com/EPNW/opus_flutter'
  s.license = { :file => '../LICENSE' }
  s.author = { 'EPNW GmbH' => 'contact@epnw.eu' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.vendored_frameworks = 'opus.xcframework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
