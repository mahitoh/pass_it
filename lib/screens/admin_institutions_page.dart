import 'package:flutter/material.dart';

class AdminInstitutionsPage extends StatefulWidget {
  const AdminInstitutionsPage({super.key});

  @override
  State<AdminInstitutionsPage> createState() => _AdminInstitutionsPageState();
}

class _AdminInstitutionsPageState extends State<AdminInstitutionsPage> {
  final List<Map<String, dynamic>> _mockInstitutions = [
    {
      'name': 'ICT University',
      'papers': 245,
      'members': 1420,
      'status': 'verified',
    },
    {
      'name': 'University of Buea',
      'papers': 158,
      'members': 980,
      'status': 'verified',
    },
    {
      'name': 'Government Bilingual High School, Yaounde',
      'papers': 89,
      'members': 540,
      'status': 'pending',
    },
    {
      'name': 'University of Bamenda',
      'papers': 112,
      'members': 670,
      'status': 'verified',
    },
  ];

  Future<void> _addInstitution() async {
    final nameCtrl = TextEditingController();
    final papersCtrl = TextEditingController();
    final membersCtrl = TextEditingController();

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
            TextField(
              controller: papersCtrl,
              decoration: const InputDecoration(labelText: 'Papers'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: membersCtrl,
              decoration: const InputDecoration(labelText: 'Contributors'),
              keyboardType: TextInputType.number,
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

    setState(() {
      _mockInstitutions.insert(0, {
        'name': name,
        'papers': int.tryParse(papersCtrl.text.trim()) ?? 0,
        'members': int.tryParse(membersCtrl.text.trim()) ?? 0,
        'status': 'pending',
      });
    });
  }

  void _handleInstitutionAction(String action, int index) {
    if (!mounted || index < 0 || index >= _mockInstitutions.length) return;

    if (action == 'verify') {
      setState(() => _mockInstitutions[index]['status'] = 'verified');
      return;
    }

    if (action == 'delete') {
      setState(() => _mockInstitutions.removeAt(index));
      return;
    }

    if (action == 'edit') {
      final ctrl = TextEditingController(
        text: _mockInstitutions[index]['name'],
      );
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Edit Institution'),
          content: TextField(controller: ctrl),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final next = ctrl.text.trim();
                if (next.isNotEmpty) {
                  setState(() => _mockInstitutions[index]['name'] = next);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening papers list is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Institutions'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addInstitution),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _mockInstitutions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final inst = _mockInstitutions[index];
          final String status = inst['status'] ?? 'verified';

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
              title: Text(
                inst['name'],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${inst['papers']} Papers  •  ${inst['members']} Contributors',
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
                            (status == 'verified'
                                    ? Colors.green
                                    : Colors.orange)
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
              trailing: PopupMenuButton<String>(
                onSelected: (value) => _handleInstitutionAction(value, index),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Info')),
                  const PopupMenuItem(
                    value: 'papers',
                    child: Text('View Papers'),
                  ),
                  const PopupMenuItem(value: 'verify', child: Text('Verify')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
