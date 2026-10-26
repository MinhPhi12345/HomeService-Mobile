import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/app_scope.dart';
import '../core/geocoding_service.dart';
import '../core/location_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Ảnh nền bản đồ OpenStreetMap: ưu tiên qua Backend (`/api/geo/tiles`, có cache),
/// Backend lỗi thì lấy thẳng từ OpenStreetMap. Không cần API key.
/// Bắt buộc ghi nguồn "© OpenStreetMap contributors".
const _userAgent = 'vn.homeservice.home_service_mobile';

LatLng toLatLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

/// Ảnh nền tự chuyển sang OpenStreetMap trực tiếp nếu Backend không phục vụ được (xem [ApiClient.checkMapTiles]).
Widget _tileLayer(BuildContext context) => ValueListenableBuilder<String>(
  valueListenable: AppScope.api(context).tileUrl,
  builder: (context, url, _) => TileLayer(
    key: ValueKey(url),
    urlTemplate: url,
    userAgentPackageName: _userAgent,
    maxZoom: 19,
  ),
);

Widget _attribution() => RichAttributionWidget(
  alignment: AttributionAlignment.bottomLeft,
  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
);

class MapPin {
  const MapPin({
    required this.point,
    this.icon = Icons.location_on_rounded,
    this.color = AppColors.danger,
    this.label,
  });

  final GeoPoint point;
  final IconData icon;
  final Color color;
  final String? label;
}

/// Bản đồ nhỏ hiển thị 1 hoặc nhiều điểm.
class PinMap extends StatelessWidget {
  const PinMap({
    super.key,
    required this.pins,
    this.height = 200,
    this.zoom = 15,
    this.interactive = true,
    this.controller,
  });

  final List<MapPin> pins;
  final double height;
  final double zoom;
  final bool interactive;
  final MapController? controller;

  @override
  Widget build(BuildContext context) {
    final center = pins.isEmpty ? GeoPoint.hcmc : pins.first.point;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: toLatLng(center),
            initialZoom: zoom,
            interactionOptions: InteractionOptions(
              flags: interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            _tileLayer(context),
            MarkerLayer(
              markers: [
                for (final pin in pins)
                  Marker(
                    point: toLatLng(pin.point),
                    width: 140,
                    height: 64,
                    alignment: Alignment.topCenter,
                    child: _PinMarker(pin: pin),
                  ),
              ],
            ),
            _attribution(),
          ],
        ),
      ),
    );
  }
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (pin.label != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: Text(
              pin.label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        Icon(pin.icon, color: pin.color, size: 36),
      ],
    );
  }
}

/// Kết quả trang chọn vị trí: toạ độ + địa chỉ tra được (có thể null nếu mất mạng).
class PickedLocation {
  const PickedLocation({required this.point, this.address});

  final GeoPoint point;
  final String? address;
}

/// Trang chọn vị trí: tìm theo địa chỉ, kéo bản đồ để ghim ở giữa, hoặc dùng GPS.
/// Địa chỉ của điểm ghim được tra tự động và hiện ở dưới.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initial,
    this.initialAddress,
    this.title = 'Chọn vị trí trên bản đồ',
  });

  final GeoPoint? initial;
  final String? initialAddress;
  final String title;

  static Future<PickedLocation?> open(
    BuildContext context, {
    GeoPoint? initial,
    String? initialAddress,
    String title = 'Chọn vị trí trên bản đồ',
  }) {
    return Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initial: initial,
          initialAddress: initialAddress,
          title: title,
        ),
      ),
    );
  }

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _controller = MapController();
  final _search = TextEditingController();
  late LatLng _center = toLatLng(widget.initial ?? GeoPoint.hcmc);
  String? _address;
  bool _resolving = false;
  bool _locating = false;
  bool _searching = false;
  List<PlaceResult> _results = const [];
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _address = widget.initialAddress;
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useMyLocation());
    } else if (_address == null) {
      _resolveAddress();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onMoved(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (!hasGesture) return;
    if (_results.isNotEmpty) setState(() => _results = const []);
    _debounce?.cancel();
    setState(() => _resolving = true);
    _debounce = Timer(const Duration(milliseconds: 900), _resolveAddress);
  }

  Future<void> _resolveAddress() async {
    final id = ++_requestId;
    setState(() => _resolving = true);
    final address = await GeocodingService.reverse(
      AppScope.api(context),
      GeoPoint(_center.latitude, _center.longitude),
    );
    if (!mounted || id != _requestId) return; // người dùng đã kéo sang chỗ khác
    setState(() {
      _address = address;
      _resolving = false;
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final point = await LocationService.current();
      _moveTo(toLatLng(point));
      await _resolveAddress();
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _moveTo(LatLng target, {double zoom = 17}) {
    _controller.move(target, zoom);
    setState(() => _center = target);
  }

  Future<void> _runSearch() async {
    FocusScope.of(context).unfocus();
    final q = _search.text.trim();
    if (q.length < 3) return;
    setState(() => _searching = true);
    final results = await GeocodingService.search(AppScope.api(context), q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
    if (results.isEmpty) {
      showSnack(
        context,
        'Không tìm thấy địa chỉ. Hãy thử thêm tên phường/quận, hoặc kéo bản đồ để ghim.',
        error: true,
      );
    }
  }

  void _pickResult(PlaceResult result) {
    _requestId++; // bỏ qua kết quả tra ngược đang chờ
    _moveTo(toLatLng(result.point));
    setState(() {
      _address = result.address;
      _resolving = false;
      _results = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hsAppBar(widget.title),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: _onMoved,
            ),
            children: [_tileLayer(context), _attribution()],
          ),
          // Ghim cố định ở giữa; mũi ghim chạm đúng tâm bản đồ.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    decoration: appInputDecoration(
                      hint: 'Tìm địa chỉ, ví dụ: 12 Nguyễn Huệ Quận 1',
                      icon: Icons.search_rounded,
                      suffix: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              onPressed: _runSearch,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final r = _results[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.place_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            r.title ?? r.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: r.title == null
                              ? null
                              : Text(
                                  r.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => _pickResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'my-location',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
              onPressed: _locating ? null : _useMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.place_rounded, color: AppColors.danger),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _resolving
                      ? 'Đang tìm địa chỉ…'
                      : _address ??
                            'Chưa xác định được địa chỉ – bạn vẫn có thể xác nhận và tự nhập địa chỉ.',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          PrimaryButton(
            label: 'Xác nhận vị trí này',
            icon: Icons.check_rounded,
            onPressed: _resolving
                ? null
                : () => Navigator.of(context).pop(
                    PickedLocation(
                      point: GeoPoint(_center.latitude, _center.longitude),
                      address: _address,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Mở app Google Maps chỉ đường (link thường, không tốn phí API).
Future<void> openDirections(
  BuildContext context,
  double latitude,
  double longitude,
) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
  );
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showSnack(context, 'Không mở được ứng dụng bản đồ.', error: true);
  }
}

Future<void> callPhone(BuildContext context, String phone) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri(scheme: 'tel', path: phone));
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showSnack(context, 'Không mở được trình gọi điện.', error: true);
  }
}
