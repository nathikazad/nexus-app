import 'package:flutter/material.dart';

import 'battery_screen.dart';
import 'images_screen.dart';

/// Entry point for data browsing: necklace/desktop images and (future) expenses.
class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Necklace images'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      const ImagesScreen(source: 'necklace'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.desktop_windows),
            title: const Text('Desktop images'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      const ImagesScreen(source: 'desktop'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.battery_full),
            title: const Text('Necklace battery'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const BatteryScreen(),
                ),
              );
            },
          ),
          ListTile(
            enabled: false,
            leading: const Icon(Icons.receipt_long),
            title: const Text('Expenses'),
            subtitle: Text(
              'Coming soon',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
