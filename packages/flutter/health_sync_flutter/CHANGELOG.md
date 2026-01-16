# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-01-16

### Changed
- Updated authorship to HCL Healthcare Product Team
- Updated repository URLs to https://github.com/Vinamra111/health-sync-sdk
- Made README more concise (reduced from 699 to 180 lines)
- Updated all documentation links

### Fixed
- Fixed code analysis warnings (String.repeat to String * operator)
- Fixed const constructor issues with DateTime.now()

## [1.0.0] - 2025-01-14

### Added
- Initial release of health_sync_flutter
- Complete Health Connect integration for Flutter
- **Health Connect Onboarding System** - Enterprise-grade onboarding flow
- Changes API for incremental sync with fallback
- Aggregate data reader with validation
- Background sync service with device compatibility
- Conflict detection and resolution system
- Rate limiting for API calls
- Comprehensive caching with SQLite
- Full test coverage (100+ tests)

### Features

#### Health Connect Onboarding
- **Stub Detection**: Automatically detects Health Connect stub state on Android 14/15
- **Update Loop Bug Mitigation**: Device-specific retry strategies (Nothing/OnePlus: 8 retries × 2s)
- **OEM Intelligence**: Built-in knowledge of 10+ manufacturers with specific quirks
- **Reactive Streams**: Real-time state and result updates
- **Play Store Integration**: Automatic deep linking with retry verification
- **Native Step Tracking**: Detects Android 14/15 native step counting
- **Diagnostic Tools**: Detailed reports for troubleshooting

#### Data Sync
- **Changes API**: Incremental sync with automatic fallback to full sync
- **Aggregate Data**: Efficient aggregate queries with validation
- **Background Sync**: Reliable background synchronization with WorkManager
- **Conflict Resolution**: Automatic duplicate detection and conflict resolution
- **Rate Limiting**: Intelligent rate limiting to respect API quotas

#### Caching & Performance
- **SQLite Caching**: Local data caching for offline access
- **Smart Invalidation**: Automatic cache invalidation on data changes
- **Optimized Queries**: Efficient data retrieval with pagination
- **Sync Tokens**: Token-based incremental sync support

#### Device Compatibility
- **Device Profiles**: Manufacturer-specific optimization (Google, Samsung, Nothing, OnePlus, etc.)
- **Battery Management**: Handling for aggressive battery managers (Xiaomi, Huawei, OPPO)
- **Background Constraints**: Device-specific background sync configuration
- **Compatibility Reports**: Detailed device compatibility assessments

### Platform Support
- Android: API 26+ (Android 8.0+)
- iOS: Coming soon (HealthKit integration planned)

### Test Coverage
- 117+ tests passing
- Unit tests for all core components
- Integration tests for sync flows
- Background sync tests
- Conflict detection tests
- Onboarding system tests (49 tests)

### Documentation
- Complete API documentation
- Integration guides
- Background sync guide
- Conflict detection guide
- Aggregate data guide
- Changes API guide
- Onboarding system guide

### Dependencies
- flutter: >=3.0.0
- plugin_platform_interface: ^2.1.0
- http: ^1.1.0
- url_launcher: ^6.2.1
- crypto: ^3.0.3
- flutter_secure_storage: ^9.0.0
- sqflite: ^2.3.0
- path: ^1.8.3
- shared_preferences: ^2.2.0
- workmanager: ^0.5.2

### Breaking Changes
None - Initial release

### Known Issues
- iOS support is not yet available (planned for v1.1.0)
- Some OEM-specific behaviors may require further optimization

### Migration Guide
This is the initial release. No migration needed.

[1.0.0]: https://github.com/Vinamra111/health-sync-sdk/releases/tag/v1.0.0
