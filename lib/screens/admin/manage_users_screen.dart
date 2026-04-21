import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14532D),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage Users',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text('Approve and manage teacher access',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _firestore.usersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF16A34A)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }

          final users = snapshot.data ?? [];
          final currentUid = _auth.currentUser?.uid;

          // Separate by role
          final pending =
              users.where((u) => u.isPending).toList();
          final teachers =
              users.where((u) => u.isTeacher).toList();
          final admins =
              users.where((u) => u.isAdmin).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Pending approval ───────────────────────────────────────
              if (pending.isNotEmpty) ...[
                _sectionHeader(
                  'Pending Approval (${pending.length})',
                  Icons.hourglass_top_rounded,
                  const Color(0xFFF97316),
                ),
                const SizedBox(height: 8),
                ...pending.map((u) => _userCard(
                      user: u,
                      currentUid: currentUid,
                      isPending: true,
                    )),
                const SizedBox(height: 16),
              ],

              // ── Teachers ───────────────────────────────────────────────
              _sectionHeader(
                'Teachers (${teachers.length})',
                Icons.school_rounded,
                const Color(0xFF16A34A),
              ),
              const SizedBox(height: 8),
              if (teachers.isEmpty)
                _emptyState('No teachers yet')
              else
                ...teachers.map((u) => _userCard(
                      user: u,
                      currentUid: currentUid,
                    )),
              const SizedBox(height: 16),

              // ── Admins ─────────────────────────────────────────────────
              _sectionHeader(
                'Admins (${admins.length})',
                Icons.admin_panel_settings_rounded,
                const Color(0xFF7C3AED),
              ),
              const SizedBox(height: 8),
              ...admins.map((u) => _userCard(
                    user: u,
                    currentUid: currentUid,
                    isCurrentUser: u.uid == currentUid,
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _emptyState(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(msg,
          style: TextStyle(color: Colors.grey[400], fontSize: 13)),
    );
  }

  Widget _userCard({
    required AppUser user,
    required String? currentUid,
    bool isPending = false,
    bool isCurrentUser = false,
  }) {
    Color roleColor;
    Color roleBg;
    String roleLabel;

    switch (user.role) {
      case UserRole.admin:
        roleColor = const Color(0xFF7C3AED);
        roleBg = const Color(0xFFEDE9FE);
        roleLabel = 'Admin';
        break;
      case UserRole.teacher:
        roleColor = const Color(0xFF16A34A);
        roleBg = const Color(0xFFDCFCE7);
        roleLabel = 'Teacher';
        break;
      case UserRole.pending:
        roleColor = const Color(0xFFF97316);
        roleBg = const Color(0xFFFFF7ED);
        roleLabel = 'Pending';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isPending
            ? Border.all(
                color: const Color(0xFFF97316).withOpacity(0.4),
                width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // ── Avatar ────────────────────────────────────────────────────
          CircleAvatar(
            radius: 22,
            backgroundColor: roleBg,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),

          // ── Info ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(user.name,
                          style: const TextStyle(
                              color: Color(0xFF14532D),
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(user.email,
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 11),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: roleBg,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(roleLabel,
                      style: TextStyle(
                          color: roleColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          // ── Actions ───────────────────────────────────────────────────
          if (!isCurrentUser) ...[
            const SizedBox(width: 8),
            _roleActions(user),
          ],
        ],
      ),
    );
  }

  Widget _roleActions(AppUser user) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) => _handleAction(value, user),
      itemBuilder: (_) => [
        if (user.isPending || user.isTeacher)
          const PopupMenuItem(
            value: 'make_teacher',
            child: Row(
              children: [
                Icon(Icons.school_rounded,
                    color: Color(0xFF16A34A), size: 18),
                SizedBox(width: 10),
                Text('Set as Teacher'),
              ],
            ),
          ),
        if (user.isPending || user.isTeacher)
          const PopupMenuItem(
            value: 'make_admin',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded,
                    color: Color(0xFF7C3AED), size: 18),
                SizedBox(width: 10),
                Text('Set as Admin'),
              ],
            ),
          ),
        if (user.isTeacher || user.isAdmin)
          const PopupMenuItem(
            value: 'make_pending',
            child: Row(
              children: [
                Icon(Icons.block_rounded,
                    color: Color(0xFFF97316), size: 18),
                SizedBox(width: 10),
                Text('Revoke Access'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_rounded,
                  color: Color(0xFFDC2626), size: 18),
              SizedBox(width: 10),
              Text('Delete User',
                  style: TextStyle(color: Color(0xFFDC2626))),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(String action, AppUser user) async {
    switch (action) {
      case 'make_teacher':
        await _firestore.updateUserRole(user.uid, UserRole.teacher);
        _showSnack('${user.name} is now a Teacher ✓',
            const Color(0xFF16A34A));
        break;
      case 'make_admin':
        await _firestore.updateUserRole(user.uid, UserRole.admin);
        _showSnack('${user.name} is now an Admin ✓',
            const Color(0xFF7C3AED));
        break;
      case 'make_pending':
        await _firestore.updateUserRole(user.uid, UserRole.pending);
        _showSnack('${user.name}\'s access revoked',
            const Color(0xFFF97316));
        break;
      case 'delete':
        await _confirmDelete(user);
        break;
    }
  }

  Future<void> _confirmDelete(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Are you sure you want to delete ${user.name}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.deleteUser(user.uid);
      _showSnack('${user.name} deleted', const Color(0xFFDC2626));
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}