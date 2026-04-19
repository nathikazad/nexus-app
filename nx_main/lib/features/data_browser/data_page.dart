import 'package:flutter/material.dart';
import 'package:nexus_voice_assistant/features/data_browser/battery_page.dart';
import 'package:nexus_voice_assistant/features/data_browser/images_page.dart';

/// Entry point for data browsing: necklace/desktop images and (future) expenses.
class DataPage extends StatelessWidget {
  const DataPage({super.key});

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
                      const ImagesPage(source: 'necklace'),
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
                      const ImagesPage(source: 'desktop'),
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
                  builder: (context) => const BatteryPage(),
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
