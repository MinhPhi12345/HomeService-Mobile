import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/app_scope.dart';
import '../core/config.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Chọn ảnh (camera / thư viện), nén về JPG rồi tải lên `POST /api/uploads`.
/// Trả về URL ảnh, hoặc null nếu người dùng bỏ qua.
Future<String?> pickAndUploadPhoto(
  BuildContext context, {
  bool cameraOnly = false,
}) async {
  final api = AppScope.api(context);
  var source = ImageSource.camera;
  if (!cameraOnly) {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Chụp ảnh'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Chọn từ thư viện'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return null;
    source = picked;
  }
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  if (file == null) return null;
  return api.uploadImage(file.path);
}

/// Ô chọn 1 ảnh (ảnh CCCD, ảnh trước/sau khi làm...).
class PhotoSlot extends StatefulWidget {
  const PhotoSlot({
    super.key,
    required this.url,
    required this.onChanged,
    this.label = 'Thêm ảnh',
    this.height = 150,
    this.cameraOnly = false,
  });

  final String? url;
  final ValueChanged<String?> onChanged;
  final String label;
  final double height;
  final bool cameraOnly;

  @override
  State<PhotoSlot> createState() => _PhotoSlotState();
}

class _PhotoSlotState extends State<PhotoSlot> {
  bool _uploading = false;

  Future<void> _pick() async {
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadPhoto(
        context,
        cameraOnly: widget.cameraOnly,
      );
      if (url != null) widget.onChanged(url);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = AppConfig.mediaUrl(widget.url);
    return SizedBox(
      height: widget.height,
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _uploading ? null : _pick,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.muted,
                  ),
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.label,
                      style: AppText.label.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              if (_uploading)
                Container(
                  color: Colors.white.withValues(alpha: 0.7),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              if (image != null && !_uploading)
                Positioned(
                  right: 6,
                  top: 6,
                  child: _RoundIcon(
                    icon: Icons.close_rounded,
                    onTap: () => widget.onChanged(null),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lưới nhiều ảnh (ảnh khiếu nại 1–5 ảnh).
class PhotoGrid extends StatefulWidget {
  const PhotoGrid({
    super.key,
    required this.urls,
    required this.onChanged,
    this.max = 5,
  });

  final List<String> urls;
  final ValueChanged<List<String>> onChanged;
  final int max;

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  bool _uploading = false;

  Future<void> _add() async {
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadPhoto(context);
      if (url != null) widget.onChanged([...widget.urls, url]);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 92.0;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final url in widget.urls)
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(
                    AppConfig.mediaUrl(url) ?? url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        Container(color: AppColors.primarySoft),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: _RoundIcon(
                    icon: Icons.close_rounded,
                    onTap: () => widget.onChanged(
                      widget.urls.where((u) => u != url).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (widget.urls.length < widget.max)
          SizedBox(
            width: size,
            height: size,
            child: Material(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: _uploading ? null : _add,
                child: Center(
                  child: _uploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_a_photo_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.urls.length}/${widget.max}',
                              style: AppText.small,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
