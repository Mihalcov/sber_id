Pod::Spec.new do |s|
  s.name             = 'sber_id'
  s.version          = '0.0.1+1'
  s.summary          = 'Sber ID authentication plugin for Flutter.'
  s.description      = <<-DESC
Flutter plugin for Sber ID authentication on iOS and Android.
                       DESC
  s.homepage         = 'https://github.com/nurullohabduvohidov/sber_id'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Nurulloh' => 'nabduvahed@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'sber_id/Sources/sber_id/**/*.swift'
  s.resource_bundles = { 'sber_id_privacy' => ['sber_id/Sources/sber_id/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.dependency 'SIDSDK', '~> 4.0.2'
  s.platform = :ios, '15.0'
  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES'
  }
end
