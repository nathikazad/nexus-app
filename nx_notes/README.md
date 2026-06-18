# nx_notes

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Serve from Nexus HTTP server

Build the Flutter web app with the `/docs/` base path and copy it into the MCP HTTP server static directory:

```sh
flutter build web --release --base-href /docs/
rsync -az --delete build/web/ ../../servers/mcp/server/static/nx_notes/

rsync -az --delete build/web/ nathik@100.108.43.37:~/Nexus/nexus-server/mcp/server/static/nx_notes/

http://100.108.43.37:8001/docs/
```
