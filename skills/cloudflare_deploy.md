---
name: cloudflare-deploy
description: Deploy Nexus Flutter web apps served through the remote nexus-mcp Docker container and Cloudflare Tunnel.
---

# Cloudflare Deploy

Use this when deploying a Flutter web app under `nexus.nathikazad.com` through the Raspberry Pi `cloudflared` tunnel.

## nx_notes

Work from:

```bash
cd /Users/nathikazad/Projects/Nexus/mobile/nx_notes
```

Build with the `/notes/` base href:

```bash
flutter analyze
flutter build web --release --base-href /notes/
```

Patch Flutter's stable asset URLs with a fresh cache-busting version. Flutter emits stable filenames like `main.dart.js`, so Cloudflare/browser caches can otherwise keep old code.

```bash
v=$(date +%s)
perl -0pi -e "s#<script src=\"flutter_bootstrap\\.js\" async></script>#<script src=\"flutter_bootstrap.js?v=$v\" async></script>#" build/web/index.html
perl -0pi -e "s#\"mainJsPath\":\"main\\.dart\\.js\"#\"mainJsPath\":\"main.dart.js?v=$v\"#" build/web/flutter_bootstrap.js
```

Sync the local static copy and the remote host checkout:

```bash
rsync -az --delete build/web/ /Users/nathikazad/Projects/Nexus/servers/mcp/server/static/nx_notes/
rsync -az --delete build/web/ nathik@100.108.43.37:~/Nexus/nexus-server/mcp/server/static/nx_notes/
```

The public service is served by the `nexus-mcp` Docker container, not directly from the remote host checkout. Copy the static files into the container and restart it:

```bash
ssh nathik@100.108.43.37 "set -e; docker cp ~/Nexus/nexus-server/mcp/server/static/nx_notes/. nexus-mcp:/app/server/static/nx_notes/; docker restart nexus-mcp"
```

Verify the origin before handing off:

```bash
curl -sS -D - http://100.108.43.37:8001/notes/ -o /tmp/notes.html | sed -n '1,20p'
grep -o 'flutter_bootstrap.js?v=[0-9]*' /tmp/notes.html
curl -sS "http://100.108.43.37:8001/notes/main.dart.js?v=$v" -o /tmp/main.dart.js
shasum /tmp/main.dart.js
```

Open the public Cloudflare URL with the version query if needed:

```text
https://nexus.nathikazad.com/notes/?v=$v
```

## Notes

- Cloudflare Tunnel routing is managed remotely by `cloudflared`; on the Pi it maps `nexus.nathikazad.com` to `http://localhost:8001`.
- If direct Tailscale URL works but Cloudflare is stale, first suspect cached stable Flutter assets.
- The server route should emit `Cache-Control: no-cache, max-age=0, must-revalidate`, but still use versioned asset URLs for immediate deploy correctness.
- Do not deploy by rsyncing only to the host checkout; the running container serves `/app/server/static/nx_notes`.
