Pod::Spec.new do |s|
  s.name             = 'opus_flutter_ios'
  s.version          = '0.0.2'
  s.summary          = 'libopus wrappers for Flutter on iOS.'
  s.description      = 'Local opus_flutter_ios podspec that builds libopus for device and simulator.'
  s.homepage         = 'https://epnw.eu'
  s.license          = { :type => 'BSD' }
  s.author           = { 'EPNW GmbH' => 'contact@epnw.eu' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'libopus', '~> 1.1'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.1'
end
