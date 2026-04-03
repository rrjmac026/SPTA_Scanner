import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import 'scanner_screen.dart';

class ResultScreen extends StatefulWidget {
  final String name;
  final String lrn;

  const ResultScreen({
    super.key,
    required this.name,
    required this.lrn,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  bool _isSaved = false;
  bool _alreadyExists = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
    _checkIfExists();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkIfExists() async {
    if (widget.lrn.isNotEmpty) {
      final exists = await _dbHelper.studentExists(widget.lrn);
      if (mounted && exists) {
        setState(() {
          _alreadyExists = true;
          _isSaved = true;
        });
      }
    }
  }

  Future<void> _markAsPaid() async {
    setState(() => _isLoading = true);

    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final student = Student(
      name: widget.name,
      lrn: widget.lrn,
      paymentStatus: 'Paid',
      createdAt: now,
    );

    final inserted = await _dbHelper.insertStudent(student);

    if (mounted) {
      if (inserted) {
        setState(() {
          _isLoading = false;
          _isSaved = true;
          _alreadyExists = false;
        });
        _showSnackBar('Payment recorded successfully!', isSuccess: true);
      } else {
        setState(() {
          _isLoading = false;
          _isSaved = true;
          _alreadyExists = true;
        });
        _showSnackBar('Student already paid SPTA', isSuccess: false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.info_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Scan Result',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ScannerScreen()),
              );
            },
            tooltip: 'Scan Another',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status badge
                if (_isSaved)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    decoration: BoxDecoration(
                      color: _alreadyExists
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _alreadyExists
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF22C55E),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _alreadyExists
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                          color: _alreadyExists
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF16A34A),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _alreadyExists
                                ? 'Student already paid SPTA'
                                : 'Payment recorded successfully!',
                            style: TextStyle(
                              color: _alreadyExists
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFF166534),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Student info card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Card header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1A3A6B), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Student Information',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'QR Code Data',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF22C55E)
                                        .withOpacity(0.5)),
                              ),
                              child: const Text(
                                'SCANNED',
                                style: TextStyle(
                                  color: Color(0xFF86EFAC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Student fields
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.badge_rounded,
                              label: 'Name',
                              value: widget.name.isNotEmpty
                                  ? widget.name
                                  : 'Not detected',
                              valueColor: widget.name.isNotEmpty
                                  ? const Color(0xFF1A3A6B)
                                  : Colors.red,
                            ),
                            const SizedBox(height: 4),
                            Divider(color: Colors.grey[100], height: 24),
                            _buildInfoRow(
                              icon: Icons.numbers_rounded,
                              label: 'LRN',
                              value: widget.lrn.isNotEmpty
                                  ? widget.lrn
                                  : 'Not detected',
                              valueColor: widget.lrn.isNotEmpty
                                  ? const Color(0xFF1A3A6B)
                                  : Colors.red,
                              isMonospace: true,
                            ),
                            const SizedBox(height: 4),
                            Divider(color: Colors.grey[100], height: 24),
                            _buildInfoRow(
                              icon: Icons.payment_rounded,
                              label: 'Payment Status',
                              value: _isSaved ? 'Paid' : 'Pending',
                              valueColor: _isSaved
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Mark as Paid button
                if (!_isSaved) ...[
                  SizedBox(
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _markAsPaid,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 22),
                      label: Text(
                        _isLoading ? 'Saving...' : 'Mark SPTA Paid',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF16A34A).withOpacity(0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Scan another button
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScannerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text(
                      'Scan Another Student',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(
                          color: Color(0xFF2563EB), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Back to home button
                SizedBox(
                  height: 52,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home_rounded, size: 20),
                    label: const Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    bool isMonospace = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: isMonospace ? 'monospace' : null,
                  letterSpacing: isMonospace ? 1.0 : 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
