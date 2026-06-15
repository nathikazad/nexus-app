// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

Widget buildNxExcalidrawFrame({
  required Map<String, dynamic> scene,
  required ValueChanged<Map<String, dynamic>> onSave,
  required int saveRequest,
}) {
  return _NxExcalidrawWebFrame(
    scene: scene,
    onSave: onSave,
    saveRequest: saveRequest,
  );
}

class _NxExcalidrawWebFrame extends StatefulWidget {
  const _NxExcalidrawWebFrame({
    required this.scene,
    required this.onSave,
    required this.saveRequest,
  });

  final Map<String, dynamic> scene;
  final ValueChanged<Map<String, dynamic>> onSave;
  final int saveRequest;

  @override
  State<_NxExcalidrawWebFrame> createState() => _NxExcalidrawWebFrameState();
}

class _NxExcalidrawWebFrameState extends State<_NxExcalidrawWebFrame> {
  static var _nextId = 0;

  late final String _viewType;
  late final String _viewId;
  late final html.IFrameElement _iframe;
  late final StreamSubscription<html.MessageEvent> _messageSubscription;

  @override
  void initState() {
    super.initState();
    _viewId = 'nx-excalidraw-${_nextId++}';
    _viewType = '$_viewId-view';
    _iframe = html.IFrameElement()
      ..srcdoc = _htmlForScene(widget.scene, _viewId)
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'clipboard-read; clipboard-write';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return _iframe;
    });
    _messageSubscription = html.window.onMessage.listen(_handleMessage);
  }

  @override
  void didUpdateWidget(covariant _NxExcalidrawWebFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.saveRequest != oldWidget.saveRequest) {
      _requestSave();
    }
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }

  void _handleMessage(html.MessageEvent event) {
    final data = event.data;
    if (data is! String) {
      return;
    }
    final decoded = jsonDecode(data);
    if (decoded is! Map || decoded['source'] != 'nx_excalidraw') {
      return;
    }
    if (decoded['viewId'] != _viewId || decoded['type'] != 'save') {
      return;
    }
    final scene = decoded['scene'];
    if (scene is Map) {
      widget.onSave(Map<String, dynamic>.from(scene));
    }
  }

  void _requestSave() {
    _iframe.contentWindow?.postMessage(
      jsonEncode(<String, Object?>{
        'source': 'nx_excalidraw',
        'viewId': _viewId,
        'type': 'save_request',
      }),
      '*',
    );
  }
}

String _htmlForScene(Map<String, dynamic> scene, String viewId) {
  final sceneJson = jsonEncode(scene);
  final viewIdJson = jsonEncode(viewId);
  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://unpkg.com/@excalidraw/excalidraw@0.16.4/dist/excalidraw.min.css">
  <style>
    html, body, #root {
      height: 100%;
      margin: 0;
      overflow: hidden;
      background: #fff;
      font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    .nx-status {
      position: fixed;
      top: 19px;
      right: 18px;
      z-index: 10;
      color: #71717a;
      font: 500 12px Inter, system-ui, sans-serif;
      opacity: 0;
      transition: opacity 120ms ease;
      pointer-events: none;
    }
    .nx-status.visible {
      opacity: 1;
    }
    .nx-error {
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #52525b;
      font: 500 13px Inter, system-ui, sans-serif;
    }
  </style>
</head>
<body>
  <div class="nx-status" id="status">Saved</div>
  <div id="root"></div>
  <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
  <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
  <script crossorigin src="https://unpkg.com/@excalidraw/excalidraw@0.16.4/dist/excalidraw.production.min.js"></script>
  <script>
    const VIEW_ID = $viewIdJson;
    const initialScene = $sceneJson;
    let latestElements = Array.isArray(initialScene.elements) ? initialScene.elements : [];
    let latestAppState = initialScene.appState || { viewBackgroundColor: "#ffffff" };
    let latestFiles = initialScene.files || {};

    function cleanAppState(appState) {
      const allowed = [
        "viewBackgroundColor",
        "currentItemStrokeColor",
        "currentItemBackgroundColor",
        "currentItemFillStyle",
        "currentItemStrokeWidth",
        "currentItemStrokeStyle",
        "currentItemRoughness",
        "currentItemOpacity",
        "currentItemFontFamily",
        "currentItemFontSize",
        "currentItemTextAlign",
        "currentItemStartArrowhead",
        "currentItemEndArrowhead",
        "scrollX",
        "scrollY",
        "zoom"
      ];
      const next = {};
      for (const key of allowed) {
        if (appState && appState[key] !== undefined) {
          next[key] = appState[key];
        }
      }
      if (!next.viewBackgroundColor) {
        next.viewBackgroundColor = "#ffffff";
      }
      return next;
    }

    function scenePayload() {
      const scene = {
        type: "excalidraw",
        version: 2,
        source: "nx_notes",
        elements: latestElements,
        appState: cleanAppState(latestAppState),
        files: latestFiles || {}
      };
      try {
        if (window.ExcalidrawLib && window.ExcalidrawLib.serializeAsJSON) {
          return JSON.parse(
            window.ExcalidrawLib.serializeAsJSON(
              latestElements,
              latestAppState,
              latestFiles || {},
              "local"
            )
          );
        }
      } catch (error) {
        console.warn("serializeAsJSON failed", error);
      }
      return JSON.parse(JSON.stringify(scene));
    }

    function saveScene() {
      const scene = scenePayload();
      parent.postMessage(JSON.stringify({
        source: "nx_excalidraw",
        viewId: VIEW_ID,
        type: "save",
        scene
      }), "*");
      const status = document.getElementById("status");
      status.classList.add("visible");
      window.setTimeout(() => status.classList.remove("visible"), 900);
    }

    function render() {
      const root = document.getElementById("root");
      const Excalidraw = window.ExcalidrawLib && window.ExcalidrawLib.Excalidraw;
      if (!Excalidraw) {
        root.innerHTML = '<div class="nx-error">Could not load Excalidraw.</div>';
        return;
      }
      ReactDOM.createRoot(root).render(
        React.createElement(Excalidraw, {
          initialData: {
            elements: latestElements,
            appState: latestAppState,
            files: latestFiles
          },
          onChange: function(elements, appState, files) {
            latestElements = elements;
            latestAppState = appState;
            latestFiles = files || {};
          }
        })
      );
    }

    window.addEventListener("message", function(event) {
      const data = event.data;
      if (typeof data !== "string") {
        return;
      }
      try {
        const decoded = JSON.parse(data);
        if (
          decoded.source === "nx_excalidraw" &&
          decoded.viewId === VIEW_ID &&
          decoded.type === "save_request"
        ) {
          saveScene();
        }
      } catch (_) {}
    });

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", render);
    } else {
      render();
    }
  </script>
</body>
</html>
''';
}
