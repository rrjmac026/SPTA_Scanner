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
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Student> _students = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String _searchQuery = '';
  String _selectedGradeFilter = 'All';
  double _totalAmount = 0;

  final List<String> _gradeFilters = [
    'All',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final students = await _dbHelper.getAllStudents();
    final total = await _dbHelper.getTotalAmount();
    if (mounted) {
      setState(() {
        _students = students;
        _totalAmount = total;
        _isLoading = false;
      });
    }
  }

  List<Student> get _filteredStudents {
    return _students.where((s) {
      final matchesGrade =
          _selectedGradeFilter == 'All' || s.grade == _selectedGradeFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.lrn.contains(_searchQuery);
      return matchesGrade && matchesSearch;
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
      final exportList = _filteredStudents.isEmpty ? _students : _filteredStudents;
      final file = await ExportHelper.exportToExcel(exportList);
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
      final exportList = _filteredStudents.isEmpty ? _students : _filteredStudents;
      final file = await ExportHelper.exportToPdf(exportList);
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                type == 'Excel'
                    ? Icons.table_chart_rounded
                    : Icons.picture_as_pdf_rounded,
                color: const Color(0xFF16A34A),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '$type Exported!',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A3A6B)),
            ),
            const SizedBox(height: 6),
            Text(
              file.path.split('/').last,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
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
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
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
                      backgroundColor: const Color(0xFF2563EB),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export failed: $error'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Records',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A3A6B)),
            ),
            const SizedBox(height: 6),
            Text(
              'Exporting ${_filteredStudents.isEmpty ? _students.length : _filteredStudents.length} records'
              '${_selectedGradeFilter != 'All' ? ' ($_selectedGradeFilter)' : ''}',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 20),
            _exportOptionTile(
              icon: Icons.table_chart_rounded,
              color: const Color(0xFF16A34A),
              bgColor: const Color(0xFFDCFCE7),
              title: 'Export as Excel (.xlsx)',
              subtitle: 'Spreadsheet with all student data',
              onTap: () {
                Navigator.pop(context);
                _exportExcel();
              },
            ),
            const SizedBox(height: 12),
            _exportOptionTile(
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFDC2626),
              bgColor: const Color(0xFFFEE2E2),
              title: 'Export as PDF',
              subtitle: 'Printable report with grade summary',
              onTap: () {
                Navigator.pop(context);
                _exportPdf();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _exportOptionTile({
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
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStudents;
    final filteredTotal =
        filtered.fold<double>(0, (sum, s) => sum + s.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A6B),
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
            Text('${_students.length} total paid',
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
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: _students.isEmpty ? null : _showExportOptions,
              tooltip: 'Export',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStudents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + filter bar
          Container(
            color: const Color(0xFF1A3A6B),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // Search field
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or LRN...',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
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
                const SizedBox(height: 10),
                // Grade filter chips
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _gradeFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final grade = _gradeFilters[i];
                      final isSelected = _selectedGradeFilter == grade;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedGradeFilter = grade),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            grade,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF1A3A6B)
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Stats strip
          if (!_isLoading && _students.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  _statItem(
                    '${filtered.length}',
                    'Students',
                    Icons.people_alt_rounded,
                    const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 28, color: Colors.grey[200]),
                  const SizedBox(width: 8),
                  _statItem(
                    '₱${filteredTotal.toStringAsFixed(2)}',
                    'Total Collected',
                    Icons.payments_rounded,
                    const Color(0xFF16A34A),
                  ),
                  const Spacer(),
                  if (_selectedGradeFilter != 'All')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _selectedGradeFilter,
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Student list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty && _selectedGradeFilter == 'All'
                                  ? Icons.people_outline_rounded
                                  : Icons.search_off_rounded,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty && _selectedGradeFilter == 'All'
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
                          final s = filtered[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14)),
                                ),
                              ),
                              title: Text(s.name,
                                  style: const TextStyle(
                                      color: Color(0xFF1A3A6B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text('LRN: ${s.lrn}',
                                      style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                          fontFamily: 'monospace')),
                                  Row(
                                    children: [
                                      if (s.grade.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(
                                              top: 4, right: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(s.grade,
                                              style: const TextStyle(
                                                  color: Color(0xFF2563EB),
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                            _formatDate(s.createdAt),
                                            style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${s.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('Paid',
                                        style: TextStyle(
                                            color: Color(0xFF16A34A),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      // Export FAB
      floatingActionButton: _students.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _isExporting ? null : _showExportOptions,
              backgroundColor: const Color(0xFF2563EB),
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

  Widget _statItem(
      String value, String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }
}
