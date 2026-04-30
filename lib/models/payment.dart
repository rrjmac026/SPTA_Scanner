// lib/models/payment.dart
//
// Add this `synced` field to your existing Payment model.
// This is a PATCH — merge it with whatever else is in your models/payment.dart.

class Payment {
  final int? id;
  final int studentId;
  final double amount;
  final String note;
  final String createdAt;
  final String transactionNumber;
  final String processedByUid;
  final String processedByName;

  /// True once the payment has been confirmed written to Firestore.
  /// Stored as INTEGER (0/1) in SQLite.
  final bool synced;

  const Payment({
    this.id,
    required this.studentId,
    required this.amount,
    this.note = '',
    required this.createdAt,
    this.transactionNumber = '',
    this.processedByUid = '',
    this.processedByName = '',
    this.synced = false,
  });

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as int?,
        studentId: map['student_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String? ?? '',
        createdAt: map['created_at'] as String? ?? '',
        transactionNumber: map['transaction_number'] as String? ?? '',
        processedByUid: map['processed_by_uid'] as String? ?? '',
        processedByName: map['processed_by_name'] as String? ?? '',
        synced: (map['synced'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'student_id': studentId,
        'amount': amount,
        'note': note,
        'created_at': createdAt,
        'transaction_number': transactionNumber,
        'processed_by_uid': processedByUid,
        'processed_by_name': processedByName,
        'synced': synced ? 1 : 0,
      };

  Payment copyWith({
    int? id,
    int? studentId,
    double? amount,
    String? note,
    String? createdAt,
    String? transactionNumber,
    String? processedByUid,
    String? processedByName,
    bool? synced,
  }) =>
      Payment(
        id: id ?? this.id,
        studentId: studentId ?? this.studentId,
        amount: amount ?? this.amount,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        transactionNumber: transactionNumber ?? this.transactionNumber,
        processedByUid: processedByUid ?? this.processedByUid,
        processedByName: processedByName ?? this.processedByName,
        synced: synced ?? this.synced,
      );
}