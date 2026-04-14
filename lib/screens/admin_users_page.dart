import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/supabase_backend.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> _users = const [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final backend = SupabaseBackend.instance;
      final rows = await backend.fetchAdminUsers();
      final uploadCounts = await backend.fetchUploadCountsByUser();
      await backend.fetchAdminUsageStats(); // keep RPC call; result unused


      final mapped = rows.map((row) {
        final id = row['id'].toString();
        return {
          'id': id,
          'name': (row['full_name'] ?? 'Unnamed Entity').toString(),
          'email': row['email'].toString(),
          'role': (row['user_type'] ?? 'student').toString(),
          'points': row['points_balance'] ?? 0,
          'uploads': uploadCounts[id] ?? 0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _users = mapped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _users.where((u) => u['name'].toLowerCase().contains(_query.toLowerCase()) || u['email'].toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Nexus Directory', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search neural signal...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final user = filtered[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _roleColor(user['role']).withValues(alpha: 0.1),
                      child: Text(user['name'][0].toUpperCase(), style: TextStyle(color: _roleColor(user['role']), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['name'], style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(user['email'], style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${user['points']} pts', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: cs.primary)),
                        Text('${user['uploads']} items', style: GoogleFonts.inter(fontSize: 10, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Color _roleColor(String role) {
    if (role == 'admin') return Colors.indigo;
    if (role == 'moderator') return Colors.teal;
    return Colors.blueGrey;
  }
}
