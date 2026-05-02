import 'dart:async';
import 'package:flutter/material.dart';
import '../../helpers/database_helper.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_sync_service.dart';
import '../../models/models.dart';
import '../scanner_screen.dart';
import '../records_screen.dart';
import '../settings_screen.dart';
import '../add_transaction_screen.dart';
import '../login_screen.dart';
import 'manage_users_screen.dart';
import '../../widgets/app_logo.dart';
import '../audit_log_screens.dart';
import '../../widgets/sync_status_badge.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _auth = AuthService();
  final FirestoreSyncService _syncService = FirestoreSyncService();

  // ── Stats displayed in the header ────────────────────────────────────────
  int _totalStudents = 0;
  double _totalCollected = 0;
  double _totalFee = 750;
  int _fullyPaidCount = 0;

  // ── In-memory caches from Firestore streams ───────────────────────────────
  // Keeping both lists lets us recompute all stats purely in memory whenever
  // either stream emits, so no stale SQLite reads can produce wrong totals.
  List<Payment> _allPayments = [];
  List<Student> _allStudents = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription? _paymentsStreamSub;
  StreamSubscription? _studentsStreamSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFee();
    _subscribeToFirestoreStreams();

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
    _paymentsStreamSub?.cancel();
    _studentsStreamSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Load the configurable fee once (it changes rarely) ───────────────────
  Future<void> _loadFee() async {
    final fee = await _db.getTotalFee();
    if (mounted) {
      setState(() => _totalFee = fee);
      _recomputeStats();
    }
  }

  /// Recompute all header stats purely from the in-memory lists.
  /// Called after every stream emission and after the fee is loaded.
  void _recomputeStats() {
    if (!mounted) return;

    // Total collected = sum of ALL payment amounts currently in the stream.
    // Because edited payments are pushed to Firestore with their new amount,
    // the stream always contains the latest value — no SQLite read needed.
    final totalCollected =
        _allPayments.fold<double>(0, (sum, p) => sum + p.amount);

    // Build a payment-per-student map to determine fully-paid count.
    final Map<int, double> paidByStudent = {};
    for (final p in _allPayments) {
      paidByStudent[p.studentId] =
          (paidByStudent[p.studentId] ?? 0) + p.amount;
    }

    final fullyPaid = _allStudents
        .where((s) => (paidByStudent[s.id] ?? 0) >= _totalFee)
        .length;

    setState(() {
      _totalStudents = _allStudents.length;
      _totalCollected = totalCollected;
      _fullyPaidCount = fullyPaid;
    });
  }

  /// Subscribes to the two Firestore real-time streams.
  ///
  /// Payments stream: fires on every add OR edit (because `upsertPayment`
  /// uses `SetOptions(merge: true)`, which triggers a snapshot update).
  /// We store the full list and recompute stats in memory — this is the key
  /// fix: we never call `getTotalCollected()` from SQLite for the header card.
  ///
  /// Students stream: fires when any device registers a student.
  void _subscribeToFirestoreStreams() {
    _paymentsStreamSub = _syncService.paymentsStream().listen(
      (remotePayments) async {
        _allPayments = remotePayments;

        // Also upsert into SQLite so Records / exports stay consistent.
        for (final p in remotePayments) {
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
      onError: (_) {
        // Offline — fall back to a one-time SQLite read.
        _fallbackLoadStats();
      },
    );

    _studentsStreamSub = _syncService.studentsStream().listen(
      (remoteStudents) async {
        _allStudents = remoteStudents;

        for (final s in remoteStudents) {
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
      onError: (_) {
        _fallbackLoadStats();
      },
    );
  }

  /// Fallback: read everything from local SQLite when Firestore is unavailable.
  Future<void> _fallbackLoadStats() async {
    final count = await _db.getTotalStudentCount();
    final collected = await _db.getTotalCollected();
    final fee = await _db.getTotalFee();
    final infos = await _db.getAllStudentPaymentInfos();
    final fullyPaid = infos.where((i) => i.isFullyPaid).length;
    if (mounted) {
      setState(() {
        _totalStudents = count;
        _totalCollected = collected;
        _totalFee = fee;
        _fullyPaidCount = fullyPaid;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app comes back to foreground, reload the fee in case it changed,
    // then recompute. Streams will have resumed automatically.
    if (state == AppLifecycleState.resumed) _loadFee();
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
                      color: Colors.amber.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded,
                            color: Colors.amber, size: 14),
                        SizedBox(width: 6),
                        Text('Admin / Treasurer',
                            style: TextStyle(
                                color: Colors.amber,
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
                              '$_totalStudents', 'Students')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _headerStat(Icons.verified_rounded,
                              '$_fullyPaidCount', 'Fully Paid')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _headerStat(
                              Icons.payments_rounded,
                              '₱${_totalCollected.toStringAsFixed(0)}',
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
                            // No manual reload needed — streams update stats.
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

                    // ── Row 1: All Records + Add Transaction ────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _modernActionCard(
                            icon: Icons.receipt_long_rounded,
                            label: 'All Records',
                            color: const Color(0xFF16A34A),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RecordsScreen())),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _modernActionCard(
                            icon: Icons.add_card_rounded,
                            label: 'Add Transaction',
                            color: const Color(0xFF0D9488),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AddTransactionScreen())),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Row 2: Manage Users + Settings ──────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _modernActionCard(
                            icon: Icons.people_rounded,
                            label: 'Manage Users',
                            color: const Color(0xFF7C3AED),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ManageUsersScreen())),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _modernActionCard(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            color: const Color(0xFF0284C7),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SettingsScreen()));
                              // Fee may have changed — reload it.
                              _loadFee();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Row 3: Audit Log (full width, accented) ─────────────
                    _modernActionCard(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Audit Log',
                      color: const Color(0xFFB45309),
                      fullWidth: true,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminAuditLogScreen())),
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