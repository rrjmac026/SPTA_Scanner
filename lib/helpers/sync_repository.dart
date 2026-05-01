import '../models/models.dart';
import '../services/firestore_sync_service.dart';
import 'database_service.dart';
import 'payment_repository.dart';

/// Repository for handling sync operations between local and Firestore.
class SyncRepository {
  final DatabaseService _databaseService = DatabaseService();
  final PaymentRepository _paymentRepository = PaymentRepository();

  /// Returns merged payments: union of local SQLite + remote Firestore,
  /// deduplicated by transaction_number. Local unsynced payments are always
  /// included; remote-only payments are inserted into local DB to keep it fresh.
  Future<List<Payment>> getMergedPaymentsForStudent(int studentId) async {
    final localPayments = await _paymentRepository.getPaymentsForStudent(studentId);
    List<Payment> remotePayments = [];

    try {
      remotePayments =
          await FirestoreSyncService().fetchPaymentsForStudent(studentId);
    } catch (_) {
      // Offline or Firestore unavailable — fall back to local only
    }

    // Build a map keyed by transaction_number (or id as fallback)
    final Map<String, Payment> merged = {};

    // Remote payments go in first (they're the source of truth for synced data)
    for (final p in remotePayments) {
      final key = p.transactionNumber.isNotEmpty
          ? p.transactionNumber
          : 'remote-${p.id}';
      merged[key] = p;
    }

    // Local payments override (they may be newer / unsynced)
    for (final p in localPayments) {
      final key = p.transactionNumber.isNotEmpty
          ? p.transactionNumber
          : 'local-${p.id}';
      merged[key] = p;
    }

    // Insert any remote-only payments into local DB so this device stays current
    final localTxnNumbers =
        localPayments.map((p) => p.transactionNumber).toSet();
    for (final p in remotePayments) {
      if (!localTxnNumbers.contains(p.transactionNumber) &&
          p.transactionNumber.isNotEmpty) {
        await _paymentRepository.insertRemotePaymentLocally(p);
      }
    }

    final result = merged.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }
}
