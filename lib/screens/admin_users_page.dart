import 'package:flutter/material.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final List<Map<String, dynamic>> _mockUsers = [
    {
      'id': '1',
      'full_name': 'Chia Richcal',
      'email': 'ankiambomrichcal.chia@ictuniversity.edu.cm',
      'role': 'admin',
      'points': 1250,
      'uploads': 12,
    },
    {
      'id': '2',
      'full_name': 'John Doe',
      'email': 'john.doe@gmail.com',
      'role': 'student',
      'points': 840,
      'uploads': 5,
    },
    {
      'id': '3',
      'full_name': 'Sarah Smith',
      'email': 'sarah@ubuea.cm',
      'role': 'student',
      'points': 720,
      'uploads': 8,
    },
    {
      'id': '4',
      'full_name': 'Mary Jane',
      'email': 'mary@unibe.it',
      'role': 'moderator',
      'points': 450,
      'uploads': 3,
    },
  ];

  String _query = '';
  String _roleFilter = 'all';

  List<Map<String, dynamic>> get _filteredUsers {
    return _mockUsers.where((u) {
      final role = (u['role'] ?? '').toString().toLowerCase();
      final q = _query.trim().toLowerCase();
      final matchesRole = _roleFilter == 'all' || role == _roleFilter;
      final matchesQuery =
          q.isEmpty ||
          (u['full_name'] ?? '').toString().toLowerCase().contains(q) ||
          (u['email'] ?? '').toString().toLowerCase().contains(q);
      return matchesRole && matchesQuery;
    }).toList();
  }

  Future<void> _openSearch() async {
    final ctrl = TextEditingController(text: _query);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search users'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Name or email'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (updated == null) return;
    setState(() => _query = updated);
  }

  Future<void> _openFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All roles'),
              onTap: () => Navigator.pop(context, 'all'),
            ),
            ListTile(
              title: const Text('Admin'),
              onTap: () => Navigator.pop(context, 'admin'),
            ),
            ListTile(
              title: const Text('Moderator'),
              onTap: () => Navigator.pop(context, 'moderator'),
            ),
            ListTile(
              title: const Text('Student'),
              onTap: () => Navigator.pop(context, 'student'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _roleFilter = selected);
  }

  void _handleAction(String action, int index) {
    if (index < 0 || index >= _filteredUsers.length) return;
    final target = _filteredUsers[index];
    final originalIndex = _mockUsers.indexOf(target);
    if (originalIndex == -1) return;

    if (action == 'promote') {
      setState(() => _mockUsers[originalIndex]['role'] = 'admin');
      return;
    }
    if (action == 'revoke') {
      setState(() => _mockUsers[originalIndex]['role'] = 'student');
      return;
    }
    if (action == 'block') {
      setState(() => _mockUsers.removeAt(originalIndex));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilter,
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredUsers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          final String role = user['role'] ?? 'student';

          return Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  (user['full_name'] as String).substring(0, 1),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              title: Text(
                user['full_name'],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    user['email'],
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _roleColor(role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _roleColor(role).withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _roleColor(role),
                          ),
                        ),
                      ),
                      Text(
                        '•  ${user['points']} Points',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        '•  ${user['uploads']} Uploads',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => _handleAction(value, index),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'promote',
                    child: Text('Make Admin'),
                  ),
                  const PopupMenuItem(
                    value: 'revoke',
                    child: Text('Revoke Admin'),
                  ),
                  const PopupMenuItem(
                    value: 'block',
                    child: Text(
                      'Block User',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.deepPurple;
      case 'moderator':
        return Color(0xFF003F98);
      default:
        return Colors.green;
    }
  }
}
