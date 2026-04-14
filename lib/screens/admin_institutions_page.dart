import 'package:flutter/material.dart';

import '../data/supabase_backend.dart';

class AdminInstitutionsPage extends StatefulWidget {
  const AdminInstitutionsPage({super.key});

  @override
  State<AdminInstitutionsPage> createState() => _AdminInstitutionsPageState();
}

class _AdminInstitutionsPageState extends State<AdminInstitutionsPage> {
  List<Map<String, dynamic>> _institutions = const [];
  Map<String, Map<String, int>> _statsByInstitution = const {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final backend = SupabaseBackend.instance;
      final institutions = await backend.fetchAdminInstitutions();
      final usageStats = await backend.fetchInstitutionUsageStats();

      if (!mounted) return;
      setState(() {
        _institutions = institutions;
        _statsByInstitution = usageStats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addInstitution() async {
    final nameCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Institution'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (created != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    try {
      await SupabaseBackend.instance.addInstitution(name: name);
      if (!mounted) return;
      await _loadInstitutions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Institution added.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add institution: $e')),
      );
    }
  }

  Future<void> _deleteInstitution(Map<String, dynamic> institution) async {
    final id = (institution['id'] ?? '').toString().trim();
    final name = (institution['name'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Institution'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseBackend.instance.deleteInstitution(institutionId: id);
      if (!mounted) return;
      await _loadInstitutions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Institution deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete institution: $e')),
      );
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 30),
              const SizedBox(height: 10),
              Text(
                'Failed to load institutions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInstitutions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_institutions.isEmpty) {
      return const Center(
        child: Text('No institutions yet. Tap + to add one.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInstitutions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _institutions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final inst = _institutions[index];
          final name = (inst['name'] ?? '').toString();
          final status = (inst['status'] ?? 'verified').toString();
          final stats = _statsByInstitution[name] ?? const {};
          final papers = stats['papers'] ?? 0;
          final contributors = stats['contributors'] ?? 0;

          return Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.school,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '$papers Papers  •  $contributors Contributors',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (status == 'verified' ? Colors.green : Colors.orange)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            (status == 'verified' ? Colors.green : Colors.orange)
                                .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (status == 'verified'
                            ? Colors.green
                            : Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteInstitution(inst),
                tooltip: 'Delete institution',
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Institutions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInstitutions,
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: _addInstitution),
        ],
      ),
      body: _buildBody(),
    );
  }
}
