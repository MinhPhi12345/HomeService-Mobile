import 'package:flutter/foundation.dart';

/// Ảnh dịch vụ do Admin tải lên, tra theo tên dịch vụ (tên là duy nhất ở Backend).
/// [ApiClient.getCategories] cập nhật danh sách; [ServiceIconBadge] tự vẽ lại khi có ảnh.
class ServiceImages {
  ServiceImages._();

  static final ValueNotifier<Map<String, String?>> byName = ValueNotifier(const {});

  static String _key(String name) => name.trim().toLowerCase();

  static void update(Iterable<({String name, String? iconUrl})> items) {
    byName.value = {for (final s in items) _key(s.name): s.iconUrl};
  }

  static String? of(String name) => byName.value[_key(name)];

  static bool get isEmpty => byName.value.isEmpty;
}
