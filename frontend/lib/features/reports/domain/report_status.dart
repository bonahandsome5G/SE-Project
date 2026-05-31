import 'package:flutter/material.dart';

class ReportStatus {
  static String label(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'queued':
        return 'Queued';
      case 'accepted':
        return 'Diterima';
      case 'rejected':
        return 'Ditolak';
      case 'in_progress':
        return 'Diproses';
      case 'resolved':
        return 'Selesai';
      case 'suspected_spam':
        return 'Dugaan Spam';
      default:
        return status;
    }
  }

  static Color color(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'queued':
        return const Color(0xFF64748B);
      case 'accepted':
        return const Color(0xFF15803D);
      case 'rejected':
        return const Color(0xFFB91C1C);
      case 'in_progress':
        return const Color(0xFF0369A1);
      case 'resolved':
        return const Color(0xFF0F766E);
      case 'suspected_spam':
        return const Color(0xFF7C2D12);
      default:
        return Colors.grey;
    }
  }
}
