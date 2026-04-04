class Payment {
  final int? id;
  final int studentId;
  final double amount;
  final String note;
  final String createdAt;

  Payment({
    this.id,
    required this.studentId,
    required this.amount,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'amount': amount,
        'note': note,
        'created_at': createdAt,
      };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as int?,
        studentId: map['student_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String? ?? '',
        createdAt: map['created_at'] as String,
      );
}