import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/app_feedback.dart';
import '../data/location_lookup_service.dart';
import '../data/reports_repository.dart';
import '../domain/indonesia_bounds.dart';
import '../domain/report.dart';
import '../domain/report_category.dart';
import '../domain/report_comment.dart';
import 'widgets/report_status_chip.dart';

enum _ReportMapFilter { semua, selesai, belumSelesai }

class CommunityMapTab extends StatefulWidget {
  const CommunityMapTab({super.key, required this.onCreateReport});

  final Future<void> Function() onCreateReport;

  @override
  State<CommunityMapTab> createState() => _CommunityMapTabState();
}

class _CommunityMapTabState extends State<CommunityMapTab> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _locationLookupService = LocationLookupService();
  final _reportsRepository = ReportsRepository();

  Timer? _searchDebounce;
  List<LocationSearchResult> _suggestions = [];
  List<Report> _reports = [];
  Report? _selectedReport;
  LatLng _center = IndonesiaBounds.center;
  bool _isSearching = false;
  bool _isLoadingReports = true;
  bool _isShowingNearbyList = false;
  _ReportMapFilter _mapFilter = _ReportMapFilter.belumSelesai;

  List<Report> get _filteredReports => switch (_mapFilter) {
    _ReportMapFilter.semua => _reports,
    _ReportMapFilter.selesai => _reports
        .where((report) => report.status == 'resolved')
        .toList(),
    _ReportMapFilter.belumSelesai => _reports
        .where((report) => report.status != 'resolved')
        .toList(),
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_queueSuggestions);
    _loadNearbyReports(_center);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _queueSuggestions() {
    _searchDebounce?.cancel();

    final query = _searchController.text.trim();
    if (query.length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _isSearching = true);
      try {
        final results = await _locationLookupService.searchLocations(query);
        if (!mounted || _searchController.text.trim() != query) return;
        setState(() => _suggestions = results);
      } catch (error) {
        if (mounted) showAppSnackBar(context, error.toString());
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _loadNearbyReports(LatLng point) async {
    setState(() => _isLoadingReports = true);

    try {
      final reports = await _reportsRepository.fetchNearbyReports(
        latitude: point.latitude,
        longitude: point.longitude,
        radiusKm: 5,
      );
      if (mounted) {
        setState(() {
          _center = point;
          _reports = reports;
        });
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Gagal mengambil laporan sekitar: $error');
      }
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _selectSuggestion(LocationSearchResult result) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.text = result.name.split(',').first.trim();
      _suggestions = [];
    });
    _mapController.move(result.point, 14);
    await _loadNearbyReports(result.point);
  }

  Future<void> _searchCurrentMapArea() async {
    final point = _mapController.camera.center;
    if (!IndonesiaBounds.contains(point)) {
      showAppSnackBar(context, 'Area peta harus berada di Indonesia.');
      return;
    }
    await _loadNearbyReports(point);
  }

  void _openNearbyReportsSheet() {
    setState(() {
      _selectedReport = null;
      _isShowingNearbyList = true;
    });
  }

  void _updateReport(Report updatedReport) {
    setState(() {
      _reports = _reports
          .map(
            (report) => report.id == updatedReport.id ? updatedReport : report,
          )
          .toList();
      _selectedReport = _selectedReport?.id == updatedReport.id
          ? updatedReport
          : _selectedReport;
    });
  }

  void _openReportSheet(Report report) {
    setState(() {
      _isShowingNearbyList = false;
      _selectedReport = report;
    });
  }

  Future<void> _createReportAndRefresh() async {
    await widget.onCreateReport();
    if (!mounted) return;
    await _loadNearbyReports(_mapController.camera.center);
  }

  void _closePanels() {
    setState(() {
      _selectedReport = null;
      _isShowingNearbyList = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 5,
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(
                IndonesiaBounds.southWest,
                IndonesiaBounds.northEast,
              ),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: AppConfig.mapUserAgent,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _center,
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.adjust,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                ..._filteredReports.map(
                  (report) => Marker(
                    point: LatLng(report.latitude, report.longitude),
                    width: 46,
                    height: 46,
                    child: IconButton.filled(
                      onPressed: () => _openReportSheet(report),
                      icon: const Icon(Icons.report_problem_outlined),
                      tooltip: 'Buka laporan',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 14,
          child: Column(
            children: [
              _MapSearchBar(
                controller: _searchController,
                isSearching: _isSearching,
                onSearchArea: _searchCurrentMapArea,
              ),
              const SizedBox(height: 8),
              _MapStatusFilter(
                value: _mapFilter,
                onChanged: (value) {
                  setState(() {
                    _mapFilter = value;
                    if (_selectedReport != null &&
                        !_filteredReports.any(
                          (report) => report.id == _selectedReport!.id,
                        )) {
                      _selectedReport = null;
                    }
                  });
                },
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SearchSuggestionPanel(
                  suggestions: _suggestions,
                  onSelected: _selectSuggestion,
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 16,
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoadingReports ? null : _openNearbyReportsSheet,
                  icon: _isLoadingReports
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar),
                  label: Text(
                    _isLoadingReports
                        ? 'Memuat laporan...'
                        : '${_filteredReports.length} laporan sekitar',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                onPressed: _createReportAndRefresh,
                tooltip: 'Buat laporan',
                child: const Icon(Icons.add_location_alt_outlined),
              ),
            ],
          ),
        ),
        if (_isShowingNearbyList)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _NearbyReportsSheet(
              reports: _reports,
              filter: _mapFilter,
              onClose: _closePanels,
              onReportSelected: (report) {
                _mapController.move(
                  LatLng(report.latitude, report.longitude),
                  16,
                );
                _openReportSheet(report);
              },
            ),
          ),
        if (_selectedReport != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ReportMapSheet(
              initialReport: _selectedReport!,
              repository: _reportsRepository,
              onClose: _closePanels,
              onReportChanged: _updateReport,
            ),
          ),
      ],
    );
  }
}

class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar({
    required this.controller,
    required this.isSearching,
    required this.onSearchArea,
  });

  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onSearchArea;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 52, child: Icon(Icons.search, size: 24)),
            Expanded(
              child: TextField(
                controller: controller,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Cari area laporan',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            SizedBox(
              width: 52,
              child: Center(
                child: isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: onSearchArea,
                        icon: const Icon(Icons.travel_explore),
                        tooltip: 'Cari di area peta',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSuggestionPanel extends StatelessWidget {
  const _SearchSuggestionPanel({
    required this.suggestions,
    required this.onSelected,
  });

  final List<LocationSearchResult> suggestions;
  final ValueChanged<LocationSearchResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 190),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return InkWell(
              onTap: () => onSelected(suggestion),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 52,
                      child: Icon(Icons.place_outlined),
                    ),
                    Expanded(
                      child: Text(
                        suggestion.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MapStatusFilter extends StatelessWidget {
  const _MapStatusFilter({required this.value, required this.onChanged});

  final _ReportMapFilter value;
  final ValueChanged<_ReportMapFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: SegmentedButton<_ReportMapFilter>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        segments: const [
          ButtonSegment(value: _ReportMapFilter.semua, label: Text('Semua')),
          ButtonSegment(
            value: _ReportMapFilter.belumSelesai,
            label: Text('Belum selesai'),
          ),
          ButtonSegment(
            value: _ReportMapFilter.selesai,
            label: Text('Selesai'),
          ),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _NearbyReportsSheet extends StatefulWidget {
  const _NearbyReportsSheet({
    required this.reports,
    required this.filter,
    required this.onClose,
    required this.onReportSelected,
  });

  final List<Report> reports;
  final _ReportMapFilter filter;
  final VoidCallback onClose;
  final ValueChanged<Report> onReportSelected;

  @override
  State<_NearbyReportsSheet> createState() => _NearbyReportsSheetState();
}

class _NearbyReportsSheetState extends State<_NearbyReportsSheet> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final statusFilteredReports = switch (widget.filter) {
      _ReportMapFilter.semua => widget.reports,
      _ReportMapFilter.selesai => widget.reports
          .where((report) => report.status == 'resolved')
          .toList(),
      _ReportMapFilter.belumSelesai => widget.reports
          .where((report) => report.status != 'resolved')
          .toList(),
    };
    final filteredReports = _selectedCategoryId == null
        ? statusFilteredReports
        : statusFilteredReports
              .where((report) => report.categoryId == _selectedCategoryId)
              .toList();

    return SizedBox(
      width: double.infinity,
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${filteredReports.length} laporan sekitar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Tutup',
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Filter kategori',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Semua kategori'),
                ),
                ...reportCategories.map(
                  (category) => DropdownMenuItem<int?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedCategoryId = value);
              },
            ),
            const SizedBox(height: 12),
            if (filteredReports.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'Tidak ada laporan untuk filter ini.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            else
              ...filteredReports.map(
                (report) => _NearbyReportTile(
                  report: report,
                  onTap: () => widget.onReportSelected(report),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NearbyReportTile extends StatelessWidget {
  const _NearbyReportTile({required this.report, required this.onTap});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = report.description.trim().isEmpty
        ? 'Tidak ada deskripsi.'
        : report.description;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  report.photoUrl,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 70,
                    height: 70,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ReportStatusChip(status: report.status),
                        if (report.isResolved) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.thumb_up_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text('${report.upvoteCount}'),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text('${report.commentCount}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportMapSheet extends StatefulWidget {
  const _ReportMapSheet({
    required this.initialReport,
    required this.repository,
    required this.onClose,
    required this.onReportChanged,
  });

  final Report initialReport;
  final ReportsRepository repository;
  final VoidCallback onClose;
  final ValueChanged<Report> onReportChanged;

  @override
  State<_ReportMapSheet> createState() => _ReportMapSheetState();
}

class _ReportMapSheetState extends State<_ReportMapSheet> {
  final _commentController = TextEditingController();
  late Report _report = widget.initialReport;
  late Future<List<ReportComment>> _commentsFuture;
  bool _isSendingComment = false;
  bool _isTogglingUpvote = false;
  bool _isFlagging = false;

  @override
  void initState() {
    super.initState();
    _commentsFuture = widget.repository.fetchReportComments(_report.id ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleUpvote() async {
    if (_report.id == null || _isTogglingUpvote) return;
    setState(() => _isTogglingUpvote = true);

    try {
      final result = await widget.repository.toggleReportUpvote(_report.id!);
      final updatedReport = _report.copyWith(
        upvoteCount: result.upvoteCount,
        hasUpvoted: result.hasUpvoted,
      );
      setState(() => _report = updatedReport);
      widget.onReportChanged(updatedReport);
    } finally {
      if (mounted) setState(() => _isTogglingUpvote = false);
    }
  }

  Future<void> _addComment() async {
    final body = _commentController.text.trim();
    if (_report.id == null || body.length < 3) return;

    setState(() => _isSendingComment = true);
    try {
      await widget.repository.addReportComment(
        reportId: _report.id!,
        body: body,
      );
      _commentController.clear();
      final updatedReport = _report.copyWith(
        commentCount: _report.commentCount + 1,
      );
      setState(() {
        _report = updatedReport;
        _commentsFuture = widget.repository.fetchReportComments(_report.id!);
      });
      widget.onReportChanged(updatedReport);
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _flagReport() async {
    if (_report.id == null || _isFlagging) return;
    setState(() => _isFlagging = true);

    try {
      await widget.repository.flagReport(
        reportId: _report.id!,
        reason: 'Dilaporkan oleh warga dari peta komunitas',
      );
      if (mounted) showAppSnackBar(context, 'Laporan dikirim untuk ditinjau.');
    } finally {
      if (mounted) setState(() => _isFlagging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final description = _report.description.trim().isEmpty
        ? 'Tidak ada deskripsi.'
        : _report.description;

    return SizedBox(
      width: double.infinity,
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Tutup',
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _report.photoUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 42),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _report.categoryName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ReportStatusChip(status: _report.status),
              if (_report.isResolved) ...[
                const SizedBox(height: 10),
                _ResolvedProofSection(report: _report),
              ],
              const SizedBox(height: 12),
              Text(description),
              const SizedBox(height: 14),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _isTogglingUpvote ? null : _toggleUpvote,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: Icon(
                      _report.hasUpvoted
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                    ),
                    label: Text('${_report.upvoteCount}'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isFlagging ? null : _flagReport,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_report.commentCount} komentar',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLength: 280,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Tambah komentar',
                  suffixIcon: IconButton(
                    onPressed: _isSendingComment ? null : _addComment,
                    icon: _isSendingComment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<ReportComment>>(
                future: _commentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Komentar belum bisa dimuat.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    );
                  }

                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Belum ada komentar.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: comments
                        .map(
                          (comment) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(comment.authorName),
                            subtitle: Text(comment.body),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolvedProofSection extends StatelessWidget {
  const _ResolvedProofSection({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final proofUrl = report.resolutionProofPhotoUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(
          alpha: 0.42,
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
                  'Laporan ini sudah selesai',
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
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
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
