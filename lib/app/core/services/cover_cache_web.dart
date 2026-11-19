import 'package:crewpoint_app/app/core/services/cover_cache.dart';

/// The web build keeps covers in memory, as its Drift database is.
ICoverCache createCoverCache() => MemoryCoverCache();
