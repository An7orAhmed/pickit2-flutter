#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pickit2_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pickit2_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Native PICkit 2 programming support for Flutter.'
  s.description      = <<-DESC
Native PICkit 2 USB programming support backed by the Microchip pk2cmd engine.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,m,mm,swift,cpp,c}'
  s.public_header_files = 'Classes/Pk2NativeBridge.h'
  s.preserve_paths = 'Classes/pk2cmd/**/*'
  s.resource_bundles = {
    'pickit2_flutter' => [
      'Resources/PK2DeviceFile.dat',
      'Resources/chip_catalog.csv',
      'Resources/PK2CMD_LICENSE.txt',
      'Resources/PrivacyInfo.xcprivacy',
    ]
  }

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '12.0'
  s.frameworks = 'IOKit', 'CoreFoundation'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) DARWIN MACOSX_HID MACOSX105 _GNU_SOURCE',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Classes/pk2cmd"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
  }
  s.swift_version = '5.0'
end
