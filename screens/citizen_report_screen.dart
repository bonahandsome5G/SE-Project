import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CitizenReportScreen extends StatefulWidget {
  const CitizenReportScreen({super.key});

  @override
  State<CitizenReportScreen> createState() => _CitizenReportScreenState();
}

class _CitizenReportScreenState extends State<CitizenReportScreen> {
  final _descriptionController = TextEditingController();
  final MapController _mapController = MapController();
  XFile? _selectedImage;
  Position? _currentPosition;
  LatLng? _selectedLocation;
  bool _isLoading = false;
  String _selectedCategory = '1'; // Default: ID untuk Jalan Berlubang

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Fungsi mengambil lokasi GPS Presisi
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Layanan lokasi harus diaktifkan.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Izin lokasi diperlukan untuk peta.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Izin lokasi ditolak permanen. Buka pengaturan perangkat.');
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    );
    if (mounted) {
      setState(() {
        _currentPosition = position;
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
    }
  }

  // Fungsi mengambil foto
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _selectedImage = pickedFile);
    }
  }

  Future<void> _submitReport() async {
    if (_selectedImage == null || _descriptionController.text.isEmpty || _selectedLocation == null) {
      _showSnackBar('Semua data wajib diisi dan lokasi harus dipilih di peta.');
      return;
    }

    setState(() => _isLoading = true);
    final client = Supabase.instance.client;

    try {
      final fileExtension = _selectedImage!.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final Uint8List imageBytes = await _selectedImage!.readAsBytes();

      await client.storage.from('report-photos').uploadBinary(
        fileName,
        imageBytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final String photoUrl = client.storage.from('report-photos').getPublicUrl(fileName);
      final user = client.auth.currentUser;

      await client.from('reports').insert({
        'user_id': user?.id,
        'category_id': int.parse(_selectedCategory),
        'description': _descriptionController.text,
        'photo_url': photoUrl,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan Berhasil Dikirim!'),
        ));
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _descriptionController.clear();
      _selectedImage = null;
      if (_currentPosition != null) {
        _selectedLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        _mapController.move(_selectedLocation!, 15);
      }
    });
  }

  Widget _buildMap() {
    final center = _selectedLocation ?? const LatLng(-6.200000, 106.816666);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 280,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onTap: (tapPosition, point) {
                setState(() => _selectedLocation = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.client_mobile',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedLocation == null
            ? 'Ketuk peta untuk memilih lokasi laporan.'
            : 'Lokasi terpilih: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _currentPosition == null ? null : () {
            setState(() {
              _selectedLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
              _mapController.move(_selectedLocation!, 15);
            });
          },
          icon: const Icon(Icons.my_location),
          label: const Text('Gunakan Lokasi Saat Ini'),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Laporan Warga')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('Jalan Berlubang')),
                    DropdownMenuItem(value: '2', child: Text('Lampu Jalan Mati')),
                  ],
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                  decoration: const InputDecoration(labelText: 'Kategori Kerusakan'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Deskripsi Laporan', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                _buildMap(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_selectedImage == null ? 'Ambil Foto Kerusakan' : 'Foto Berhasil Diambil ✓'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text('KIRIM LAPORAN'),
                )
              ],
            ),
          ),
    );
  }
}