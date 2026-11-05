Pod::Spec.new do |s|
  s.name             = 'sber_id_sdk'
  s.version          = '0.2.1'
  s.summary          = 'Sber ID authentication plugin for Flutter.'
  s.description      = <<-DESC
Flutter plugin for Sber ID authentication on iOS and Android.
iOS: SIDSDK 4.0.2, minimum iOS 15. Android: SIDSDK_CORE and SIDSDK_ELK 1.8.0.
                       DESC
  s.homepage         = 'https://github.com/Mihalcov/sber_id'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Nurulloh' => 'nabduvahed@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'sber_id_sdk/Sources/sber_id_sdk/**/*.swift'
  s.resource_bundles = { 'sber_id_privacy' => ['sber_id_sdk/Sources/sber_id_sdk/PrivacyInfo.xcprivacy'] }
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
