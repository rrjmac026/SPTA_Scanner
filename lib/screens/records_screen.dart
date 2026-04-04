import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../helpers/database_helper.dart';
import '../helpers/export_helper.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<StudentPaymentInfo> _infos = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String _searchQuery = '';
  String _selectedGradeFilter = 'All';
  String _selectedStatusFilter = 'All';

  final List<String> _gradeFilters = [
    'All', 'Grade 7', 'Grade 8', 'Grade 9',
    'Grade 10', 'Grade 11', 'Grade 12',
  ];
  final List<String> _statusFilters = ['All', 'Fully Paid', 'Partial', 'Unpaid'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final infos = await _db.getAllStudentPaymentInfos();
    if (mounted) setState(() { _infos = infos; _isLoading = false; });
  }

  List<StudentPaymentInfo> get _filtered {
    return _infos.where((info) {
      final matchGrade = _selectedGradeFilter == 'All' ||
          info.student.grade == _selectedGradeFilter;
      final matchStatus = _selectedStatusFilter == 'All' ||
          info.paymentStatus == _selectedStatusFilter;
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          info.student.name.toLowerCase().contains(q) ||
          info.student.lrn.contains(q);
      return matchGrade && matchStatus && matchSearch;
    }).toList();
  }

  String _formatDate(String dateStr) {
    try {
      return DateFormat('MMM d, yyyy  h:mm a').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      final list = _filtered.isEmpty ? _infos : _filtered;
      final file = await ExportHelper.exportToExcel(list);
      setState(() => _isExporting = false);
      if (mounted) _showExportSuccess(file, 'Excel');
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) _showExportError(e.toString());
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final list = _filtered.isEmpty ? _infos : _filtered;
      final file = await ExportHelper.exportToPdf(list);
      setState(() => _isExporting = false);
      if (mounted) _showExportSuccess(file, 'PDF');
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) _showExportError(e.toString());
    }
  }

  void _showExportSuccess(File file, String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(
                type == 'Excel'
                    ? Icons.table_chart_rounded
                    : Icons.picture_as_pdf_rounded,
                color: const Color(0xFF16A34A),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text('$type Exported!',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14532D))),
            const SizedBox(height: 6),
            Text(file.path.split('/').last,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      OpenFilex.open(file.path);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Share.shareXFiles([XFile(file.path)],
                          subject: 'SPTA Payment Records');
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExportError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Export failed: $error'),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showExportOptions() {
    final count = _filtered.isEmpty ? _infos.length : _filtered.length;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export Records',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14532D))),
            const SizedBox(height: 4),
            Text('Exporting $count records',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 20),
            _exportTile(
              icon: Icons.table_chart_rounded,
              color: const Color(0xFF16A34A),
              bgColor: const Color(0xFFDCFCE7),
              title: 'Export as Excel (.xlsx)',
              subtitle: 'Full spreadsheet with payment details',
              onTap: () { Navigator.pop(context); _exportExcel(); },
            ),
            const SizedBox(height: 12),
            _exportTile(
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFDC2626),
              bgColor: const Color(0xFFFEE2E2),
              title: 'Export as PDF',
              subtitle: 'Printable report with grade summary',
              onTap: () { Navigator.pop(context); _exportPdf(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _exportTile({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color)),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    late Color bg, text;
    late IconData icon;
    switch (status) {
      case 'Fully Paid':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        icon = Icons.check_circle_rounded;
        break;
      case 'Partial':
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFFF97316);
        icon = Icons.pending_rounded;
        break;
      default:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: text, size: 12),
          const SizedBox(width: 4),
          Text(status,
              style: TextStyle(
                  color: text, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalCollected = filtered.fold<double>(0, (s, i) => s + i.amountPaid);
    final fullyPaidCount = filtered.where((i) => i.isFullyPaid).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14532D),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Records',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text('${_infos.length} students registered',
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: _infos.isEmpty ? null : _showExportOptions,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + filter bar
          Container(
            color: const Color(0xFF14532D),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or LRN...',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.6), size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _gradeFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => _filterChip(
                        _gradeFilters[i], _selectedGradeFilter,
                        () => setState(() => _selectedGradeFilter = _gradeFilters[i])),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => _filterChip(
                        _statusFilters[i], _selectedStatusFilter,
                        () => setState(() => _selectedStatusFilter = _statusFilters[i])),
                  ),
                ),
              ],
            ),
          ),

          // Stats strip
          if (!_isLoading && _infos.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _statItem('${filtered.length}', 'Students',
                      Icons.people_alt_rounded, const Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 28, color: Colors.grey[200]),
                  const SizedBox(width: 8),
                  _statItem('$fullyPaidCount', 'Fully Paid',
                      Icons.verified_rounded, const Color(0xFF14532D)),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 28, color: Colors.grey[200]),
                  const SizedBox(width: 8),
                  _statItem(
                      '₱${totalCollected.toStringAsFixed(0)}',
                      'Collected',
                      Icons.payments_rounded,
                      const Color(0xFF0D9488)),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF16A34A)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty &&
                                      _selectedGradeFilter == 'All' &&
                                      _selectedStatusFilter == 'All'
                                  ? Icons.people_outline_rounded
                                  : Icons.search_off_rounded,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty &&
                                      _selectedGradeFilter == 'All' &&
                                      _selectedStatusFilter == 'All'
                                  ? 'No records yet'
                                  : 'No results found',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final info = filtered[i];
                          final s = info.student;
                          final pct = info.totalFee > 0
                              ? (info.amountPaid / info.totalFee).clamp(0.0, 1.0)
                              : 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Center(
                                          child: Text('${i + 1}',
                                              style: const TextStyle(
                                                  color: Color(0xFF16A34A),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13)),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(s.name,
                                                style: const TextStyle(
                                                    color: Color(0xFF14532D),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14)),
                                            const SizedBox(height: 1),
                                            Text('LRN: ${s.lrn}',
                                                style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 11,
                                                    fontFamily: 'monospace')),
                                          ],
                                        ),
                                      ),
                                      _statusChip(info.paymentStatus),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      if (s.grade.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Text(s.grade,
                                              style: const TextStyle(
                                                  color: Color(0xFF16A34A),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        _formatDate(s.createdAt),
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 10),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      Expanded(
                                          child: _miniStat(
                                              'Total Fee',
                                              '₱${info.totalFee.toStringAsFixed(2)}',
                                              const Color(0xFF64748B))),
                                      Expanded(
                                          child: _miniStat(
                                              'Paid',
                                              '₱${info.amountPaid.toStringAsFixed(2)}',
                                              const Color(0xFF16A34A))),
                                      Expanded(
                                          child: _miniStat(
                                              'Balance',
                                              '₱${info.remainingBalance.toStringAsFixed(2)}',
                                              info.isFullyPaid
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFFDC2626))),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        info.isFullyPaid
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF4ADE80),
                                      ),
                                    ),
                                  ),

                                  if (info.payments.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '${info.payments.length} payment${info.payments.length > 1 ? 's' : ''} recorded',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 10),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _infos.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _isExporting ? null : _showExportOptions,
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded),
              label: Text(_isExporting ? 'Exporting...' : 'Export'),
            ),
    );
  }

  Widget _filterChip(String label, String selected, VoidCallback onTap) {
    final isSelected = selected == label;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? const Color(0xFF14532D) : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: TextStyle(fontSize: 9, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}