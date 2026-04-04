import 'package:flutter/material.dart';
import '../../models/student.dart';

/// Card showing student identity info in [ResultScreen].
/// Pass [student] for an existing record, or leave null to use
/// [name]/[lrn] from the raw QR scan.
class StudentInfoCard extends StatelessWidget {
  final Student? student;
  final String name;
  final String lrn;

  const StudentInfoCard({
    super.key,
    this.student,
    required this.name,
    required this.lrn,
  });

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool isMonospace = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF16A34A), size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: valueColor ?? const Color(0xFF14532D),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: isMonospace ? 'monospace' : null,
                      letterSpacing: isMonospace ? 0.8 : 0)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = student?.name ?? name;
    final displayLrn = student?.lrn ?? lrn;
    final grade = student?.grade ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF14532D), Color(0xFF16A34A)]),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Student Information',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text('Scanned from QR Code',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Text('SCANNED',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
              ],
            ),
          ),

          // Body rows
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.badge_rounded, 'Full Name',
                    displayName.isNotEmpty ? displayName : 'Not detected',
                    valueColor: displayName.isNotEmpty
                        ? const Color(0xFF14532D)
                        : Colors.red),
                if (displayLrn.isNotEmpty) ...[
                  Divider(color: Colors.grey[100], height: 20),
                  _infoRow(Icons.numbers_rounded, 'LRN', displayLrn,
                      isMonospace: true,
                      valueColor: const Color(0xFF14532D)),
                ],
                if (grade.isNotEmpty) ...[
                  Divider(color: Colors.grey[100], height: 20),
                  _infoRow(Icons.school_rounded, 'Grade Level', grade,
                      valueColor: const Color(0xFF16A34A)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}