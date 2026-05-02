import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/audit_log.dart';
import '../services/firestore_sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Teacher screen — sees only their own logs, live from Firestore
// ─────────────────────────────────────────────────────────────────────────────

class TeacherAuditLogScreen extends StatefulWidget {
  const TeacherAuditLogScreen({super.key});

  @override
  State<TeacherAuditLogScreen> createState() => _TeacherAuditLogScreenState();
}

class _TeacherAuditLogScreenState extends State<TeacherAuditLogScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  final _sync = FirestoreSyncService();

  List<AuditLog> _logs = [];
  List<AuditLog> _filtered = [];
  bool _loading = true;
  String _filterAction = 'all';
  StreamSubscription<List<AuditLog>>? _sub;

  static const _actionFilters = <String, String>{
    'all': 'All',
    AuditAction.paymentAdded: 'Added',
    AuditAction.paymentEdited: 'Edited',
    AuditAction.lrnLinked: 'Linked',
    AuditAction.lrnAssigned: 'Assigned',
    AuditAction.studentRegistered: 'Registered',
  };

  @override
  void initState() {
    super.initState();
    _subscribeToLogs();
  }

  void _subscribeToLogs() {
    final uid = _user?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    _sub = _sync.auditLogsStreamForUser(uid).listen(
      (logs) {
        if (mounted) {
          setState(() {
            _logs = logs;
            _loading = false;
            _applyFilter();
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _applyFilter() {
    _filtered = _filterAction == 'all'
        ? List.from(_logs)
        : _logs.where((l) => l.action == _filterAction).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14532D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Activity Log',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('Live · updates automatically',
                style: TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
        actions: [
          // Live indicator dot
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            filters: _actionFilters,
            selected: _filterAction,
            onSelected: (key) => setState(() {
              _filterAction = key;
              _applyFilter();
            }),
          ),
          if (!_loading)
            _CountBanner(
              count: _filtered.length,
              icon: Icons.shield_outlined,
              message:
                  '${_filtered.length} record${_filtered.length == 1 ? '' : 's'} — your personal proof trail',
            ),
          Expanded(
            child: _loading
                ? const _LoadingView()
                : _filtered.isEmpty
                    ? _EmptyState(
                        message: _filterAction == 'all'
                            ? 'No activity recorded yet.'
                            : 'No records for this filter.',
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) =>
                            _AuditLogCard(log: _filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin screen — sees ALL logs from ALL devices, live from Firestore
// ─────────────────────────────────────────────────────────────────────────────

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final _sync = FirestoreSyncService();

  List<AuditLog> _logs = [];
  List<AuditLog> _filtered = [];
  bool _loading = true;

  String _filterAction = 'all';
  String? _filterUid;
  final Map<String, String> _knownUsers = {};
  StreamSubscription<List<AuditLog>>? _sub;

  static const _actionFilters = <String, String>{
    'all': 'All',
    AuditAction.paymentAdded: 'Added',
    AuditAction.paymentEdited: 'Edited',
    AuditAction.lrnLinked: 'Linked',
    AuditAction.lrnAssigned: 'Assigned',
    AuditAction.studentRegistered: 'Registered',
  };

  @override
  void initState() {
    super.initState();
    _subscribeToLogs();
  }

  void _subscribeToLogs() {
    _sub = _sync.auditLogsStream().listen(
      (logs) {
        if (!mounted) return;
        final Map<String, String> users = {};
        for (final l in logs) {
          if (l.processedByUid.isNotEmpty) {
            users[l.processedByUid] = l.processedByName.isNotEmpty
                ? l.processedByName
                : l.processedByUid;
          }
        }
        setState(() {
          _logs = logs;
          _knownUsers
            ..clear()
            ..addAll(users);
          _loading = false;
          _applyFilter();
        });
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _applyFilter() {
    _filtered = _logs.where((l) {
      final actionOk =
          _filterAction == 'all' || l.action == _filterAction;
      final userOk =
          _filterUid == null || l.processedByUid == _filterUid;
      return actionOk && userOk;
    }).toList();
  }

  void _showUserPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('Filter by Teacher',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded,
                  color: Color(0xFF16A34A)),
              title: const Text('All Teachers'),
              selected: _filterUid == null,
              selectedColor: const Color(0xFF16A34A),
              onTap: () {
                setState(() {
                  _filterUid = null;
                  _applyFilter();
                });
                Navigator.pop(context);
              },
            ),
            ..._knownUsers.entries.map((e) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFDCFCE7),
                    radius: 18,
                    child: Text(
                      e.value.isNotEmpty
                          ? e.value[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(e.value),
                  subtitle: Text(e.key,
                      style: const TextStyle(fontSize: 11)),
                  selected: _filterUid == e.key,
                  selectedColor: const Color(0xFF16A34A),
                  onTap: () {
                    setState(() {
                      _filterUid = e.key;
                      _applyFilter();
                    });
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14532D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audit Log',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('Live · all devices',
                style: TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
        actions: [
          // Live indicator dot
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.person_search_rounded),
                if (_filterUid != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFFFBBF24),
                          shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            onPressed: _showUserPicker,
            tooltip: 'Filter by teacher',
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            filters: _actionFilters,
            selected: _filterAction,
            onSelected: (key) => setState(() {
              _filterAction = key;
              _applyFilter();
            }),
          ),

          // Active user filter pill
          if (_filterUid != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              color: const Color(0xFFFEF9C3),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_rounded,
                      color: Color(0xFFCA8A04), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing: ${_knownUsers[_filterUid] ?? _filterUid}',
                      style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _filterUid = null;
                      _applyFilter();
                    }),
                    child: const Icon(Icons.close_rounded,
                        color: Color(0xFF92400E), size: 16),
                  ),
                ],
              ),
            ),

          if (!_loading)
            _CountBanner(
              count: _filtered.length,
              icon: Icons.admin_panel_settings_rounded,
              message:
                  '${_filtered.length} record${_filtered.length == 1 ? '' : 's'} · ${_knownUsers.length} teacher${_knownUsers.length == 1 ? '' : 's'}',
            ),

          Expanded(
            child: _loading
                ? const _LoadingView()
                : _filtered.isEmpty
                    ? const _EmptyState(
                        message: 'No records match this filter.')
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _AuditLogCard(
                          log: _filtered[i],
                          showUser: true,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final Map<String, String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterBar({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF14532D),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            final isSelected = selected == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelected(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF14532D)
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CountBanner extends StatelessWidget {
  final int count;
  final IconData icon;
  final String message;

  const _CountBanner(
      {required this.count, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFDCFCE7),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF16A34A), size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Color(0xFF15803D),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF16A34A)),
            SizedBox(height: 12),
            Text('Connecting to live feed…',
                style:
                    TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(message,
                style:
                    TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Audit log card
// ─────────────────────────────────────────────────────────────────────────────

class _AuditLogCard extends StatelessWidget {
  final AuditLog log;
  final bool showUser;

  const _AuditLogCard({required this.log, this.showUser = false});

  Color get _color {
    switch (log.action) {
      case AuditAction.paymentAdded:
        return const Color(0xFF16A34A);
      case AuditAction.paymentEdited:
        return const Color(0xFFD97706);
      case AuditAction.lrnLinked:
      case AuditAction.lrnAssigned:
        return const Color(0xFF2563EB);
      case AuditAction.studentRegistered:
        return const Color(0xFF7C3AED);
      default:
        return Colors.grey;
    }
  }

  IconData get _icon {
    switch (log.action) {
      case AuditAction.paymentAdded:
        return Icons.add_card_rounded;
      case AuditAction.paymentEdited:
        return Icons.edit_rounded;
      case AuditAction.lrnLinked:
        return Icons.link_rounded;
      case AuditAction.lrnAssigned:
        return Icons.assignment_ind_rounded;
      case AuditAction.studentRegistered:
        return Icons.person_add_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const mo = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final m = dt.minute.toString().padLeft(2, '0');
      return '${mo[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m $ampm';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent column
            Container(
              width: 54,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, color: color, size: 17),
                  ),
                  const SizedBox(height: 6),
                  // All Firestore-sourced logs are synced
                  const Icon(
                    Icons.cloud_done_rounded,
                    size: 13,
                    color: Color(0xFF16A34A),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action badge + timestamp
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.actionLabel,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _fmt(log.createdAt),
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 10),
                        ),
                      ],
                    ),

                    // Processor name
                    if (showUser) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded,
                              size: 12, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Text(
                            log.processedByName.isNotEmpty
                                ? log.processedByName
                                : log.processedByUid,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],

                    // Before → After pills
                    if (log.oldValue != null ||
                        log.newValue != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (log.oldValue != null)
                            Expanded(
                              child: _Pill(
                                  label: 'Before',
                                  value: log.oldValue!,
                                  color: const Color(0xFFDC2626)),
                            ),
                          if (log.oldValue != null &&
                              log.newValue != null)
                            const Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Color(0xFF9CA3AF)),
                            ),
                          if (log.newValue != null)
                            Expanded(
                              child: _Pill(
                                  label: 'After',
                                  value: log.newValue!,
                                  color: const Color(0xFF16A34A)),
                            ),
                        ],
                      ),
                    ],

                    // Reason
                    if (log.reason != null &&
                        log.reason!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.comment_rounded,
                                size: 12, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(log.reason!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF4B5563))),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Record ID
                    if (log.targetId != null) ...[
                      const SizedBox(height: 6),
                      Text('Record #${log.targetId}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[400])),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Pill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600)),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}