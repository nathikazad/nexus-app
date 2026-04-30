/// Re-exported from nx_db so `features/` avoids importing package:nx_db beyond auth
/// (see test/layering/no_nx_db_in_features_test.dart).
export 'package:nx_db/nx_db.dart'
    show
        ImageEntry,
        ImageRepository,
        imageCacheManager,
        imageHeaders,
        minutesFromImageFilename;
