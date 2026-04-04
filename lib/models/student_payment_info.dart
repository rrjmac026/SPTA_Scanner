import 'student.dart';
import 'payment.dart';

/// Combines a Student with their full payment summary.
class StudentPaymentInfo {
  final Student student;
  final double totalFee;
  final double amountPaid;
  final List<Payment> payments;

  StudentPaymentInfo({
    required this.student,
    required this.totalFee,
    required this.amountPaid,
    required this.payments,
  });

  double get remainingBalance =>
      (totalFee - amountPaid).clamp(0, double.infinity);

  bool get isFullyPaid => remainingBalance <= 0;

  String get paymentStatus =>
      isFullyPaid ? 'Fully Paid' : (amountPaid > 0 ? 'Partial' : 'Unpaid');
}