import 'package:flutter/material.dart';
import '../domain/book/download_report.dart';

class DownloadReportView extends StatelessWidget {
  const DownloadReportView({required this.report, this.syncing, super.key});
  final DownloadReport? report;
  final bool? syncing;

  @override
  Widget build(BuildContext context) {
    final value = report;
    if (value == null) {
      return const Text(
        'Downloads have not been verified. Use Sync now before travelling.',
      );
    }
    final complete = value.phase == DownloadPhase.complete;
    final text = complete
        ? '${value.verified}/${value.total} book and document texts verified.'
        : '${value.verified}/${value.total} texts verified so far. Check unfinished downloads with Sync now.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, key: const ValueKey('books-download-readiness')),
        if (syncing ??
            (value.phase == DownloadPhase.checking ||
                value.phase == DownloadPhase.downloading))
          const Text(
            'Sync is running. A large first sync may take several minutes; you can close Settings while it finishes.',
          ),
        if (value.failed.isNotEmpty)
          Text('${value.failed.length} downloads need attention.'),
        Text(
          'Last check: ${value.updatedAt.toLocal().toString().split('.').first}',
        ),
        const Text(
          'This check covers texts and saved AI conversations. Attached book files are verified separately; images are not included.',
        ),
      ],
    );
  }
}
