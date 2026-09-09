import 'package:flutter/material.dart';
import '../domain/book/download_report.dart';

class DownloadReportView extends StatelessWidget {
  const DownloadReportView({required this.report, super.key});
  final DownloadReport? report;

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
        if (value.failed.isNotEmpty)
          Text('${value.failed.length} downloads need attention.'),
        Text(
          'Last check: ${value.updatedAt.toLocal().toString().split('.').first}',
        ),
        const Text(
          'This check covers text. Images and AI conversations are not included.',
        ),
      ],
    );
  }
}
