#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint device_key_vault.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'device_key_vault'
  s.version          = '0.1.0'
  s.summary          = 'One secret per app, kept behind OS-enforced biometrics on iOS and Android, invalidated when enrolled biometrics change.'
  s.description      = <<-DESC
One secret per app, kept behind OS-enforced biometrics on iOS and Android, invalidated when enrolled biometrics change.
                       DESC
  s.homepage         = 'https://github.com/dxy-global/device_key_vault'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'dxy-global' => 'https://github.com/dxy-global' }
  s.source           = { :path => '.' }
  s.source_files = 'device_key_vault/Sources/device_key_vault/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'device_key_vault_privacy' => ['device_key_vault/Sources/device_key_vault/PrivacyInfo.xcprivacy']}
end
