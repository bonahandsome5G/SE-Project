import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../domain/indonesia_bounds.dart';

class LocationSearchResult {
  const LocationSearchResult({required this.name, required this.point});

  final String name;
  final LatLng point;
}

class LocationLookupException implements Exception {
  const LocationLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationLookupService {
  Future<List<LocationSearchResult>> searchLocations(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];

    final client = HttpClient();

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': trimmedQuery,
        'limit': '6',
        'addressdetails': '1',
        'countrycodes': 'id',
        'bounded': '1',
        'viewbox':
            '${IndonesiaBounds.southWest.longitude},${IndonesiaBounds.northEast.latitude},${IndonesiaBounds.northEast.longitude},${IndonesiaBounds.southWest.latitude}',
      });
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'LaporInfrastrukturApp/1.0',
      );
      final response = await request.close();

      if (response.statusCode == 429) {
        throw const LocationLookupException(
          'Layanan pencarian lokasi sedang dibatasi. Coba lagi sebentar.',
        );
      }

      if (response.statusCode >= 500) {
        throw const LocationLookupException(
          'Layanan pencarian lokasi sedang bermasalah. Coba lagi nanti.',
        );
      }

      if (response.statusCode != 200) {
        throw const LocationLookupException('Gagal mencari lokasi.');
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as List<dynamic>;

      return data
          .whereType<Map<String, dynamic>>()
          .map(_parseSearchResult)
          .whereType<LocationSearchResult>()
          .where((result) => IndonesiaBounds.contains(result.point))
          .toList();
    } catch (error) {
      developer.log('Location search failed: $error');
      if (error is LocationLookupException) {
        rethrow;
      }
      return [];
    } finally {
      client.close();
    }
  }

  Future<String> getNearestRoad(double latitude, double longitude) async {
    final client = HttpClient();

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'LaporInfrastrukturApp/1.0',
      );
      final response = await request.close();

      if (response.statusCode != 200) {
        return 'Nama jalan belum tersedia';
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      final roadName =
          address?['road'] ??
          address?['pedestrian'] ??
          address?['footway'] ??
          address?['path'] ??
          address?['neighbourhood'] ??
          address?['suburb'];

      if (roadName != null) {
        return roadName.toString();
      }

      final displayName = data['display_name']?.toString();
      if (displayName != null && displayName.isNotEmpty) {
        return displayName.split(',').first.trim();
      }
    } catch (error) {
      developer.log('Reverse geocoding failed: $error');
    } finally {
      client.close();
    }

    return 'Sekitar titik laporan';
  }

  LocationSearchResult? _parseSearchResult(Map<String, dynamic> item) {
    final latitude = double.tryParse(item['lat']?.toString() ?? '');
    final longitude = double.tryParse(item['lon']?.toString() ?? '');
    final displayName = item['display_name']?.toString();

    if (latitude == null ||
        longitude == null ||
        displayName == null ||
        displayName.isEmpty) {
      return null;
    }

    return LocationSearchResult(
      name: displayName,
      point: LatLng(latitude, longitude),
    );
  }
}
