class Payment {
  final int? id;
  final int studentId;
  final double amount;
  final String note;
  final String createdAt;
  final String transactionNumber;
  final String processedByUid;
  final String processedByName;

  Payment({
    this.id,
    required this.studentId,
    required this.amount,
    this.note = '',
    required this.createdAt,
    this.transactionNumber = '',
    this.processedByUid = '',
    this.processedByName = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'amount': amount,
        'note': note,
        'created_at': createdAt,
        'transaction_number': transactionNumber,
        'processed_by_uid': processedByUid,
        'processed_by_name': processedByName,
      };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as int?,
        studentId: map['student_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String? ?? '',
        createdAt: map['created_at'] as String,
        transactionNumber: map['transaction_number'] as String? ?? '',
        processedByUid: map['processed_by_uid'] as String? ?? '',
        processedByName: map['processed_by_name'] as String? ?? '',
      );
}