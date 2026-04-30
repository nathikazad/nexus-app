import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_db/src/models/data/image/http_image_repository.dart';
import 'package:nx_db/src/models/domain/image/image_repository.dart';

final imageRepositoryProvider = Provider<ImageRepository>((ref) {
  return HttpImageRepository();
});
