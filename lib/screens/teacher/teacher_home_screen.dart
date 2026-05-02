import 'dart:async';
import 'package:flutter/material.dart';
import '../../helpers/database_helper.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_sync_service.dart';
import '../scanner_screen.dart';
import '../add_transaction_screen.dart';
import '../login_screen.dart';
import 'teacher_records_screen.dart';
import '../../widgets/app_logo.dart';
import '../audit_log_screens.dart';
import '../../widgets/sync_status_badge.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _auth = AuthService();
  final FirestoreSyncService _sync = FirestoreSyncService();

  // ── In-memory caches from Firestore streams ──────────────────────────────
  List<Payment> _allPayments = [];
  List<Student> _allStudents = [];
  double _totalFee = 750;

  // ── Computed stats ───────────────────────────────────────────────────────
  int _myStudentCount = 0;
  double _myCollected = 0;
  int _myFullyPaid = 0;

  StreamSubscription<List<Payment>>? _paymentsSub;
  StreamSubscription<List<Student>>? _studentsSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFee();
    _subscribeToStreams();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentsSub?.cancel();
    _studentsSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadFee();
  }

  Future<void> _loadFee() async {
    final fee = await _db.getTotalFee();
    if (mounted) {
      setState(() => _totalFee = fee);
      _recomputeStats();
    }
  }

  void _subscribeToStreams() {
    _paymentsSub = _sync.paymentsStream().listen(
      (payments) async {
        if (!mounted) return;
        _allPayments = payments;

        // Keep SQLite fresh for exports / offline use
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

        _recomputeStats();
      },
      onError: (_) => _fallbackToLocal(),
    );

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

        _recomputeStats();
      },
      onError: (_) => _fallbackToLocal(),
    );
  }

  /// Recompute stats from in-memory lists — same pattern as AdminHomeScreen,
  /// but filtered to only this teacher's payments.
  void _recomputeStats() {
    if (!mounted) return;

    final uid = _auth.currentUser?.uid ?? '';

    // Find student IDs where at least one payment was made by this teacher.
    final myStudentIds = _allPayments
        .where((p) => p.processedByUid == uid)
        .map((p) => p.studentId)
        .toSet();

    if (myStudentIds.isEmpty) {
      setState(() {
        _myStudentCount = 0;
        _myCollected = 0;
        _myFullyPaid = 0;
      });
      return;
    }

    // Group ALL payments by studentId so balances are correct even when
    // multiple teachers collected from the same student.
    final Map<int, double> paidByStudent = {};
    for (final p in _allPayments) {
      paidByStudent[p.studentId] =
          (paidByStudent[p.studentId] ?? 0) + p.amount;
    }

    // Total collected = sum of only THIS teacher's payments.
    final myCollected = _allPayments
        .where((p) => p.processedByUid == uid)
        .fold<double>(0, (sum, p) => sum + p.amount);

    // Fully paid = students this teacher touched whose total balance is cleared.
    final myFullyPaid = myStudentIds
        .where((sid) => (paidByStudent[sid] ?? 0) >= _totalFee)
        .length;

    setState(() {
      _myStudentCount = myStudentIds.length;
      _myCollected = myCollected;
      _myFullyPaid = myFullyPaid;
    });
  }

  /// Fallback: read from SQLite when Firestore streams fail (offline).
  Future<void> _fallbackToLocal() async {
    if (!mounted) return;
    final uid = _auth.currentUser?.uid ?? '';
    final fee = await _db.getTotalFee();
    final infos = await _db.getStudentPaymentInfosByProcessor(uid);
    final collected = await _db.getTotalCollectedByProcessor(uid);
    final fullyPaid = infos.where((i) => i.isFullyPaid).length;

    if (mounted) {
      setState(() {
        _totalFee = fee;
        _myStudentCount = infos.length;
        _myCollected = collected;
        _myFullyPaid = fullyPaid;
      });
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ─────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF14532D), Color(0xFF16A34A)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppLogo(size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SPTA Payment',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5)),
                            const SizedBox(height: 2),
                            Text(
                              user?.name ?? 'Teacher',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SyncStatusBadge(),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _signOut,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.logout_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.lightBlueAccent.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_rounded,
                            color: Colors.lightBlueAccent, size: 14),
                        SizedBox(width: 6),
                        Text('Teacher',
                            style: TextStyle(
                                color: Colors.lightBlueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: _headerStat(Icons.people_alt_rounded,
                              '$_myStudentCount', 'My Students')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _headerStat(Icons.verified_rounded,
                              '$_myFullyPaid', 'Fully Paid')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _headerStat(
                              Icons.payments_rounded,
                              '₱${_myCollected.toStringAsFixed(0)}',
                              'Collected',
                              overflow: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'SPTA Fee: ₱${_totalFee.toStringAsFixed(2)} per student',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Body ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: Color(0xFF14532D),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Main scanner card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ScannerScreen()));
                            // No manual reload — streams update stats automatically.
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                ScaleTransition(
                                  scale: _pulseAnimation,
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.qr_code_scanner_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Scan Student ID',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Verify payment status instantly',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Row 1: My Records + Add Transaction ─────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _modernActionCard(
                            icon: Icons.receipt_long_rounded,
                            label: 'My Records',
                            color: const Color(0xFF16A34A),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const TeacherRecordsScreen()));
                              // Streams handle stats automatically.
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _modernActionCard(
                            icon: Icons.add_card_rounded,
                            label: 'Add Transaction',
                            color: const Color(0xFF0D9488),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AddTransactionScreen()));
                              // Streams handle stats automatically.
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Row 2: Activity Log (full width) ────────────────────
                    _modernActionCard(
                      icon: Icons.history_rounded,
                      label: 'My Activity Log',
                      color: const Color(0xFF0369A1),
                      fullWidth: true,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const TeacherAuditLogScreen()));
                      },
                    ),

                    const SizedBox(height: 24),

                    // Info card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF16A34A).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF16A34A),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Scan QR codes or manually add transactions to process payments',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerStat(IconData icon, String value, String label,
      {bool overflow = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            overflow: overflow ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: fullWidth
                ? const EdgeInsets.symmetric(vertical: 14, horizontal: 20)
                : const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: fullWidth
                ? Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: color.withOpacity(0.5), size: 14),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}