import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'citizen_report_screen.dart';
import 'dart:developer' as developer;

class CitizenMenuScreen extends StatefulWidget {
  const CitizenMenuScreen({super.key});

  @override
  State<CitizenMenuScreen> createState() => _CitizenMenuScreenState();
}

class _CitizenMenuScreenState extends State<CitizenMenuScreen> {
  List<Map<String, dynamic>> _reports = []; // Menyimpan data laporan secara aktif
  bool _isLoading = true; // State loading indikator

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  // Fungsi mengambil data laporan dari Supabase secara reaktif
  Future<void> _fetchReports() async {
    try {
      setState(() => _isLoading = true);
      
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id;
      
      if (userId == null) {
        developer.log('Error: userId is null');
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _reports = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
      
    } catch (e) {
      developer.log('Error fetching reports: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data: $e')),
        );
      }
    }
  }

  // Fungsi cerdas mencari nama jalan terdekat
  Future<String> _getNearestRoad(double lat, double lon) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'LaporInfrastrukturApp/1.0');
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        
        if (address != null) {
          final jalanTerdekat = address['road'] ?? 
                                address['pedestrian'] ?? 
                                address['footway'] ??
                                address['path'] ??
                                address['amenity'] ?? 
                                address['building'] ?? 
                                address['neighbourhood'] ?? 
                                address['suburb'];
          if (jalanTerdekat != null) return jalanTerdekat.toString();
        }
        
        if (data['display_name'] != null) {
          final parts = data['display_name'].toString().split(',');
          if (parts.isNotEmpty) return parts.first.trim();
        }
      }
    } catch (e) {
      developer.log('Error reverse geocoding: $e');
    } finally {
      client.close();
    }
    return 'Sekitar wilayah ini (Nama jalan tidak terdaftar)';
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal logout: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'Menunggu';
      case 'accepted': return 'Diterima';
      case 'rejected': return 'Ditolak';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    // PopScope digunakan untuk mematikan tombol "Back" fisik HP Android
    // sehingga pengguna wajib keluar menggunakan tombol LOGOUT resmi.
    return PopScope(
      canPop: false, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Menu Utama Warga'),
          automaticallyImplyLeading: false, // 1. MENGHILANGKAN TOMBOL KEMBALI BAWAAN DI KIRI
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: currentUser == null
            ? const Center(child: Text('User tidak teridentifikasi'))
            : Column(
                children: [
                  Container(
                    color: Colors.blue.shade50,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${currentUser.email?.split('@').first ?? 'Pengguna'}!',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CitizenReportScreen()),
                              );
                              _fetchReports(); // Refresh data otomatis setelah membuat laporan
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('BUAT LAPORAN BARU'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 2. JUMLAH LAPORAN SEKARANG OTOMATIS DAN DINAMIS Sesuai Array Data
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Laporan Saya (${_reports.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _fetchReports,
                            child: _reports.isEmpty
                                ? _buildEmptyState()
                                : _buildReportList(),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Belum ada laporan.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Mulai membuat laporan pertama Anda!', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final status = report['status'] ?? 'pending';
        final description = report['description'] ?? 'Tanpa Deskripsi';
        final createdAt = report['created_at'] != null ? DateTime.parse(report['created_at'] as String) : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 2,
          child: InkWell(
            onTap: () => _showReportDetails(context, report),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            if (createdAt != null)
                              Text(
                                '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(status)),
                        ),
                        child: Text(
                          _getStatusLabel(status),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getStatusColor(status)),
                        ),
                      ),
                    ],
                  ),
                  if (report['photo_url'] != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        report['photo_url'],
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image_not_supported),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReportDetails(BuildContext context, Map<String, dynamic> report) {
    final status = report['status'] ?? 'pending';
    final description = report['description'] ?? 'Tanpa Deskripsi';
    final latitude = report['latitude'];
    final longitude = report['longitude'];
    final createdAt = report['created_at'] != null ? DateTime.parse(report['created_at'] as String) : null;

    final double? lat = latitude != null ? (latitude as num).toDouble() : null;
    final double? lon = longitude != null ? (longitude as num).toDouble() : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Laporan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Status: ${_getStatusLabel(status)}', style: TextStyle(fontWeight: FontWeight.w600, color: _getStatusColor(status))),
              const SizedBox(height: 12),
              const Text('Deskripsi:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(description),
              const SizedBox(height: 12),
              const Text('Lokasi Peta:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              
              if (lat != null && lon != null) ...[
                SizedBox(
                  height: 180,
                  width: double.maxFinite,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat, lon),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.example.client_mobile',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lon),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<String>(
                  future: _getNearestRoad(lat, lon),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Mencari jalan terdekat...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.add_road_rounded, size: 16, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Jalan: ${snapshot.data ?? 'Tidak diketahui'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.explore_rounded, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Koordinat: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}', style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: 'monospace'))),
                  ],
                ),
              ] else
                const Text('Lokasi tidak tersedia'),
                
              if (createdAt != null) ...[
                const SizedBox(height: 14),
                const Text('Dibuat:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }
}