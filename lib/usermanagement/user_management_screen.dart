// lib/screens/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class ManagedUser {
  final int id;
  final String name;
  final String email;
  final String role;
  bool isActive;
  final DateTime createdAt;

  ManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'worker',
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class UserManagementService {
  // Reuse the same base URL / token logic from AuthService
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> fetchUsers() async {
    return await _authService.makeAuthenticatedRequest(
      method: 'GET',
      endpoint: '/users',
    );
  }

  Future<Map<String, dynamic>> toggleUserStatus(int userId, bool isActive) async {
    return await _authService.makeAuthenticatedRequest(
      method: 'PATCH',
      endpoint: '/users/$userId/status',
      body: {'isActive': isActive},
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final _service = UserManagementService();

  List<ManagedUser> _allUsers = [];
  List<ManagedUser> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all' | 'admin' | 'worker'
  String _statusFilter = 'all'; // 'all' | 'active' | 'inactive'

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadUsers();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _callerRole {
    final user =
        Provider.of<AuthProvider>(context, listen: false).user;
    return user?.role ?? 'worker';
  }

  bool _canManage(ManagedUser target) {
    if (_callerRole == 'super_admin') return true;
    if (_callerRole == 'admin') return target.role == 'worker';
    return false;
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _service.fetchUsers();
      if (res['success'] == true) {
        final List raw = res['data'] as List;
        final callerRole = _callerRole;

        List<ManagedUser> users =
        raw.map((e) => ManagedUser.fromJson(e)).toList();

        // admin only sees workers; super_admin sees admins + workers
        if (callerRole == 'admin') {
          users = users.where((u) => u.role == 'worker').toList();
        } else if (callerRole == 'super_admin') {
          users =
              users.where((u) => u.role != 'super_admin').toList();
        }

        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
        _applyFilters();
        _animController.forward(from: 0);
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed to load users';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<ManagedUser> result = List.from(_allUsers);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((u) {
        return u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q);
      }).toList();
    }

    if (_roleFilter != 'all') {
      result = result.where((u) => u.role == _roleFilter).toList();
    }

    if (_statusFilter != 'all') {
      final active = _statusFilter == 'active';
      result = result.where((u) => u.isActive == active).toList();
    }

    setState(() => _filteredUsers = result);
  }

  Future<void> _toggleStatus(ManagedUser user) async {
    if (!_canManage(user)) {
      _showSnackbar('Permission denied', isError: true);
      return;
    }

    final newStatus = !user.isActive;
    final actionWord = newStatus ? 'activate' : 'deactivate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${actionWord[0].toUpperCase()}${actionWord.substring(1)} User'),
        content: Text(
            'Are you sure you want to $actionWord ${user.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
              newStatus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
            child: Text(actionWord[0].toUpperCase() +
                actionWord.substring(1)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _service.toggleUserStatus(user.id, newStatus);
      if (res['success'] == true) {
        setState(() {
          user.isActive = newStatus;
        });
        _showSnackbar(
            '${user.name} has been ${newStatus ? "activated" : "deactivated"}');
      } else {
        _showSnackbar(res['message'] ?? 'Failed to update status',
            isError: true);
      }
    } catch (e) {
      _showSnackbar('Error: $e', isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: _loadUsers,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text(
                      'User Management',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _callerRole == 'super_admin'
                          ? 'Manage admins and workers across your organisation'
                          : 'Manage worker accounts',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ]),
                  // Summary chips
                  Row(children: [
                    _summaryChip(
                        '${_allUsers.where((u) => u.isActive).length} Active',
                        const Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    _summaryChip(
                        '${_allUsers.where((u) => !u.isActive).length} Inactive',
                        const Color(0xFFEF4444)),
                    const SizedBox(width: 10),
                    _summaryChip(
                        '${_allUsers.length} Total', const Color(0xFF7C3AED)),
                  ]),
                ],
              ),
              const SizedBox(height: 28),

              // ── Filters row
              Row(children: [
                // Search
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                      Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
                    ),
                    child: TextField(
                      onChanged: (v) {
                        _searchQuery = v;
                        _applyFilters();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name or email…',
                        hintStyle:
                        TextStyle(color: Colors.grey[400], fontSize: 13),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey[400], size: 20),
                        border: InputBorder.none,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Role filter
                if (_callerRole == 'super_admin') ...[
                  _filterDropdown(
                    value: _roleFilter,
                    items: const {
                      'all': 'All Roles',
                      'admin': 'Admins',
                      'worker': 'Workers'
                    },
                    onChanged: (v) {
                      _roleFilter = v!;
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 12),
                ],
                // Status filter
                _filterDropdown(
                  value: _statusFilter,
                  items: const {
                    'all': 'All Status',
                    'active': 'Active',
                    'inactive': 'Inactive'
                  },
                  onChanged: (v) {
                    _statusFilter = v!;
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 12),
                // Refresh
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                    Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Color(0xFF7C3AED), size: 20),
                    onPressed: _loadUsers,
                    tooltip: 'Refresh',
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // ── Table
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border:
                  Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(children: [
                  // Table header
                  _tableHeader(),
                  const Divider(height: 1, color: Color(0xFFF0F0F5)),

                  if (_filteredUsers.isEmpty)
                    _emptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredUsers.length,
                      separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF5F5FA)),
                      itemBuilder: (_, i) =>
                          _userRow(_filteredUsers[i], i),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────────

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  Widget _filterDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2D3142),
              fontWeight: FontWeight.w500),
          items: items.entries
              .map((e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: [
        const SizedBox(width: 52),
        Expanded(
            flex: 3,
            child: _headerText('USER')),
        Expanded(
            flex: 2,
            child: _headerText('EMAIL')),
        Expanded(
            child: _headerText('ROLE')),
        Expanded(
            child: _headerText('STATUS')),
        Expanded(
            child: _headerText('JOINED')),
        const SizedBox(width: 100, child: Text('ACTION',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF), letterSpacing: 0.8))),
      ]),
    );
  }

  Widget _headerText(String t) => Text(t,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.8));

  Widget _userRow(ManagedUser user, int index) {
    final canToggle = _canManage(user);
    final roleColor = user.role == 'admin'
        ? const Color(0xFF7C3AED)
        : const Color(0xFF3B82F6);

    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + index * 30),
      color: Colors.transparent,
      child: InkWell(
        onTap: canToggle ? () => _showUserDetail(user) : null,
        hoverColor: const Color(0xFFFAFAFC),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    roleColor,
                    roleColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name
            Expanded(
              flex: 3,
              child: Text(user.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3142)),
                  overflow: TextOverflow.ellipsis),
            ),

            // Email
            Expanded(
              flex: 2,
              child: Text(user.email,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ),

            // Role badge
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: roleColor.withOpacity(0.2)),
                ),
                child: Text(
                  user.role[0].toUpperCase() + user.role.substring(1),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: roleColor),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Status badge
            Expanded(
              child: Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user.isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
                Text(
                  user.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: user.isActive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444)),
                ),
              ]),
            ),

            // Joined date
            Expanded(
              child: Text(
                '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),

            // Toggle action
            SizedBox(
              width: 100,
              child: canToggle
                  ? _toggleSwitch(user)
                  : Tooltip(
                message: 'No permission',
                child: Icon(Icons.lock_outline,
                    size: 16, color: Colors.grey[300]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _toggleSwitch(ManagedUser user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: user.isActive,
            onChanged: (_) => _toggleStatus(user),
            activeColor: const Color(0xFF10B981),
            inactiveThumbColor: const Color(0xFFEF4444),
            inactiveTrackColor: const Color(0xFFEF4444).withOpacity(0.2),
            activeTrackColor: const Color(0xFF10B981).withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(children: [
          Icon(Icons.people_outline, size: 52, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No users found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400])),
          const SizedBox(height: 4),
          Text('Try adjusting your search or filters',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ]),
      ),
    );
  }

  // ── User detail bottom sheet ────────────────────────────────────────────

  void _showUserDetail(ManagedUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(
        user: user,
        canToggle: _canManage(user),
        onToggle: () => _toggleStatus(user),
      ),
    );
  }
}

// ─── User Detail Bottom Sheet ─────────────────────────────────────────────

class _UserDetailSheet extends StatelessWidget {
  final ManagedUser user;
  final bool canToggle;
  final VoidCallback onToggle;

  const _UserDetailSheet({
    required this.user,
    required this.canToggle,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = user.role == 'admin'
        ? const Color(0xFF7C3AED)
        : const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(2)),
        ),

        // Avatar + name
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [roleColor, roleColor.withOpacity(0.6)]),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              user.name[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(user.name,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142))),
        const SizedBox(height: 4),
        Text(user.email,
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 20),

        // Info row
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _infoBadge(
              user.role[0].toUpperCase() + user.role.substring(1),
              roleColor,
              Icons.shield_outlined),
          const SizedBox(width: 12),
          _infoBadge(
              user.isActive ? 'Active' : 'Inactive',
              user.isActive
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              user.isActive
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined),
          const SizedBox(width: 12),
          _infoBadge(
              'Joined ${user.createdAt.year}',
              const Color(0xFFF59E0B),
              Icons.calendar_today_outlined),
        ]),

        if (canToggle) ...[
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onToggle();
              },
              icon: Icon(
                  user.isActive ? Icons.person_off_outlined : Icons.person_outlined),
              label: Text(user.isActive
                  ? 'Deactivate ${user.name}'
                  : 'Activate ${user.name}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: user.isActive
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 8),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ]),
    );
  }

  Widget _infoBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}