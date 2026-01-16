/// HealthSync Flutter Plugin
///
/// Universal health data integration for Flutter applications.
/// Provides unified access to Android Health Connect and other health data sources.
library health_sync_flutter;

export 'src/models/data_type.dart';
export 'src/models/health_source.dart';
export 'src/models/health_data.dart';
export 'src/models/connection_status.dart';
export 'src/models/aggregate_data.dart';

export 'src/plugins/health_connect/health_connect_plugin.dart';
export 'src/plugins/health_connect/health_connect_types.dart';

export 'src/plugins/fitbit/fitbit_plugin.dart';
export 'src/plugins/fitbit/fitbit_types.dart';

export 'src/types/errors.dart';
export 'src/types/plugin_config.dart';
export 'src/types/data_query.dart';

// Logging and Analytics
export 'src/utils/logger.dart';
export 'src/utils/permission_tracker.dart';
export 'src/utils/data_aggregator.dart';

// Rate Limiting and Batch Operations
export 'src/utils/rate_limiter.dart';
export 'src/utils/batch_writer.dart';

// Incremental Sync (Changes API)
export 'src/utils/changes_api.dart';
export 'src/utils/sync_token_manager.dart';

// Aggregate Data Reader
export 'src/utils/aggregate_reader.dart';

// Background Sync
export 'src/background_sync/background_sync_config.dart';
export 'src/background_sync/background_sync_service.dart';
export 'src/background_sync/background_sync_handler.dart';
export 'src/background_sync/background_sync_stats.dart';
export 'src/background_sync/device_info.dart';

// Conflict Detection (Double-Count Detector)
export 'src/conflict_detection/conflict_detector.dart';
export 'src/conflict_detection/data_source_info.dart';

// Data Caching
export 'src/cache/health_data_cache.dart';
