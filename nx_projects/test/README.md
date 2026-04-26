# Tests

## Unit / widget (default)

```bash
flutter test --exclude-tags=integration
```

## Integration (live GraphQL)

Requires PGDB with:

- `model_types` loaded (`setup_model_types` or equivalent)
- `servers/pgdb/scripts/apply_project_additions.py` applied
- `seed_nx_projects_demo` (via `kitchen_sink` or calling `seed_nx_projects_demo` from fixtures)

GraphQL HTTP should match `kIntegrationTestBackendUrls` in `nx_db` (default `http://127.0.0.1:5001/graphql`).

```bash
RUN_NX_PROJECTS_INTEGRATION=true flutter test --tags integration test/integration/
```
