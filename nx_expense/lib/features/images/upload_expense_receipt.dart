import 'package:nx_expense/data/sync/expense_sync_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_expense/data/images/expense_image_upload_api.dart';
import 'package:nx_expense/data/images/expense_images.dart';

final expenseImagePickerProvider = Provider<ImagePicker>(
  (ref) => ImagePicker(),
);

Future<void> uploadExpenseReceipt(
  BuildContext context,
  WidgetRef ref, {
  Object? sourceOverride,
  VoidCallback? onUploaded,
  ValueChanged<bool>? onBusyChanged,
}) async {
  String? currentSession() {
    final user = ref.read(authProvider).value;
    return user?.domainId == null ? null : user!.sessionKey;
  }

  final session = currentSession();
  if (session == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sign in and select a domain to upload images.'),
      ),
    );
    return;
  }
  final cameraAvailable =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  final source =
      sourceOverride ??
      await showModalBottomSheet<Object>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cameraAvailable)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Choose PDF'),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose image'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
  if (source == null || !context.mounted) return;
  onBusyChanged?.call(true);
  try {
    final pdf = source == 'pdf';
    XFile? file;
    if (pdf) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null) {
        file = result.xFiles.single;
      }
    } else {
      file = await ref
          .read(expenseImagePickerProvider)
          .pickImage(source: source as ImageSource, imageQuality: 85);
    }
    if (file == null || !context.mounted || currentSession() != session) {
      return;
    }
    final base = ref.read(imageBaseUrlProvider);
    final userId = ref.read(userIdProvider);
    final client = ref.read(nexusHttpClientProvider);
    if (base == null || userId == null || client == null) {
      throw StateError('Sign in to upload an image');
    }
    final bytes = await file.readAsBytes();
    if (!context.mounted || currentSession() != session) {
      return;
    }
    final png = file.name.toLowerCase().endsWith('.png');
    await uploadExpenseSnapshot(
      imageBaseUrl: base,
      userId: userId,
      domainId: ref.read(authProvider).value!.requiredDomainId,
      bytes: bytes,
      filename: pdf
          ? 'upload.pdf'
          : png
          ? 'upload.png'
          : 'upload.jpg',
      imageContentType: pdf
          ? MediaType('application', 'pdf')
          : MediaType('image', png ? 'png' : 'jpeg'),
      httpClient: client,
    );
    if (!context.mounted || currentSession() != session) {
      return;
    }
    ref.read(expenseTransportProvider)?.reads.invalidate();
    ref.invalidate(expenseImagesProvider);
    // New standalone uploads are unlinked and must be visible after success.
    onUploaded?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt uploaded. Ready to reconcile later.'),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not upload the image. Please try again.'),
        ),
      );
    }
  } finally {
    onBusyChanged?.call(false);
  }
}
