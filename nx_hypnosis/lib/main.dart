import 'package:flutter/material.dart';
import 'app.dart';
import 'desires.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final collection = await HypnosisCollection.load();
  runApp(HypnosisApp(collection: collection));
}
