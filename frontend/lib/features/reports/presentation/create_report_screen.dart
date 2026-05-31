import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/app_feedback.dart';
import '../data/location_lookup_service.dart';
import '../data/reports_repository.dart';
import '../domain/indonesia_bounds.dart';
import '../domain/report_category.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapKey = GlobalKey();
  final _scrollController = ScrollController();
  final _descriptionController = TextEditingController();
  final _locationSearchController = TextEditingController();
  final _mapController = MapController();
  final _locationLookupService = LocationLookupService();
  final _reportsRepository = ReportsRepository();

  int _categoryId = reportCategories.first.id;
  XFile? _photo;
  Uint8List? _photoPreview;
  Position? _currentPosition;
  LatLng? _selectedLocation;
  List<LocationSearchResult> _locationSearchResults = [];
  Timer? _locationSearchDebounce;
  bool _isApplyingSearchResult = false;
  bool _isLoadingLocation = true;
  bool _isSearchingLocation = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _locationSearchController.addListener(_queueLocationSuggestions);
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _locationSearchDebounce?.cancel();
    _scrollController.dispose();
    _descriptionController.dispose();
    _locationSearchController.dispose();
    super.dispose();
  }

  void _queueLocationSuggestions() {
    if (_isApplyingSearchResult) return;

    _locationSearchDebounce?.cancel();

    final query = _locationSearchController.text.trim();
    if (query.length < 3) {
      if (_locationSearchResults.isNotEmpty) {
        setState(() => _locationSearchResults = []);
      }
      return;
    }

    _locationSearchDebounce = Timer(
      const Duration(milliseconds: 650),
      () => _searchLocation(showEmptyMessage: false, unfocus: false),
    );
  }

  Future<void> _searchLocation({
    bool showEmptyMessage = true,
    bool unfocus = true,
  }) async {
    final query = _locationSearchController.text.trim();
    if (query.length < 3) {
      showAppSnackBar(context, 'Masukkan minimal 3 huruf lokasi.');
      return;
    }

    if (unfocus) FocusScope.of(context).unfocus();
    setState(() => _isSearchingLocation = true);

    try {
      final results = await _locationLookupService.searchLocations(query);
      if (!mounted) return;
      if (_locationSearchController.text.trim() != query) return;
      setState(() => _locationSearchResults = results);

      if (showEmptyMessage && results.isEmpty) {
        showAppSnackBar(
          context,
          'Lokasi tidak ditemukan di wilayah Indonesia.',
        );
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Gagal mencari lokasi: $error');
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  void _selectSearchResult(LocationSearchResult result) {
    _locationSearchDebounce?.cancel();
    _isApplyingSearchResult = true;
    setState(() {
      _selectedLocation = result.point;
      _locationSearchController.text = result.name.split(',').first.trim();
      _locationSearchResults = [];
    });
    _isApplyingSearchResult = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(result.point, 16);
      final mapContext = _mapKey.currentContext;
      if (mapContext != null) {
        Scrollable.ensureVisible(
          mapContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      }
    });
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) showAppSnackBar(context, 'Aktifkan layanan lokasi.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) showAppSnackBar(context, 'Izin lokasi diperlukan.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showAppSnackBar(
            context,
            'Izin lokasi ditolak permanen. Buka pengaturan perangkat.',
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      );

      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      if (!IndonesiaBounds.contains(point)) {
        showAppSnackBar(
          context,
          'Lokasi laporan hanya dapat dipilih di wilayah Indonesia.',
        );
        return;
      }

      setState(() {
        _currentPosition = position;
        _selectedLocation = point;
      });
      _mapController.move(point, 16);
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Gagal mengambil lokasi: $error');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
      maxWidth: 1600,
    );

    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = photo;
      _photoPreview = bytes;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final location = _selectedLocation;
    final photo = _photo;
    final preview = _photoPreview;

    if (location == null) {
      showAppSnackBar(context, 'Pilih lokasi laporan di peta.');
      return;
    }

    if (!IndonesiaBounds.contains(location)) {
      showAppSnackBar(
        context,
        'Lokasi laporan harus berada di wilayah Indonesia.',
      );
      return;
    }

    if (photo == null || preview == null) {
      showAppSnackBar(context, 'Foto kerusakan wajib dilampirkan.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final extension = photo.name.split('.').last;
      await _reportsRepository.createReport(
        NewReportPayload(
          categoryId: _categoryId,
          description: _descriptionController.text.trim(),
          photoBytes: preview,
          photoExtension: extension,
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      );

      if (!mounted) return;
      showAppSnackBar(context, 'Laporan berhasil dikirim.');
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (mounted) showAppSnackBar(context, error.message);
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Gagal mengirim laporan: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedLocation ?? const LatLng(-6.2, 106.816666);

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Laporan')),
      body: AbsorbPointer(
        absorbing: _isSubmitting,
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori kerusakan',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: reportCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _categoryId = value);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 280,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi masalah',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Deskripsi wajib diisi';
                  if (text.length < 12) return 'Deskripsi terlalu pendek';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Lokasi presisi',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchLocation(),
                decoration: InputDecoration(
                  labelText: 'Cari lokasi di Indonesia',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearchingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: _searchLocation,
                          icon: const Icon(Icons.arrow_forward),
                          tooltip: 'Cari lokasi',
                        ),
                ),
              ),
              if (_locationSearchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Saran lokasi',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _LocationSearchResults(
                  results: _locationSearchResults,
                  onSelected: _selectSearchResult,
                ),
              ],
              const SizedBox(height: 10),
              ClipRRect(
                key: _mapKey,
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 280,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15,
                      cameraConstraint: CameraConstraint.contain(
                        bounds: LatLngBounds(
                          IndonesiaBounds.southWest,
                          IndonesiaBounds.northEast,
                        ),
                      ),
                      onTap: (_, point) {
                        if (!IndonesiaBounds.contains(point)) {
                          showAppSnackBar(
                            context,
                            'Pilih titik laporan di wilayah Indonesia.',
                          );
                          return;
                        }
                        setState(() => _selectedLocation = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: AppConfig.mapUserAgent,
                      ),
                      if (_selectedLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation!,
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons.location_pin,
                                size: 42,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedLocation == null
                    ? 'Ketuk peta untuk memilih titik laporan.'
                    : 'Koordinat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isLoadingLocation
                    ? null
                    : () {
                        final position = _currentPosition;
                        if (position == null) {
                          _loadCurrentLocation();
                          return;
                        }
                        final point = LatLng(
                          position.latitude,
                          position.longitude,
                        );
                        if (!IndonesiaBounds.contains(point)) {
                          showAppSnackBar(
                            context,
                            'Lokasi saat ini berada di luar wilayah Indonesia.',
                          );
                          return;
                        }
                        setState(() => _selectedLocation = point);
                        _mapController.move(point, 16);
                      },
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _isLoadingLocation
                      ? 'Mengambil Lokasi...'
                      : 'Gunakan Lokasi Saat Ini',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Foto bukti',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (_photoPreview != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _photoPreview!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(
                  _photo == null ? 'Ambil Foto Kerusakan' : 'Ambil Ulang Foto',
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_isSubmitting ? 'Mengirim...' : 'Kirim Laporan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSearchResults extends StatelessWidget {
  const _LocationSearchResults({
    required this.results,
    required this.onSelected,
  });

  final List<LocationSearchResult> results;
  final ValueChanged<LocationSearchResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: results
            .map(
              (result) => ListTile(
                dense: true,
                leading: const Icon(Icons.place_outlined),
                title: Text(
                  result.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelected(result),
              ),
            )
            .toList(),
      ),
    );
  }
}
