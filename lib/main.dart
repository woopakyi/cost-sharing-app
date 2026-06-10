import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(CostSharingApp(store: AppStore(preferences)..load()));
}

class CostSharingApp extends StatelessWidget {
  const CostSharingApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Cost Sharing Ledger',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff1d7a72),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            cardTheme: const CardThemeData(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
          home: HomeShell(store: store),
        );
      },
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final selected = store.selectedProject;

    return Scaffold(
      backgroundColor: const Color(0xfff5f7f5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            if (compact) {
              return Column(
                children: [
                  _TopBar(store: store),
                  Expanded(
                    child: selected == null
                        ? _ProjectList(store: store)
                        : _ProjectWorkspace(store: store, project: selected),
                  ),
                ],
              );
            }

            return Row(
              children: [
                SizedBox(width: 340, child: _ProjectList(store: store)),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(store: store),
                      Expanded(
                        child: selected == null
                            ? _EmptyWorkspace(
                                onCreate: () =>
                                    _showProjectDialog(context, store),
                              )
                            : _ProjectWorkspace(
                                store: store,
                                project: selected,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final user = store.signedInEmail;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cost Sharing Ledger',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Web-first cost sharing, receipts, members, checkout, and sharing',
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () {
              if (user == null) {
                store.signInDemo();
                _showSnack(
                  context,
                  'Demo Google sign-in enabled. Add Firebase to use real Google Auth and cloud sync.',
                );
              } else {
                store.signOut();
              }
            },
            icon: Icon(user == null ? Icons.login : Icons.logout),
            label: Text(user ?? 'Continue with Google'),
          ),
        ],
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Projects',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _showProjectDialog(context, store),
                icon: const Icon(Icons.add),
                tooltip: 'Create project',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SyncNotice(store: store),
          const SizedBox(height: 14),
          Expanded(
            child: store.projects.isEmpty
                ? Center(
                    child: Text(
                      'Create your first project to start recording receipts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  )
                : ListView.separated(
                    itemCount: store.projects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final project = store.projects[index];
                      final selected = project.id == store.selectedProjectId;
                      return ListTile(
                        selected: selected,
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        title: Text(
                          project.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${project.receipts.length} receipts · ${project.members.length} members',
                        ),
                        trailing: Icon(
                          project.isCloudBacked
                              ? Icons.cloud_done
                              : Icons.devices,
                        ),
                        onTap: () => store.selectProject(project.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final signedIn = store.signedInEmail != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: signedIn ? const Color(0xffe8f5e9) : const Color(0xfffff8e1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(signedIn ? Icons.cloud_sync : Icons.storage),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              signedIn
                  ? 'Signed in. Existing local projects are marked cloud-ready; connect Firebase to sync them between devices.'
                  : 'Guest mode. Projects are saved in this browser using local storage.',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.group_work,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No project selected',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Create or select a project to manage shared spending.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create project'),
          ),
        ],
      ),
    );
  }
}

class _ProjectWorkspace extends StatelessWidget {
  const _ProjectWorkspace({required this.store, required this.project});

  final AppStore store;
  final CostProject project;

  @override
  Widget build(BuildContext context) {
    final totals = project.openBalanceByMember;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProjectHeader(store: store, project: project),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _SummaryCard(
                title: 'Open total',
                value: money(project.openTotal),
                icon: Icons.payments,
              ),
              _SummaryCard(
                title: 'Receipts',
                value: '${project.receipts.length}',
                icon: Icons.receipt,
              ),
              _SummaryCard(
                title: 'Done',
                value: '${project.receipts.where((r) => r.isDone).length}',
                icon: Icons.task_alt,
              ),
              _SummaryCard(
                title: 'Members',
                value: '${project.members.length}',
                icon: Icons.people,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MembersCard(store: store, project: project, totals: totals),
          const SizedBox(height: 18),
          _ReceiptsCard(store: store, project: project),
        ],
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.store, required this.project});

  final AppStore store;
  final CostProject project;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff145c57), Color(0xff28a195)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  project.isCloudBacked
                      ? 'Cloud-ready project'
                      : 'Stored locally in this browser',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _showReceiptDialog(context, store, project),
                icon: const Icon(Icons.add),
                label: const Text('Receipt'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showCheckoutDialog(context, store, project),
                icon: const Icon(Icons.done_all),
                label: const Text('Checkout'),
              ),
              IconButton.filledTonal(
                onPressed: () => _shareProject(context, store, project),
                icon: const Icon(Icons.share),
                tooltip: 'Share project',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade700)),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({
    required this.store,
    required this.project,
    required this.totals,
  });

  final AppStore store;
  final CostProject project;
  final Map<String, double> totals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Members and current balance',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showMemberDialog(context, store, project),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Member'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (project.members.isEmpty)
              const Text('Add members to split receipt items.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: project.members.map((member) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Color(member.colorValue),
                      child: Text(member.name.characters.first.toUpperCase()),
                    ),
                    label: Text(
                      '${member.name}: ${money(totals[member.id] ?? 0)}',
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptsCard extends StatelessWidget {
  const _ReceiptsCard({required this.store, required this.project});

  final AppStore store;
  final CostProject project;

  @override
  Widget build(BuildContext context) {
    final receipts = project.sortedReceipts;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Receipts',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI receipt import coming later'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _showReceiptDialog(context, store, project),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Manual entry'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (receipts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No receipts yet. Add a manual receipt to start.',
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: receipts.length,
                separatorBuilder: (_, _) => const Divider(height: 24),
                itemBuilder: (context, index) =>
                    _ReceiptTile(project: project, receipt: receipts[index]),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.project, required this.receipt});

  final CostProject project;
  final CostReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd-MM-yyyy').format(receipt.date);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: receipt.isDone
            ? Colors.green.shade100
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(receipt.isDone ? Icons.check : Icons.receipt_long),
      ),
      title: Text(
        '$date · ${receipt.storeName}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${receipt.items.length} items · ${receipt.isDone ? 'checked out' : 'open'}',
      ),
      trailing: Text(
        money(receipt.totalCost),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      children: [
        ...receipt.items.map((item) {
          final splitText = item.splits
              .map((split) {
                final member =
                    project.memberById(split.memberId)?.name ?? 'Unknown';
                return '$member ${split.percent.toStringAsFixed(0)}%';
              })
              .join(', ');
          return ListTile(
            dense: true,
            title: Text(
              '${item.name} ${money(item.unitCost)} x${item.quantity}',
            ),
            subtitle: Text(splitText),
            trailing: Text(money(item.totalCost)),
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            children: project.members.map((member) {
              return Chip(
                label: Text(
                  '${member.name}: ${money(receipt.totalForMember(member.id))}',
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

Future<void> _showProjectDialog(BuildContext context, AppStore store) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create project'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Project name',
          hintText: 'e.g. Korea trip',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (name != null && name.trim().isNotEmpty) {
    store.createProject(name.trim());
  }
}

Future<void> _showMemberDialog(
  BuildContext context,
  AppStore store,
  CostProject project,
) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add member'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Member name',
          hintText: 'e.g. Anny',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  if (name != null && name.trim().isNotEmpty) {
    store.addMember(project.id, name.trim());
  }
}

Future<void> _showReceiptDialog(
  BuildContext context,
  AppStore store,
  CostProject project,
) async {
  if (project.members.isEmpty) {
    _showSnack(context, 'Add at least one member before creating a receipt.');
    return;
  }
  final receipt = await showDialog<CostReceipt>(
    context: context,
    builder: (context) => ReceiptEditorDialog(project: project),
  );
  if (receipt != null) {
    store.addReceipt(project.id, receipt);
  }
}

Future<void> _showCheckoutDialog(
  BuildContext context,
  AppStore store,
  CostProject project,
) async {
  final openReceipts = project.sortedReceipts
      .where((receipt) => !receipt.isDone)
      .toList();
  if (openReceipts.isEmpty) {
    _showSnack(context, 'No open receipts to checkout.');
    return;
  }
  final selected = <String>{};
  final result = await showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Checkout receipts'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: openReceipts.map((receipt) {
              return CheckboxListTile(
                value: selected.contains(receipt.id),
                onChanged: (checked) {
                  setDialogState(() {
                    if (checked ?? false) {
                      selected.add(receipt.id);
                    } else {
                      selected.remove(receipt.id);
                    }
                  });
                },
                title: Text(
                  '${DateFormat('dd-MM-yyyy').format(receipt.date)} · ${receipt.storeName}',
                ),
                subtitle: Text(money(receipt.totalCost)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, selected),
            child: const Text('Mark done'),
          ),
        ],
      ),
    ),
  );
  if (result != null && result.isNotEmpty) {
    store.checkout(project.id, result);
  }
}

void _shareProject(BuildContext context, AppStore store, CostProject project) {
  if (store.signedInEmail == null) {
    _showSnack(
      context,
      'Sign in before sharing a project. Firebase Auth and Firestore are needed for real invitations.',
    );
    return;
  }
  _showSnack(
    context,
    'Sharing UI is ready; connect Firestore rules and invite links to send real invitations.',
  );
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class ReceiptEditorDialog extends StatefulWidget {
  const ReceiptEditorDialog({super.key, required this.project});

  final CostProject project;

  @override
  State<ReceiptEditorDialog> createState() => _ReceiptEditorDialogState();
}

class _ReceiptEditorDialogState extends State<ReceiptEditorDialog> {
  final _storeController = TextEditingController();
  DateTime _date = DateTime.now();
  late final List<_ItemDraft> _items;

  @override
  void initState() {
    super.initState();
    _items = [_ItemDraft(widget.project.members)];
  }

  @override
  void dispose() {
    _storeController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual receipt entry'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _storeController,
                      decoration: const InputDecoration(
                        labelText: 'Store name',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(DateFormat('dd-MM-yyyy').format(_date)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ..._items.indexed.map(
                (entry) => _buildItemEditor(entry.$1, entry.$2),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _items.add(_ItemDraft(widget.project.members)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save receipt')),
      ],
    );
  }

  Widget _buildItemEditor(int index, _ItemDraft item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: .08)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: item.nameController,
                  decoration: InputDecoration(
                    labelText: 'Item ${index + 1}',
                    hintText: 'Apple juice',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: item.costController,
                  decoration: const InputDecoration(labelText: 'Unit cost'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: item.quantityController,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(
                onPressed: _items.length == 1
                    ? null
                    : () => setState(() {
                        _items.removeAt(index).dispose();
                      }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.project.members.map((member) {
              return SizedBox(
                width: 150,
                child: TextField(
                  controller: item.splitControllers[member.id],
                  decoration: InputDecoration(labelText: '${member.name} %'),
                  keyboardType: TextInputType.number,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _save() {
    final store = _storeController.text.trim();
    if (store.isEmpty) {
      _showSnack(context, 'Enter a store name.');
      return;
    }

    final items = <ReceiptItem>[];
    for (final draft in _items) {
      final name = draft.nameController.text.trim();
      final cost = double.tryParse(draft.costController.text.trim());
      final quantity = int.tryParse(draft.quantityController.text.trim());
      final splits = <SplitAllocation>[];

      for (final member in widget.project.members) {
        final percent =
            double.tryParse(
              draft.splitControllers[member.id]?.text.trim() ?? '',
            ) ??
            0;
        if (percent > 0) {
          splits.add(SplitAllocation(memberId: member.id, percent: percent));
        }
      }

      final totalPercent = splits.fold<double>(
        0,
        (sum, split) => sum + split.percent,
      );
      if (name.isEmpty ||
          cost == null ||
          cost <= 0 ||
          quantity == null ||
          quantity <= 0) {
        _showSnack(
          context,
          'Each item needs a name, positive unit cost, and positive quantity.',
        );
        return;
      }
      if ((totalPercent - 100).abs() > .01) {
        _showSnack(context, 'Each item split must add up to 100%.');
        return;
      }

      items.add(
        ReceiptItem(
          id: createId(),
          name: name,
          unitCost: cost,
          quantity: quantity,
          splits: splits,
        ),
      );
    }

    Navigator.pop(
      context,
      CostReceipt(id: createId(), date: _date, storeName: store, items: items),
    );
  }
}

class _ItemDraft {
  _ItemDraft(List<ProjectMember> members) {
    if (members.isNotEmpty) {
      splitControllers[members.first.id] = TextEditingController(text: '100');
      for (final member in members.skip(1)) {
        splitControllers[member.id] = TextEditingController(text: '0');
      }
    }
  }

  final nameController = TextEditingController();
  final costController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final Map<String, TextEditingController> splitControllers = {};

  void dispose() {
    nameController.dispose();
    costController.dispose();
    quantityController.dispose();
    for (final controller in splitControllers.values) {
      controller.dispose();
    }
  }
}

class AppStore extends ChangeNotifier {
  AppStore(this._preferences);

  static const _projectsKey = 'cost_sharing_projects_v1';
  static const _emailKey = 'cost_sharing_demo_email_v1';

  final SharedPreferences _preferences;
  final List<CostProject> projects = [];
  String? selectedProjectId;
  String? signedInEmail;

  CostProject? get selectedProject {
    for (final project in projects) {
      if (project.id == selectedProjectId) return project;
    }
    return projects.isEmpty ? null : projects.first;
  }

  void load() {
    signedInEmail = _preferences.getString(_emailKey);
    final raw = _preferences.getString(_projectsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      projects.addAll(
        decoded.map(
          (item) => CostProject.fromJson(item as Map<String, dynamic>),
        ),
      );
    }
    if (projects.isNotEmpty) selectedProjectId = projects.first.id;
  }

  Future<void> _save() async {
    await _preferences.setString(
      _projectsKey,
      jsonEncode(projects.map((project) => project.toJson()).toList()),
    );
    if (signedInEmail == null) {
      await _preferences.remove(_emailKey);
    } else {
      await _preferences.setString(_emailKey, signedInEmail!);
    }
    notifyListeners();
  }

  void selectProject(String id) {
    selectedProjectId = id;
    notifyListeners();
  }

  void createProject(String name) {
    final project = CostProject(
      id: createId(),
      name: name,
      createdAt: DateTime.now(),
      isCloudBacked: signedInEmail != null,
      ownerEmail: signedInEmail,
    );
    projects.insert(0, project);
    selectedProjectId = project.id;
    _save();
  }

  void addMember(String projectId, String name) {
    final project = _project(projectId);
    project.members.add(
      ProjectMember(
        id: createId(),
        name: name,
        colorValue: memberColors[project.members.length % memberColors.length],
      ),
    );
    _save();
  }

  void addReceipt(String projectId, CostReceipt receipt) {
    _project(projectId).receipts.add(receipt);
    _save();
  }

  void checkout(String projectId, Set<String> receiptIds) {
    for (final receipt in _project(projectId).receipts) {
      if (receiptIds.contains(receipt.id)) receipt.isDone = true;
    }
    _save();
  }

  void signInDemo() {
    signedInEmail = 'demo.user@gmail.com';
    for (final project in projects) {
      project.isCloudBacked = true;
      project.ownerEmail ??= signedInEmail;
    }
    _save();
  }

  void signOut() {
    signedInEmail = null;
    _save();
  }

  CostProject _project(String id) =>
      projects.firstWhere((project) => project.id == id);
}

class CostProject {
  CostProject({
    required this.id,
    required this.name,
    required this.createdAt,
    this.ownerEmail,
    this.isCloudBacked = false,
    List<ProjectMember>? members,
    List<CostReceipt>? receipts,
  }) : members = members ?? [],
       receipts = receipts ?? [];

  final String id;
  final String name;
  final DateTime createdAt;
  String? ownerEmail;
  bool isCloudBacked;
  final List<ProjectMember> members;
  final List<CostReceipt> receipts;

  List<CostReceipt> get sortedReceipts =>
      [...receipts]..sort((a, b) => b.date.compareTo(a.date));
  double get openTotal => receipts
      .where((receipt) => !receipt.isDone)
      .fold(0, (sum, receipt) => sum + receipt.totalCost);

  Map<String, double> get openBalanceByMember {
    final result = {for (final member in members) member.id: 0.0};
    for (final receipt in receipts.where((receipt) => !receipt.isDone)) {
      for (final member in members) {
        result[member.id] =
            (result[member.id] ?? 0) + receipt.totalForMember(member.id);
      }
    }
    return result;
  }

  ProjectMember? memberById(String id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  factory CostProject.fromJson(Map<String, dynamic> json) => CostProject(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    ownerEmail: json['ownerEmail'] as String?,
    isCloudBacked: json['isCloudBacked'] as bool? ?? false,
    members: (json['members'] as List<dynamic>? ?? [])
        .map((item) => ProjectMember.fromJson(item as Map<String, dynamic>))
        .toList(),
    receipts: (json['receipts'] as List<dynamic>? ?? [])
        .map((item) => CostReceipt.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'ownerEmail': ownerEmail,
    'isCloudBacked': isCloudBacked,
    'members': members.map((member) => member.toJson()).toList(),
    'receipts': receipts.map((receipt) => receipt.toJson()).toList(),
  };
}

class ProjectMember {
  const ProjectMember({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  final String id;
  final String name;
  final int colorValue;

  factory ProjectMember.fromJson(Map<String, dynamic> json) => ProjectMember(
    id: json['id'] as String,
    name: json['name'] as String,
    colorValue: json['colorValue'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
  };
}

class CostReceipt {
  CostReceipt({
    required this.id,
    required this.date,
    required this.storeName,
    required this.items,
    this.isDone = false,
  });

  final String id;
  final DateTime date;
  final String storeName;
  final List<ReceiptItem> items;
  bool isDone;

  double get totalCost => items.fold(0, (sum, item) => sum + item.totalCost);

  double totalForMember(String memberId) {
    return items.fold(0, (sum, item) {
      final allocation = item.splits
          .where((split) => split.memberId == memberId)
          .fold(0.0, (splitSum, split) => splitSum + split.percent);
      return sum + item.totalCost * allocation / 100;
    });
  }

  factory CostReceipt.fromJson(Map<String, dynamic> json) => CostReceipt(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    storeName: json['storeName'] as String,
    isDone: json['isDone'] as bool? ?? false,
    items: (json['items'] as List<dynamic>)
        .map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'storeName': storeName,
    'isDone': isDone,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.name,
    required this.unitCost,
    required this.quantity,
    required this.splits,
  });

  final String id;
  final String name;
  final double unitCost;
  final int quantity;
  final List<SplitAllocation> splits;

  double get totalCost => unitCost * quantity;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
    id: json['id'] as String,
    name: json['name'] as String,
    unitCost: (json['unitCost'] as num).toDouble(),
    quantity: json['quantity'] as int,
    splits: (json['splits'] as List<dynamic>)
        .map((item) => SplitAllocation.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unitCost': unitCost,
    'quantity': quantity,
    'splits': splits.map((split) => split.toJson()).toList(),
  };
}

class SplitAllocation {
  const SplitAllocation({required this.memberId, required this.percent});

  final String memberId;
  final double percent;

  factory SplitAllocation.fromJson(Map<String, dynamic> json) =>
      SplitAllocation(
        memberId: json['memberId'] as String,
        percent: (json['percent'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'memberId': memberId, 'percent': percent};
}

String createId() => DateTime.now().microsecondsSinceEpoch.toString();
String money(double value) =>
    NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(value);

const memberColors = [
  0xffffcc80,
  0xff90caf9,
  0xffa5d6a7,
  0xfff48fb1,
  0xffce93d8,
  0xffffab91,
  0xff80cbc4,
];
