import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/app_feedback.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../features/auth/presentation/auth_screen.dart';
import '../../../shared/widgets/app_section.dart';
import '../data/reports_repository.dart';
import '../domain/report.dart';
import 'community_map_tab.dart';
import 'create_report_screen.dart';
import 'report_detail_screen.dart';
import 'widgets/report_status_chip.dart';

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  final _authRepository = AuthRepository();
  final _reportsRepository = ReportsRepository();

  var _selectedIndex = 0;
  var _isLoadingMine = true;
  List<Report> _myReports = [];

  @override
  void initState() {
    super.initState();
    _loadMyReports();
  }

  Future<void> _loadMyReports() async {
    setState(() => _isLoadingMine = true);

    try {
      final reports = await _reportsRepository.fetchMyReports();
      if (mounted) {
        setState(() => _myReports = reports);
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Gagal mengambil laporan: $error');
    } finally {
      if (mounted) setState(() => _isLoadingMine = false);
    }
  }

  Future<void> _openCreateReport() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateReportScreen()));
    await _loadMyReports();
  }

  Future<void> _logout() async {
    await _authRepository.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Beranda', 'Laporan Saya', 'Akun'];

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[_selectedIndex]),
          automaticallyImplyLeading: false,
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            CommunityMapTab(onCreateReport: _openCreateReport),
            _ReportsTab(
              title: 'Status Laporan (${_myReports.length})',
              reports: _myReports,
              isLoading: _isLoadingMine,
              emptyIcon: Icons.inbox_outlined,
              emptyTitle: 'Belum ada laporan.',
              emptySubtitle: 'Mulai dengan membuat laporan kerusakan pertama.',
              onRefresh: _loadMyReports,
              onOpenReport: _openReportDetail,
            ),
            _AccountTab(onLogout: _logout),
          ],
        ),
        floatingActionButton: _selectedIndex == 1
            ? FloatingActionButton.extended(
                onPressed: _openCreateReport,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Lapor'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Laporan',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Akun',
            ),
          ],
        ),
      ),
    );
  }

  void _openReportDetail(Report report) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportDetailScreen(report: report)),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({
    required this.title,
    required this.reports,
    required this.isLoading,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
    required this.onOpenReport,
  });

  final String title;
  final List<Report> reports;
  final bool isLoading;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;
  final ValueChanged<Report> onOpenReport;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppSection(
            title: title,
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : reports.isEmpty
                ? _EmptyReports(
                    icon: emptyIcon,
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                  )
                : Column(
                    children: reports
                        .map(
                          (report) => _ReportTile(
                            report: report,
                            onTap: () => onOpenReport(report),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.client.auth.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppSection(
          title: 'Profil',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccountLine(
                icon: Icons.mail_outline,
                label: 'Email',
                value: user?.email ?? 'Tidak diketahui',
              ),
              const SizedBox(height: 12),
              _AccountLine(
                icon: Icons.badge_outlined,
                label: 'Peran',
                value: 'Warga',
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
        AppSection(
          title: 'Jam Layanan',
          child: const Text(
            'Laporan di luar jam 09:00-17:00 tetap diterima dan masuk antrean hari kerja berikutnya.',
          ),
        ),
      ],
    );
  }
}

class _AccountLine extends StatelessWidget {
  const _AccountLine({
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
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.onTap});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final createdAt = report.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  report.photoUrl,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 76,
                    height: 76,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (createdAt != null)
                      Text(
                        '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    ReportStatusChip(status: report.status),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 420,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
