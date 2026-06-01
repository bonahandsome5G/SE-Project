import 'package:flutter/material.dart';

import '../data/location_lookup_service.dart';
import '../domain/report.dart';
import 'widgets/report_status_chip.dart';
import 'widgets/static_report_map.dart';

class ReportDetailScreen extends StatelessWidget {
  ReportDetailScreen({
    super.key,
    required this.report,
  });

  final Report report;
  final LocationLookupService _locationLookupService = LocationLookupService();

  @override
  Widget build(BuildContext context) {
    final createdAt = report.createdAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Laporan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              report.photoUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 220,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ReportStatusChip(status: report.status),
              if (report.isResolved) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.verified_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
              const Spacer(),
              if (createdAt != null)
                Text(
                  '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (report.isResolved) ...[
            _ResolutionProofCard(report: report),
            const SizedBox(height: 18),
          ],
          Text(
            'Deskripsi',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(report.description),
          const SizedBox(height: 18),
          Text(
            'Lokasi',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          StaticReportMap(
            latitude: report.latitude,
            longitude: report.longitude,
          ),
          const SizedBox(height: 10),
          FutureBuilder<String>(
            future: _locationLookupService.getNearestRoad(
              report.latitude,
              report.longitude,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Mencari nama jalan...'),
                  ],
                );
              }

              return _DetailLine(
                icon: Icons.add_road_outlined,
                label: 'Jalan',
                value: snapshot.data ?? 'Tidak diketahui',
              );
            },
          ),
          const SizedBox(height: 8),
          _DetailLine(
            icon: Icons.explore_outlined,
            label: 'Koordinat',
            value:
                '${report.latitude.toStringAsFixed(6)}, ${report.longitude.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 18),
          Text(
            report.isResolved
                ? 'Laporan telah ditandai selesai oleh petugas Dishub.'
                : 'Pembaruan status akan muncul setelah Dishub memeriksa laporan.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ResolutionProofCard extends StatelessWidget {
  const _ResolutionProofCard({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final proofUrl = report.resolutionProofPhotoUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(
          alpha: 0.4,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bukti laporan selesai',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (proofUrl != null && proofUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                proofUrl,
                width: double.infinity,
                height: 190,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 190,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ],
          if (report.resolutionNote?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(report.resolutionNote!),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
