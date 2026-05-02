import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../helpers/database_helper.dart';
import '../../helpers/export_helper.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_sync_service.dart';
import '../widgets/student_card.dart';
import '../widgets/export_bottom_sheet.dart';
import '../../widgets/sync_status_badge.dart';

/// Records screen for teachers — only shows students they personally processed.
/// Uses the Firestore payments stream (filtered by processedByUid in memory)
/// so the list is always live and never needs a manual reload.
class TeacherRecordsScreen extends StatefulWidget {
  const TeacherRecordsScreen({super.key});

  @override
  State<TeacherRecordsScreen> createState() => _TeacherRecordsScreenState();
}

class _TeacherRecordsScreenState extends State<TeacherRecordsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _auth = AuthService();
  final FirestoreSyncService _sync = FirestoreSyncService();

  // ── In-memory caches from Firestore streams ──────────────────────────────
  List<Payment> _allPayments = [];
  List<Student> _allStudents = [];
  double _totalFee = 750;

  List<StudentPaymentInfo> _infos = [];

  bool _isLoading = true;
  bool _isExporting = false;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';

  StreamSubscription<List<Payment>>? _paymentsSub;
  StreamSubscription<List<Student>>? _studentsSub;

  final List<String> _statusFilters = ['All', 'Fully Paid', 'Partial', 'Unpaid'];

  @override
  void initState() {
    super.initState();
    _loadFee();
    _subscribeToStreams();
  }

  @override
  void dispose() {
    _paymentsSub?.cancel();
    _studentsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFee() async {
    final fee = await _db.getTotalFee();
    if (mounted) {
      setState(() => _totalFee = fee);
      _rebuildInfos();
    }
  }

  void _subscribeToStreams() {
    final uid = _auth.currentUser?.uid ?? '';

    // Listen to ALL payments stream; filter by this teacher's uid in memory.
    // This is the same stream AdminHomeScreen uses, so edits propagate instantly.
    _paymentsSub = _sync.paymentsStream().listen(
      (payments) async {
        if (!mounted) return;
        _allPayments = payments;

        // Upsert into SQLite so exports / offline stay consistent.
        for (final p in payments) {
          if (p.transactionNumber.isNotEmpty) {
            await _db.upsertTransactionFromFirestore({
              'transactionNumber': p.transactionNumber,
              'studentId': p.studentId,
              'amount': p.amount,
              'note': p.note,
              'createdAt': p.createdAt,
              'processedByUid': p.processedByUid,
              'processedByName': p.processedByName,
            });
          }
        }

        _rebuildInfos();
      },
      onError: (_) => _fallbackToLocal(),
    );

    // Listen to students stream so names / grades stay fresh.
    _studentsSub = _sync.studentsStream().listen(
      (students) async {
        if (!mounted) return;
        _allStudents = students;

        for (final s in students) {
          await _db.upsertStudentFromFirestore({
            'lrn': s.lrn,
            'name': s.name,
            'grade': s.grade,
            'createdAt': s.createdAt,
            'isTemp': s.isTemp,
          });
        }

        _rebuildInfos();
      },
      onError: (_) => _fallbackToLocal(),
    );
  }

  /// Build [StudentPaymentInfo] list from the in-memory payment + student lists,
  /// keeping only students whose payments were processed by this teacher.
  void _rebuildInfos() {
    if (!mounted) return;

    final uid = _auth.currentUser?.uid ?? '';

    // Find student IDs where at least one payment was made by this teacher.
    final myStudentIds = _allPayments
        .where((p) => p.processedByUid == uid)
        .map((p) => p.studentId)
        .toSet();

    if (myStudentIds.isEmpty) {
      setState(() {
        _infos = [];
        _isLoading = false;
      });
      return;
    }

    // Group ALL payments (not just this teacher's) by studentId so balances
    // are always accurate even when multiple teachers collected from one student.
    final Map<int, List<Payment>> paymentsByStudent = {};
    for (final p in _allPayments) {
      paymentsByStudent.putIfAbsent(p.studentId, () => []).add(p);
    }

    // Build StudentPaymentInfo only for students this teacher touched.
    final studentMap = {for (final s in _allStudents) s.id: s};

    final infos = <StudentPaymentInfo>[];
    for (final sid in myStudentIds) {
      final student = studentMap[sid];
      if (student == null) continue;

      final payments = paymentsByStudent[sid] ?? [];
      payments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final amountPaid = payments.fold<double>(0, (s, p) => s + p.amount);

      infos.add(StudentPaymentInfo(
        student: student,
        totalFee: _totalFee,
        amountPaid: amountPaid,
        payments: payments,
      ));
    }

    // Sort newest registration first.
    infos.sort((a, b) => b.student.createdAt.compareTo(a.student.createdAt));

    setState(() {
      _infos = infos;
      _isLoading = false;
    });
  }

  /// Fallback: read from SQLite when Firestore is unavailable.
  Future<void> _fallbackToLocal() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final uid = _auth.currentUser?.uid ?? '';
    final infos = await _db.getStudentPaymentInfosByProcessor(uid);
    if (mounted) setState(() { _infos = infos; _isLoading = false; });
  }

  List<StudentPaymentInfo> get _filtered {
    return _infos.where((info) {
      final matchStatus = _selectedStatusFilter == 'All' ||
          info.paymentStatus == _selectedStatusFilter;
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          info.student.name.toLowerCase().contains(q) ||
          info.student.lrn.contains(q);
      return matchStatus && matchSearch;
    }).toList();
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

  void _showExportOptions() {
    final count = _filtered.isEmpty ? _infos.length : _filtered.length;
    ExportBottomSheet.show(
      context,
      recordCount: count,
      onExcelTap: _exportExcel,
      onPdfTap: _exportPdf,
    );
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
            Icon(
              type == 'Excel'
                  ? Icons.table_chart_rounded
                  : Icons.picture_as_pdf_rounded,
              color: const Color(0xFF16A34A),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text('$type Exported!',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14532D))),
            const SizedBox(height: 16),
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
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Share.shareXFiles([XFile(file.path)],
                          subject: 'My SPTA Payment Records');
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalCollected =
        filtered.fold<double>(0, (s, i) => s + i.amountPaid);
    final fullyPaidCount = filtered.where((i) => i.isFullyPaid).length;
    final user = _auth.currentUser;

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
            const Text('My Records',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text(user?.name ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          // Live indicator dot
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SyncStatusBadge(),
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
        ],
      ),
      body: Column(
        children: [
          // ── Search + filter bar ────────────────────────────────────────────
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
                    itemCount: _statusFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => _filterChip(
                        _statusFilters[i],
                        _selectedStatusFilter,
                        () => setState(
                            () => _selectedStatusFilter = _statusFilters[i])),
                  ),
                ),
              ],
            ),
          ),

          // ── Stats strip ────────────────────────────────────────────────────
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
                  _statItem('₱${totalCollected.toStringAsFixed(0)}', 'Collected',
                      Icons.payments_rounded, const Color(0xFF0D9488)),
                ],
              ),
            ),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF16A34A)),
                        SizedBox(height: 12),
                        Text('Connecting to live feed…',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 13)),
                      ],
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty &&
                                      _selectedStatusFilter == 'All'
                                  ? Icons.people_outline_rounded
                                  : Icons.search_off_rounded,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty &&
                                      _selectedStatusFilter == 'All'
                                  ? 'No records yet.\nScan a student to get started!'
                                  : 'No results found',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => StudentCard(
                          info: filtered[i],
                          index: i,
                          // Streams handle updates automatically; no manual
                          // reload needed, but StudentCard callback is honoured.
                          onRecordChanged: () {},
                        ),
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
}