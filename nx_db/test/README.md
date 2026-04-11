flutter test                          # everything (integration groups skipped unless RUN_NX_DB_INTEGRATION=true)
flutter test test/unit
flutter test test/providers
flutter test test/widget
flutter test test/integration

flutter test --tags=providers
flutter test --tags=unit
flutter test --exclude-tags=integration
RUN_NX_DB_INTEGRATION=true flutter test test/integration