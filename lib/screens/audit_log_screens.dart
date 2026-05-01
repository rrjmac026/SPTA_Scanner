import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/database_helper.dart';
import '../models/audit_log.dart';

class TeacherAuditLogScreen extends StatefulWidget {
  const TeacherAuditLogScreen({super.key});

  @override
  State<TeacherAuditLogScreen> createState() => _TeacherAuditLogScreenState();
}

class _TeacherAuditLogScreenState extends State<TeacherAuditLogScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final _user = FirebaseAuth.instance.currentUser;

  List<AuditLog> _logs = [];
  List<AuditLog> _filtered = [];
  bool _loading = true;
  String _filterAction = 'all';

  static const _actionFilters = {
    'all': 'All Actions',
    AuditAction.paymentAdded: 'Payments Added',
    AuditAction.paymentEdited: 'Edits',
    AuditAction.lrnLinked: 'LRN Linked',
    AuditAction.lrnAssigned: 'LRN Assigned',
    AuditAction.studentRegistered: 'Registrations',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_user == null) return;
    setState(() => _loading = true);
    final logs = await _db.getAuditLogsByUser(_user!.uid);
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    if (_filterAction == 'all') {
      _filtered = List.from(_logs);
    } else {
      _filtered = _logs.where((l) => l.action == _filterAction).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14532D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Activity Log',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(_user?.displayName ?? _user?.email ?? '',
                style:
                    const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filter chips ────────────────────────────────────────────────
          Container(
            color: const Color(0xFF14532D),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: _actionFilters.entries.map((e) {
                  final selected = _filterAction == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(e.value,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? const Color(0xFF14532D)
                                  : Colors.white,
                              fontWeight: FontWeight.w600)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _filterAction = e.key;
                          _applyFilter();
                        });
                      },
                      backgroundColor: Colors.white.withOpacity(0.15),
                      selectedColor: Colors.white,
                      checkmarkColor: const Color(0xFF14532D),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ─── Count banner ─────────────────────────────────────────────────
          if (!_loading)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFFDCFCE7),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: Color(0xFF16A34A), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_filtered.length} record${_filtered.length == 1 ? '' : 's'} — this is your personal proof trail.',
                    style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // ─── List ─────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF16A34A)))
                : _filtered.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        color: const Color(0xFF16A34A),
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _AuditLogCard(log: _filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            _filterAction == 'all'
                ? 'No activity recorded yet.'
                : 'No records for this filter.',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin screen
// ─────────────────────────────────────────────────────────────────────────────

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final DatabaseHelper _db = DatabaseHelper();

  List<AuditLog> _logs = [];
  List<AuditLog> _filtered = [];
  bool _loading = true;

  // Filters
  String _filterAction = 'all';
  String? _filterUid; // null = all users
  final Map<String, String> _knownUsers = {}; // uid → displayName

  static const _actionFilters = {
    'all': 'All Actions',
    AuditAction.paymentAdded: 'Payments Added',
    AuditAction.paymentEdited: 'Edits',
    AuditAction.lrnLinked: 'LRN Linked',
    AuditAction.lrnAssigned: 'LRN Assigned',
    AuditAction.studentRegistered: 'Registrations',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await _db.getAllAuditLogs();
    // Build uid → name map from the logs themselves
    final Map<String, String> users = {};
    for (final l in logs) {
      if (l.processedByUid.isNotEmpty) {
        users[l.processedByUid] = l.processedByName.isNotEmpty
            ? l.processedByName
            : l.processedByUid;
      }
    }
    if (mounted) {
      setState(() {
        _logs = logs;
        _knownUsers
          ..clear()
          ..addAll(users);
        _loading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    _filtered = _logs.where((l) {
      final actionMatch =
          _filterAction == 'all' || l.action == _filterAction;
      final userMatch =
          _filterUid == null || l.processedByUid == _filterUid;
      return actionMatch && userMatch;
    }).toList();
  }

  void _showUserPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Filter by Teacher',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.people_alt_rounded,
                    color: Color(0xFF16A34A)),
                title: const Text('All Teachers'),
                selected: _filterUid == null,
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
        );
      },
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
            Text('Admin View — All Activity',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
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
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showUserPicker,
            tooltip: 'Filter by teacher',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Action filter chips ──────────────────────────────────────────
          Container(
            color: const Color(0xFF14532D),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: _actionFilters.entries.map((e) {
                  final selected = _filterAction == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(e.value,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? const Color(0xFF14532D)
                                  : Colors.white,
                              fontWeight: FontWeight.w600)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _filterAction = e.key;
                          _applyFilter();
                        });
                      },
                      backgroundColor: Colors.white.withOpacity(0.15),
                      selectedColor: Colors.white,
                      checkmarkColor: const Color(0xFF14532D),
                      side: BorderSide.none,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ─── Active user filter banner ────────────────────────────────────
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
                    onTap: () {
                      setState(() {
                        _filterUid = null;
                        _applyFilter();
                      });
                    },
                    child: const Icon(Icons.close_rounded,
                        color: Color(0xFF92400E), size: 16),
                  ),
                ],
              ),
            ),

          // ─── Count banner ─────────────────────────────────────────────────
          if (!_loading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              color: const Color(0xFFDCFCE7),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: Color(0xFF16A34A), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_filtered.length} record${_filtered.length == 1 ? '' : 's'} • ${_knownUsers.length} teacher${_knownUsers.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // ─── List ─────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF16A34A)))
                : _filtered.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        color: const Color(0xFF16A34A),
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _AuditLogCard(
                            log: _filtered[i],
                            showUser: true,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No records match this filter.',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card widget
// ─────────────────────────────────────────────────────────────────────────────

class _AuditLogCard extends StatelessWidget {
  final AuditLog log;
  final bool showUser;

  const _AuditLogCard({required this.log, this.showUser = false});

  Color get _actionColor {
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

  IconData get _actionIcon {
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

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final m = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $h:$m $ampm';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _actionColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored left bar + icon
            Container(
              width: 52,
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_actionIcon, color: color, size: 17),
                  ),
                  const SizedBox(height: 6),
                  // Sync indicator
                  Icon(
                    log.synced
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    size: 12,
                    color: log.synced
                        ? const Color(0xFF16A34A)
                        : Colors.grey[400],
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
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
                          _formatDate(log.createdAt),
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 10),
                        ),
                      ],
                    ),

                    if (showUser) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded,
                              size: 12, color: Color(0xFF6B7280)),
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

                    if (log.oldValue != null || log.newValue != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (log.oldValue != null)
                            _valuePill(
                                label: 'Before',
                                value: log.oldValue!,
                                color: const Color(0xFFDC2626)),
                          if (log.oldValue != null && log.newValue != null)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 14, color: Color(0xFF9CA3AF)),
                            ),
                          if (log.newValue != null)
                            _valuePill(
                                label: 'After',
                                value: log.newValue!,
                                color: const Color(0xFF16A34A)),
                        ],
                      ),
                    ],

                    if (log.reason != null && log.reason!.isNotEmpty) ...[
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
                              child: Text(
                                log.reason!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4B5563)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (log.targetId != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Record #${log.targetId}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[400]),
                      ),
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

  Widget _valuePill(
      {required String label,
      required String value,
      required Color color}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}