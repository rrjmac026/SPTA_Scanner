import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import '../models/models.dart';
import '../services/firestore_sync_service.dart';
import '../services/firestore_service.dart';
import 'scanner_screen.dart';
import 'widgets/payment_dialog.dart';
import 'widgets/status_banner.dart';
import 'widgets/student_info_card.dart';
import 'widgets/payment_summary_card.dart';
import 'widgets/payment_history_card.dart';
import 'widgets/link_temp_sheet.dart';
import '../services/auth_service.dart';

class ResultScreen extends StatefulWidget {
  final String name;
  final String lrn;

  const ResultScreen({super.key, required this.name, required this.lrn});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();
  final FirestoreSyncService _syncService = FirestoreSyncService();

  bool _isLoading = true;
  bool _isSavingPayment = false;
  bool _isLinking = false;

  StudentPaymentInfo? _info;
  String _selectedGrade = 'Grade 7';
  bool _isNewStudent = false;
  bool _tempLinkChecked = false;

  // ── Live stream subscriptions ────────────────────────────────────────────
  // We subscribe to BOTH the students stream and the payments stream (same as
  // RecordsScreen / AdminHomeScreen) so that any payment recorded on another
  // device is immediately reflected here.
  StreamSubscription<List<Student>>? _studentsSub;
  StreamSubscription<List<Payment>>? _paymentsSub;

  // In-memory caches that are rebuilt whenever either stream fires.
  List<Student> _allStudents = [];
  List<Payment> _allPayments = [];
  double _totalFee = 750;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<String> _grades = [
    'Grade 7', 'Grade 8', 'Grade 9',
    'Grade 10', 'Grade 11', 'Grade 12',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 450), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    _loadFeeAndSubscribe();
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _paymentsSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ── Step 1: load fee, then subscribe to live streams ─────────────────────
  Future<void> _loadFeeAndSubscribe() async {
    _totalFee = await _db.getTotalFee();
    _subscribeToStreams();
  }

  /// Mirrors the pattern used in RecordsScreen and AdminHomeScreen.
  /// Both streams upsert into SQLite as they arrive, then rebuild _info in
  /// memory — so the displayed balance is always consistent with Firestore.
  void _subscribeToStreams() {
    _studentsSub = _syncService.studentsStream().listen(
      (students) async {
        if (!mounted) return;
        _allStudents = students;

        // Keep local SQLite fresh so exports / other screens stay consistent.
        for (final s in students) {
          await _db.upsertStudentFromFirestore({
            'lrn': s.lrn,
            'name': s.name,
            'grade': s.grade,
            'createdAt': s.createdAt,
            'isTemp': s.isTemp,
          });
        }

        _rebuildInfo();
      },
      onError: (_) => _fallbackToOneShot(),
    );

    _paymentsSub = _syncService.paymentsStream().listen(
      (payments) async {
        if (!mounted) return;
        _allPayments = payments;

        // Upsert every payment into SQLite so local queries stay accurate.
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

        _rebuildInfo();
      },
      onError: (_) => _fallbackToOneShot(),
    );
  }

  /// Builds [_info] from the in-memory student + payment caches, filtered to
  /// the LRN that was scanned. Called after every stream emission.
  void _rebuildInfo() {
    if (!mounted) return;

    // Find the student record for the scanned LRN.
    Student? student;
    try {
      student = _allStudents.firstWhere((s) => s.lrn == widget.lrn);
    } catch (_) {
      student = null;
    }

    if (student == null) {
      // Student not found in Firestore yet — could be truly new or offline.
      // Check for temp-link candidates once, then fall back to "new student".
      if (!_tempLinkChecked && !_isNewStudent) {
        _handleMissingStudent();
      } else {
        setState(() {
          _isLoading = false;
          // Keep _isNewStudent as-is; don't flip it back on stream updates.
        });
      }
      return;
    }

    // Filter payments for this student only.
    final payments = _allPayments
        .where((p) => p.studentId == student!.id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final amountPaid = payments.fold<double>(0, (s, p) => s + p.amount);

    final info = StudentPaymentInfo(
      student: student,
      totalFee: _totalFee,
      amountPaid: amountPaid,
      payments: payments,
    );

    setState(() {
      _info = info;
      _isNewStudent = false;
      _isLoading = false;
    });
  }

  /// Called when the scanned LRN is not found in the live stream.
  /// Checks for walk-in (temp) candidates; if none, marks as new student.
  Future<void> _handleMissingStudent() async {
    _tempLinkChecked = true;

    final candidates = await _db.findTempCandidates(widget.name);
    if (candidates.isNotEmpty && mounted) {
      setState(() => _isLoading = false);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      final chosen = await LinkTempSheet.show(
        context,
        scannedName: widget.name,
        scannedLrn: widget.lrn,
        candidates: candidates,
      );

      if (chosen != null && mounted) {
        await _linkTempRecord(chosen);
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isNewStudent = true;
        _isLoading = false;
      });
    }
  }

  /// Fallback used when Firestore streams fail (offline device).
  /// Performs a single SQLite read — the same behaviour as before.
  Future<void> _fallbackToOneShot() async {
    final info =
        await _firestoreService.syncAndGetStudentPaymentInfo(widget.lrn);

    if (info == null) {
      if (!_tempLinkChecked) {
        await _handleMissingStudent();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _info = info;
        _isNewStudent = false;
        _isLoading = false;
      });
    }
  }

  // ── Kept for post-payment refresh and initial registration ───────────────

  /// Still used after _registerAndContinue() so the grade selector clears
  /// and transitions to the payment view.  The live stream will have already
  /// updated _info by the time this resolves, but calling _rebuildInfo()
  /// explicitly guarantees the UI flips without waiting for the next emission.
  Future<void> _refreshFromCache() async {
    _rebuildInfo();
  }

  Future<void> _linkTempRecord(StudentPaymentInfo chosen) async {
    if (mounted) setState(() => _isLinking = true);

    await _db.linkTempToLrn(
      tempStudentId: chosen.student.id!,
      realLrn: widget.lrn,
      realName: widget.name,
      grade: chosen.student.grade,
    );

    // The live stream will pick up the change shortly; do one explicit rebuild
    // so the UI doesn't sit blank while waiting.
    final info =
        await _firestoreService.syncAndGetStudentPaymentInfo(widget.lrn);
    if (mounted) {
      setState(() {
        _info = info;
        _isNewStudent = info == null;
        _isLoading = false;
        _isLinking = false;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.link_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Walk-in record linked to ${widget.name}!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _registerAndContinue() async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final currentUser = AuthService().currentUser;
    final student = Student(
      name: widget.name,
      lrn: widget.lrn,
      grade: _selectedGrade,
      createdAt: now,
    );
    final id = await _db.insertStudent(
      student,
      processedByUid: currentUser?.uid ?? '',
      processedByName: currentUser?.name ?? '',
    );
    if (id == null) {
      // Already exists — just rebuild from what we have.
      await _refreshFromCache();
      return;
    }
    // The Firestore stream will push the new student back to us; rebuild now
    // from SQLite so the grade selector disappears immediately.
    await _refreshFromCache();
  }

  Future<void> _showPaymentDialog() async {
    if (_info == null) return;
    final remaining = _info!.remainingBalance;
    if (remaining <= 0) return;

    await showPaymentDialog(context, remaining: remaining).then((amt) async {
      if (amt == null) return;
      setState(() => _isSavingPayment = true);
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final currentUser = AuthService().currentUser;
      final savedPayment = await _db.addPayment(Payment(
        studentId: _info!.student.id!,
        amount: amt as double,
        createdAt: now,
        processedByUid: currentUser?.uid ?? '',
        processedByName: currentUser?.name ?? '',
      ));

      // The live stream will update _info; just clear the saving flag here.
      // We do one explicit rebuild so the balance flips without waiting.
      await _refreshFromCache();
      setState(() => _isSavingPayment = false);

      if (mounted) {
        final isNowPaid = _info?.isFullyPaid ?? false;
        final txn = savedPayment.transactionNumber;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isNowPaid
                          ? Icons.celebration_rounded
                          : Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isNowPaid
                            ? 'Payment complete! SPTA fully paid!'
                            : '₱${amt.toStringAsFixed(2)} recorded successfully!',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (txn.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: txn));
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_number_rounded,
                            size: 13, color: Colors.white70),
                        const SizedBox(width: 5),
                        Text(txn,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                letterSpacing: 0.5)),
                        const SizedBox(width: 5),
                        const Icon(Icons.copy_rounded,
                            size: 11, color: Colors.white54),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            backgroundColor: isNowPaid
                ? const Color(0xFF0D9488)
                : const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  // ─── Grade selector (new student) ─────────────────────────────────────────

  Widget _buildGradeSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudentInfoCard(name: widget.name, lrn: widget.lrn),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
            ),
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
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.school_rounded,
                          color: Color(0xFF16A34A), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Select Grade Level',
                        style: TextStyle(
                            color: Color(0xFF14532D),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('This student is new. Select their grade to register.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGrade,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF16A34A)),
                      items: _grades.map((grade) {
                        return DropdownMenuItem(
                          value: grade,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Center(
                                  child: Text(grade.split(' ').last,
                                      style: const TextStyle(
                                          color: Color(0xFF16A34A),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(grade,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedGrade = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _registerAndContinue,
                    icon: const Icon(Icons.person_add_rounded, size: 20),
                    label: const Text('Register & Continue',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _scanAnotherButton(),
        ],
      ),
    );
  }

  // ─── Payment view (existing student) ──────────────────────────────────────

  Widget _buildPaymentView() {
    if (_info == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF16A34A)),
      );
    }

    final info = _info!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Temp-linked banner ────────────────────────────────────────
          if (info.student.isTempRecord) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFF97316).withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF97316), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Walk-in record — LRN not yet linked. Ask student to present their QR code.',
                      style: TextStyle(
                          color: Color(0xFF9A3412),
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          StatusBanner(info: info),
          const SizedBox(height: 14),
          StudentInfoCard(
              student: info.student, name: widget.name, lrn: widget.lrn),
          const SizedBox(height: 14),
          PaymentSummaryCard(info: info),
          const SizedBox(height: 14),

          // ── Payment history with edit support ─────────────────────────
          if (info.payments.isNotEmpty) ...[
            PaymentHistoryCard(
              payments: info.payments,
              student: info.student,
              totalFee: info.totalFee,
              onEdited: _refreshFromCache,
            ),
            const SizedBox(height: 14),
          ],

          if (!info.isFullyPaid) ...[
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSavingPayment ? null : _showPaymentDialog,
                icon: _isSavingPayment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.add_card_rounded, size: 22),
                label: Text(
                  _isSavingPayment
                      ? 'Recording...'
                      : info.amountPaid > 0
                          ? 'Record Installment Payment'
                          : 'Record Payment',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _scanAnotherButton(),
          const SizedBox(height: 10),
          _homeButton(),
        ],
      ),
    );
  }

  // ─── Shared action buttons ─────────────────────────────────────────────────

  Widget _scanAnotherButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
        label: const Text('Scan Another Student',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF16A34A),
          side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _homeButton() {
    return SizedBox(
      height: 50,
      child: TextButton.icon(
        onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        icon: const Icon(Icons.home_rounded, size: 20),
        label: const Text('Back to Home',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey[600],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Scan Result',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          // Live indicator dot — same as RecordsScreen
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
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ScannerScreen()),
            ),
            tooltip: 'Scan Another',
          ),
        ],
      ),
      body: (_isLoading || _isLinking)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF16A34A)),
                  const SizedBox(height: 16),
                  Text(
                    _isLinking ? 'Linking record...' : 'Loading...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _isNewStudent
                    ? _buildGradeSelector()
                    : _buildPaymentView(),
              ),
            ),
    );
  }
}