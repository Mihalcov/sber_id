## 0.0.1+2

### Dependencies
- Android: SIDSDK_CORE 1.3.1, SIDSDK_ELK 1.3.1 (ELK 1.3.2 требует CORE 1.3.2, пока не в Maven)
- Android: androidx fragment-ktx 1.8.8, lifecycle-runtime-ktx 2.9.2
- Dart: flutter_lints 6.0.0, plugin_platform_interface ^2.1.8
- iOS: SIDSDK ~> 1.7.4 (unchanged)

## 0.0.1+1

### Features
- iOS Sber ID authentication support with native SDK integration
- Automatic SDK optimization (dynamic/static linking detection)
- Check Sber ID mobile app installation status
- Support for both native app and web authentication flows
- Comprehensive iOS setup documentation with URL scheme configuration

### Improvements
- Updated to SIDSDKStatic 1.6.0 for better compatibility
- Smart linking mode detection for optimal performance
- Enhanced error handling and validation
- Complete example application with authentication flow

### Platform Support
- iOS 14.0+ with automatic linking mode compatibility
- Android support coming in future releases

## 0.0.1
* Initial release
* iOS Sber ID authentication support
* Check Sber ID app installation
* Web and native app authentication flows