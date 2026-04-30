// lib/widgets/sync_status_badge.dart
//
// Drop this widget into any AppBar or toolbar so teachers can see
// whether their offline payments have been uploaded.
//
// Usage in AppBar:
//   AppBar(
//     title: Text('Payment'),
//     actions: [SyncStatusBadge()],
//   )

import 'dart:async';
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../services/firestore_sync_service.dart';

class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  int _pendingCount = 0;
  bool _isSyncing = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Poll every 10 seconds so the badge stays up to date
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final count = await DatabaseHelper().getPendingSyncCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _forceSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await FirestoreSyncService().syncAll();
      await _refresh();
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSyncing) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (_pendingCount == 0) {
      // All synced — show a subtle green check
      return IconButton(
        icon: const Icon(Icons.cloud_done_outlined, color: Colors.white),
        tooltip: 'All payments synced',
        onPressed: _forceSync,
      );
    }

    // Has pending uploads — show orange badge with count
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
          tooltip: 'Tap to upload $_pendingCount pending payment(s)',
          onPressed: () async {
            await _forceSync();
            if (mounted && _pendingCount > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _pendingCount == 0
                        ? 'All payments uploaded!'
                        : '$_pendingCount payment(s) still pending — check your connection.',
                  ),
                  backgroundColor:
                      _pendingCount == 0 ? Colors.green : Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$_pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
