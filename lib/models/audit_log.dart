/// Represents a single entry in the immutable audit trail.
/// Every sensitive action (add payment, edit payment, link LRN, etc.)
/// produces one [AuditLog] that is written to SQLite AND synced to Firestore.
class AuditLog {
  final int? id;
  final String action;       // e.g. 'payment_added', 'payment_edited'
  final String targetType;   // e.g. 'payment', 'student'
  final int? targetId;       // SQLite row id of the affected record
  final String? oldValue;    // JSON or plain string of old state
  final String? newValue;    // JSON or plain string of new state
  final String? reason;      // Optional justification entered by the user
  final String processedByUid;
  final String processedByName;
  final String createdAt;    // 'yyyy-MM-dd HH:mm:ss'
  final bool synced;         // false until uploaded to Firestore

  const AuditLog({
    this.id,
    required this.action,
    required this.targetType,
    this.targetId,
    this.oldValue,
    this.newValue,
    this.reason,
    required this.processedByUid,
    required this.processedByName,
    required this.createdAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'old_value': oldValue,
        'new_value': newValue,
        'reason': reason,
        'processed_by_uid': processedByUid,
        'processed_by_name': processedByName,
        'created_at': createdAt,
        'synced': synced ? 1 : 0,
      };

  factory AuditLog.fromMap(Map<String, dynamic> m) => AuditLog(
        id: m['id'] as int?,
        action: m['action'] as String,
        targetType: m['target_type'] as String,
        targetId: m['target_id'] as int?,
        oldValue: m['old_value'] as String?,
        newValue: m['new_value'] as String?,
        reason: m['reason'] as String?,
        processedByUid: m['processed_by_uid'] as String,
        processedByName: m['processed_by_name'] as String,
        createdAt: m['created_at'] as String,
        synced: (m['synced'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toFirestore() => {
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'old_value': oldValue,
        'new_value': newValue,
        'reason': reason,
        'processed_by_uid': processedByUid,
        'processed_by_name': processedByName,
        'created_at': createdAt,
      };

  // ── Friendly display helpers ─────────────────────────────────────────────

  String get actionLabel {
    switch (action) {
      case 'payment_added':
        return 'Payment Added';
      case 'payment_edited':
        return 'Payment Edited';
      case 'lrn_linked':
        return 'LRN Linked';
      case 'lrn_assigned':
        return 'LRN Assigned';
      case 'student_registered':
        return 'Student Registered';
      default:
        return action;
    }
  }

  bool get isEdit => action == 'payment_edited';
  bool get isAdd  => action == 'payment_added';
}

/// Well-known action constants — use these instead of raw strings.
class AuditAction {
  static const paymentAdded      = 'payment_added';
  static const paymentEdited     = 'payment_edited';
  static const lrnLinked         = 'lrn_linked';
  static const lrnAssigned       = 'lrn_assigned';
  static const studentRegistered = 'student_registered';
}