import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

void main() => runApp(const InkTest());

/// Static Flutter shell. No drawing model, persistence, timers or ink callbacks.
class InkTest extends StatelessWidget {
  const InkTest({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'NX Flutter Ink Test',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Stock black ink · no saving · write below'),
            ),
            Expanded(
              child: PlatformViewLink(
                viewType: 'nx_ink_test/stock',
                surfaceFactory: (context, controller) => AndroidViewSurface(
                  controller: controller as AndroidViewController,
                  hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),
                onCreatePlatformView: (params) {
                  final view = PlatformViewsService.initExpensiveAndroidView(
                    id: params.id,
                    viewType: 'nx_ink_test/stock',
                    layoutDirection: TextDirection.ltr,
                  );
                  view.addOnPlatformViewCreatedListener(
                    params.onPlatformViewCreated,
                  );
                  view.create();
                  return view;
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
