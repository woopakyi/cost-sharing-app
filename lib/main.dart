import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          title: 'Cost Sharing App',
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Widget _buildTopBar() {
    return _TopBar(store: widget.store);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.store.selectedProject;

    return Scaffold(
      backgroundColor: const Color(0xfff5f7f5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            if (compact) {
              return Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: selected == null
                        ? _ProjectList(store: widget.store)
                        : _ProjectWorkspace(
                            store: widget.store,
                            project: selected,
                          ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                SizedBox(width: 380, child: _ProjectList(store: widget.store)),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: selected == null
                            ? _EmptyWorkspace(
                                onCreate: () =>
                                    _showProjectDialog(context, widget.store),
                              )
                            : _ProjectWorkspace(
                                store: widget.store,
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
  const _TopBar({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final user = store.signedInEmail;
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: compact ? () => _showProjectMenuSheet(context, store) : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cost Sharing App',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Web-first cost sharing, receipts, members, checkout, and sharing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        child: child,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1 + (animation.value * .03),
                            child: Material(
                              type: MaterialType.transparency,
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                    itemCount: store.projects.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      store.reorderProject(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final project = store.projects[index];
                      final selected = project.id == store.selectedProjectId;
                      return Padding(
                        key: ValueKey(project.id),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: selected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => store.selectProject(project.id),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 8, 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () => _showEditProjectDialog(
                                      context,
                                      store,
                                      project,
                                    ),
                                    icon: const Icon(Icons.more_vert_rounded),
                                    tooltip: 'Edit project',
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                project.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${project.receipts.length} receipts · ${project.members.length} members',
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    project.isCloudBacked
                                        ? Icons.cloud_done
                                        : Icons.devices,
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Icon(Icons.drag_indicator),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                canUseFullRowWhenExpanded: true,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  project.isCloudBacked
                      ? 'Cloud-ready project'
                      : 'Stored locally in this browser',
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            children: [
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

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.canUseFullRowWhenExpanded = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool canUseFullRowWhenExpanded;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 48;
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.value,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final contentWidth = 40 + 14 + textPainter.width + 40;
    final expandedWidth = contentWidth < 210 ? 210.0 : contentWidth.toDouble();
    final targetWidth = _expanded
        ? (widget.canUseFullRowWhenExpanded
              ? availableWidth
              : expandedWidth.clamp(210.0, availableWidth).toDouble())
        : 210.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: targetWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(child: Icon(widget.icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
              SizedBox(
                height: 72,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      child: child,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1 + (animation.value * .03),
                          child: Material(
                            type: MaterialType.transparency,
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                  itemCount: project.members.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    store.reorderMember(project.id, oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final member = project.members[index];
                    return Padding(
                      key: ValueKey(member.id),
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _showEditMemberDialog(
                          context,
                          store,
                          project,
                          member,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black.withValues(alpha: .08),
                            ),
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(member.colorValue),
                                child: Text(
                                  member.name.characters.first.toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${member.name}: ${money(totals[member.id] ?? 0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_indicator),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
                FilledButton.tonalIcon(
                  onPressed: () => _showAddReceiptOptionsDialog(
                    context,
                    store,
                    project,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Receipt'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _showCheckoutDialog(context, store, project),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Checkout'),
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
                itemBuilder: (context, index) => _ReceiptTile(
                  store: store,
                  project: project,
                  receipt: receipts[index],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({
    required this.store,
    required this.project,
    required this.receipt,
  });

  final AppStore store;
  final CostProject project;
  final CostReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd-MM-yyyy').format(receipt.date);
    final theme = Theme.of(context);
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      collapsedBackgroundColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      iconColor: theme.colorScheme.onSurface,
      collapsedIconColor: theme.colorScheme.onSurface,
      tilePadding: EdgeInsets.zero,
      leading: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showEditReceiptDialog(context, store, project, receipt),
        child: CircleAvatar(
          backgroundColor: receipt.isDone
              ? Colors.green.shade100
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(receipt.isDone ? Icons.check : Icons.receipt_long),
        ),
      ),
      title: Text(
        '$date · ${receipt.storeName}',
        style: const TextStyle(fontWeight: FontWeight.w800),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${receipt.items.length} items · '),
          Text(receipt.isDone ? 'checked out' : 'open'),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              if (receipt.isDone) {
                store.undoCheckout(project.id, receipt.id);
              } else {
                store.checkout(project.id, {receipt.id});
              }
            },
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
            ),
            child: Text(receipt.isDone ? 'Uncheckout' : 'Checkout'),
          ),
        ],
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              splitText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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

Future<void> _showEditProjectDialog(
  BuildContext context,
  AppStore store,
  CostProject project,
) async {
  final controller = TextEditingController(text: project.name);
  final result = await showDialog<Object>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit project'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Project name'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, 'delete');
          },
          child: const Text('Delete'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result == 'delete') {
    store.deleteProject(project.id);
    return;
  }
  if (result is String && result.trim().isNotEmpty) {
    store.updateProject(project.id, result.trim());
  }
}

Future<void> _showProjectMenuSheet(BuildContext context, AppStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.9,
              child: _ProjectList(store: store),
            ),
          );
        },
      ),
    ),
  );
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

Future<void> _showEditMemberDialog(
  BuildContext context,
  AppStore store,
  CostProject project,
  ProjectMember member,
) async {
  final controller = TextEditingController(text: member.name);
  final result = await showDialog<Object>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit member'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Member name'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'delete'),
          child: const Text('Delete'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result == 'delete') {
    store.deleteMember(project.id, member.id);
    return;
  }
  if (result is String && result.trim().isNotEmpty) {
    store.updateMemberName(project.id, member.id, result.trim());
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

Future<void> _showAddReceiptOptionsDialog(
  BuildContext context,
  AppStore store,
  CostProject project,
) async {
  final action = await showDialog<_AddReceiptAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add receipt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose how you want to add a receipt to this project.',
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, _AddReceiptAction.ai),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI import'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.pop(context, _AddReceiptAction.manual),
                icon: const Icon(Icons.edit_note),
                label: const Text('Manual entry'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  if (!context.mounted || action == null) return;

  switch (action) {
    case _AddReceiptAction.ai:
      _showSnack(context, 'AI receipt import coming later.');
      break;
    case _AddReceiptAction.manual:
      await _showReceiptDialog(context, store, project);
      break;
  }
}

Future<void> _showEditReceiptDialog(
  BuildContext context,
  AppStore store,
  CostProject project,
  CostReceipt receipt,
) async {
  final result = await showDialog<Object>(
    context: context,
    builder: (context) =>
        ReceiptEditorDialog(project: project, receipt: receipt),
  );
  if (result is CostReceipt) {
    store.updateReceipt(project.id, result);
  } else if (result == _ReceiptEditorAction.delete) {
    store.deleteReceipt(project.id, receipt.id);
  }
}

Future<void> _showCheckoutDialog(
  BuildContext context,
  AppStore store,
  CostProject project,
) async {
  if (project.sortedReceipts.where((receipt) => !receipt.isDone).isEmpty) {
    _showSnack(context, 'No open receipts to checkout.');
    return;
  }
  final selected = <String>{};
  final result = await showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final currentProject = store.projects.firstWhere(
            (item) => item.id == project.id,
            orElse: () => project,
          );
          final openReceipts = currentProject.sortedReceipts
              .where((receipt) => !receipt.isDone)
              .toList();
          selected.removeWhere(
            (receiptId) => !openReceipts.any((receipt) => receipt.id == receiptId),
          );

          if (openReceipts.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          }

          return AlertDialog(
            title: const Text('Checkout receipts'),
            content: SizedBox(
              width: 520,
              child: openReceipts.isEmpty
                  ? const Text('No open receipts to checkout.')
                  : ListView(
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
                          secondary: IconButton(
                            onPressed: () => _showEditReceiptDialog(
                              context,
                              store,
                              currentProject,
                              receipt,
                            ),
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'Edit receipt',
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          title: Text(
                            '${DateFormat('dd-MM-yyyy').format(receipt.date)} · ${receipt.storeName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                onPressed: selected.isEmpty || openReceipts.isEmpty
                    ? null
                    : () => Navigator.pop(context, selected),
                child: const Text('Mark done'),
              ),
            ],
          );
        },
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
  _showOverlaySnack(context, message);
}

void _showOverlaySnack(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  var removed = false;

  void removeEntry() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      bottom: 24,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), removeEntry);
}

enum _AddReceiptAction { ai, manual }

enum _ReceiptEditorAction { delete }

class ReceiptEditorDialog extends StatefulWidget {
  const ReceiptEditorDialog({super.key, required this.project, this.receipt});

  final CostProject project;
  final CostReceipt? receipt;

  @override
  State<ReceiptEditorDialog> createState() => _ReceiptEditorDialogState();
}

class _ReceiptEditorDialogState extends State<ReceiptEditorDialog> {
  final _storeController = TextEditingController();
  DateTime _date = DateTime.now();
  late final List<_ItemDraft> _items;

  void _handleSplitChanged(_ItemDraft item, String memberId, String value) {
    final percent = double.tryParse(value.trim()) ?? 0;
    item.setMemberInvolved(memberId, percent > 0, clearPercent: false);
    setState(() {});
  }

  List<ProjectMember> _membersForItem(_ItemDraft item) {
    final members = [...widget.project.members];
    for (final memberId in item.splitControllers.keys) {
      if (members.any((member) => member.id == memberId)) continue;
      final deletedMember = widget.project.memberById(memberId);
      if (deletedMember != null) {
        members.add(deletedMember);
      }
    }
    return members;
  }

  List<ProjectMember> _involvedMembersForItem(_ItemDraft item) {
    return _membersForItem(
      item,
    ).where((member) => item.isMemberInvolved(member.id)).toList();
  }

  double _itemTotalCost(_ItemDraft item) {
    final cost = double.tryParse(item.costController.text.trim()) ?? 0;
    final quantity = int.tryParse(item.quantityController.text.trim()) ?? 0;
    return cost * quantity;
  }

  double _itemTotalPercent(_ItemDraft item) {
    return item.splitControllers.keys.fold<double>(0, (sum, memberId) {
      final percent =
          double.tryParse(item.splitControllers[memberId]?.text.trim() ?? '') ??
          0;
      return sum + percent;
    });
  }

  Map<String, double> _draftMemberTotals() {
    final totals = {
      for (final member in widget.project.members) member.id: 0.0,
    };
    for (final item in _items) {
      final itemTotal = _itemTotalCost(item);
      for (final memberId in item.splitControllers.keys) {
        final percent =
            double.tryParse(
              item.splitControllers[memberId]?.text.trim() ?? '',
            ) ??
            0;
        totals[memberId] = (totals[memberId] ?? 0) + itemTotal * percent / 100;
      }
    }
    return totals;
  }

  void _applyAutoSplit(_ItemDraft item) {
    item.applyAutoSplit(_involvedMembersForItem(item));
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final receipt = widget.receipt;
    _storeController.text = receipt?.storeName ?? '';
    _date = receipt?.date ?? DateTime.now();
    _items = receipt == null
        ? [_ItemDraft(widget.project.members)]
        : receipt.items
              .map((item) => _ItemDraft(widget.project.members, item))
              .toList();
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
    final isEditing = widget.receipt != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit receipt' : 'Manual receipt entry'),
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
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _items.add(_ItemDraft(widget.project.members)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ),
              _ReceiptSplitPreview(
                project: widget.project,
                memberTotals: _draftMemberTotals(),
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
        if (isEditing)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _ReceiptEditorAction.delete),
            child: const Text('Delete'),
          ),
        FilledButton(onPressed: _save, child: const Text('Save receipt')),
      ],
    );
  }

  Widget _buildItemEditor(int index, _ItemDraft item) {
    final itemMembers = _membersForItem(item);
    final totalPercent = _itemTotalPercent(item);
    final percentDelta = 100 - totalPercent;
    final formattedDelta = percentDelta.abs().toStringAsFixed(
      percentDelta.abs().truncateToDouble() == percentDelta.abs() ? 0 : 2,
    );
    final percentStatus = percentDelta.abs() <= 0.01
        ? '100% handled'
        : percentDelta > 0
        ? '$formattedDelta% remaining'
        : '$formattedDelta% over';
    final statusColor = percentDelta.abs() <= 0.01
        ? Colors.green.shade700
        : percentDelta > 0
        ? Colors.orange.shade800
        : Colors.red.shade700;

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
                  decoration: InputDecoration(labelText: 'Item ${index + 1}'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberInput(
                  controller: item.costController,
                  labelText: 'Unit cost',
                  step: 1,
                  min: 0,
                  allowDecimal: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberInput(
                  controller: item.quantityController,
                  labelText: 'Qty',
                  step: 1,
                  min: 1,
                  allowDecimal: false,
                  onChanged: (_) => setState(() {}),
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Members handling this item',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: itemMembers.map((member) {
                final isDeletedMember = !widget.project.members.any(
                  (m) => m.id == member.id,
                );
                final isInvolved = item.isMemberInvolved(member.id);
                final colorScheme = Theme.of(context).colorScheme;
                final memberChipColor = isDeletedMember
                    ? _unknownMemberColor(context)
                    : null;
                return FilterChip(
                  selected: isInvolved,
                  showCheckmark: true,
                  checkmarkColor: colorScheme.onSecondaryContainer,
                  selectedColor: colorScheme.secondaryContainer,
                  backgroundColor: memberChipColor,
                  side: isInvolved
                      ? BorderSide.none
                      : BorderSide(color: colorScheme.outlineVariant),
                  label: Text(member.name),
                  onSelected: (selected) => setState(() {
                    item.setMemberInvolved(member.id, selected);
                    item.applyAutoSplit(_involvedMembersForItem(item));
                  }),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: itemMembers.map((member) {
              final isDeletedMember = !widget.project.members.any(
                (m) => m.id == member.id,
              );
              final isInvolved = item.isMemberInvolved(member.id);
              final memberInputFillColor = isDeletedMember
                  ? isInvolved
                        ? _unknownMemberColor(context)
                        : _inactiveMemberColor(context)
                  : isInvolved
                  ? Colors.white
                  : _inactiveMemberColor(context);
              return SizedBox(
                width: 150,
                child: _NumberInput(
                  controller: item.splitControllers[member.id]!,
                  labelText: '${member.name} %',
                  step: 1,
                  min: 0,
                  max: 100,
                  allowDecimal: true,
                  decimalPlaces: 2,
                  onChanged: (value) =>
                      _handleSplitChanged(item, member.id, value),
                  isGrey: true,
                  enabled: true,
                  fillColor: memberInputFillColor,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  percentStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _applyAutoSplit(item),
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('Auto split'),
              ),
            ],
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
      _showOverlaySnack(context, 'Enter a store name.');
      return;
    }

    final items = <ReceiptItem>[];
    for (final draft in _items) {
      final name = draft.nameController.text.trim();
      final cost = double.tryParse(draft.costController.text.trim());
      final quantity = int.tryParse(draft.quantityController.text.trim());
      final splits = <SplitAllocation>[];

      for (final memberId in draft.splitControllers.keys) {
        if (!draft.isMemberInvolved(memberId)) continue;
        final percent =
            double.tryParse(
              draft.splitControllers[memberId]?.text.trim() ?? '',
            ) ??
            0;
        if (percent > 0) {
          splits.add(SplitAllocation(memberId: memberId, percent: percent));
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
        _showOverlaySnack(
          context,
          'Each item needs a name, positive unit cost, and positive quantity.',
        );
        return;
      }
      if (draft.involvedMemberIds.isEmpty) {
        _showOverlaySnack(
          context,
          'Select at least one member to handle each item.',
        );
        return;
      }
      if ((totalPercent - 100).abs() > .01) {
        _showOverlaySnack(context, 'Each item split must add up to 100%.');
        return;
      }

      items.add(
        ReceiptItem(
          id: draft.itemId ?? createId(),
          name: name,
          unitCost: cost,
          quantity: quantity,
          splits: splits,
        ),
      );
    }

    Navigator.pop(
      context,
      CostReceipt(
        id: widget.receipt?.id ?? createId(),
        date: _date,
        storeName: store,
        items: items,
        isDone: widget.receipt?.isDone ?? false,
      ),
    );
  }
}

Color _unknownMemberColor(BuildContext context) {
  return Color.alphaBlend(
    Theme.of(context).colorScheme.tertiary.withValues(alpha: .22),
    Colors.white,
  );
}

Color _inactiveMemberColor(BuildContext context) {
  return Theme.of(context).disabledColor.withValues(alpha: .12);
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({
    required this.controller,
    required this.labelText,
    required this.step,
    required this.allowDecimal,
    this.min,
    this.max,
    this.decimalPlaces,
    this.onChanged,
    this.isGrey = false,
    this.enabled = true,
    this.fillColor,
  });

  final TextEditingController controller;
  final String labelText;
  final double step;
  final bool allowDecimal;
  final double? min;
  final double? max;
  final int? decimalPlaces;
  final ValueChanged<String>? onChanged;
  final bool isGrey;
  final bool enabled;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final decimals = decimalPlaces ?? (allowDecimal ? 2 : 0);
    final effectiveFillColor = fillColor ?? _inactiveMemberColor(context);
    return Container(
      decoration: BoxDecoration(
        color: isGrey ? effectiveFillColor : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            allowDecimal
                ? RegExp('^\\d*\\.?\\d{0,$decimals}')
                : RegExp(r'^\d*'),
          ),
        ],
        decoration: InputDecoration(
          labelText: labelText,
          filled: isGrey,
          fillColor: isGrey ? effectiveFillColor : null,
          suffixIcon: SizedBox(
            width: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NumberInputButton(
                  icon: Icons.keyboard_arrow_up,
                  onPressed: enabled ? () => _changeValue(step) : null,
                ),
                _NumberInputButton(
                  icon: Icons.keyboard_arrow_down,
                  onPressed: enabled ? () => _changeValue(-step) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _changeValue(double delta) {
    final current = double.tryParse(controller.text.trim()) ?? 0;
    var next = current + delta;
    if (min != null && next < min!) next = min!;
    if (max != null && next > max!) next = max!;
    controller.text = allowDecimal
        ? _formatDecimal(next)
        : next.round().toString();
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    onChanged?.call(controller.text);
  }

  String _formatDecimal(double value) {
    final decimals = decimalPlaces ?? 2;
    final rounded =
        (value * _pow10(decimals)).roundToDouble() / _pow10(decimals);
    return rounded.truncateToDouble() == rounded
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(decimals);
  }

  double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}

class _ReceiptSplitPreview extends StatelessWidget {
  const _ReceiptSplitPreview({
    required this.project,
    required this.memberTotals,
  });

  final CostProject project;
  final Map<String, double> memberTotals;

  @override
  Widget build(BuildContext context) {
    final previewMembers = [
      ...project.members,
      ...project.deletedMembers.values.where(
        (member) => memberTotals.containsKey(member.id),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current member totals',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: previewMembers.map((member) {
              final isDeletedMember = !project.members.any(
                (activeMember) => activeMember.id == member.id,
              );
              return Chip(
                backgroundColor: isDeletedMember
                    ? _unknownMemberColor(context)
                    : null,
                label: Text(
                  '${member.name}: ${money(memberTotals[member.id] ?? 0)}',
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NumberInputButton extends StatelessWidget {
  const _NumberInputButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ItemDraft {
  _ItemDraft(List<ProjectMember> members, [ReceiptItem? item])
    : itemId = item?.id {
    if (item != null) {
      nameController.text = item.name;
      costController.text = item.unitCost.toString();
      quantityController.text = item.quantity.toString();
    }

    final memberMap = {for (final member in members) member.id: member};
    if (item != null) {
      for (final split in item.splits) {
        memberMap.putIfAbsent(
          split.memberId,
          () => ProjectMember(
            id: split.memberId,
            name: 'Unknown',
            colorValue: 0xffbdbdbd,
          ),
        );
      }
    }

    if (memberMap.isNotEmpty) {
      for (final member in memberMap.values) {
        final percent = item?.splits
            .where((split) => split.memberId == member.id)
            .fold<double>(0, (sum, split) => sum + split.percent);
        splitControllers[member.id] = TextEditingController(
          text: _formatPercent(percent),
        );
        if (item == null || (percent ?? 0) > 0) {
          involvedMemberIds.add(member.id);
        }
      }
      if (item == null) {
        applyAutoSplit(members);
      }
    }
  }

  final String? itemId;
  final nameController = TextEditingController();
  final costController = TextEditingController(text: '10');
  final quantityController = TextEditingController(text: '1');
  final Map<String, TextEditingController> splitControllers = {};
  final Set<String> involvedMemberIds = {};

  bool isMemberInvolved(String memberId) =>
      involvedMemberIds.contains(memberId);

  void setMemberInvolved(
    String memberId,
    bool isInvolved, {
    bool clearPercent = true,
  }) {
    if (isInvolved) {
      involvedMemberIds.add(memberId);
    } else {
      involvedMemberIds.remove(memberId);
      if (clearPercent) {
        splitControllers[memberId]?.text = _formatPercent(0);
      }
    }
  }

  void applyAutoSplit(List<ProjectMember> members) {
    if (members.isEmpty) return;
    final totalCents = 10000;
    final basePercentCents = totalCents ~/ members.length;
    final remainderCents = totalCents % members.length;
    for (var i = 0; i < members.length; i++) {
      final member = members[i];
      final percent = (basePercentCents + (i == 0 ? remainderCents : 0)) / 100;
      splitControllers[member.id]?.text = _formatPercent(percent);
    }
  }

  String _formatPercent(double? value) {
    final percent = value ?? 0;
    return percent.toStringAsFixed(
      percent.truncateToDouble() == percent ? 0 : 2,
    );
  }

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

  void updateProject(String projectId, String name) {
    final project = _project(projectId);
    final index = projects.indexOf(project);
    projects[index] = CostProject(
      id: project.id,
      name: name,
      createdAt: project.createdAt,
      ownerEmail: project.ownerEmail,
      isCloudBacked: project.isCloudBacked,
      members: project.members,
      receipts: project.receipts,
    );
    _save();
  }

  void deleteProject(String projectId) {
    projects.removeWhere((project) => project.id == projectId);
    if (selectedProjectId == projectId) {
      selectedProjectId = projects.isEmpty ? null : projects.first.id;
    }
    _save();
  }

  void reorderProject(int oldIndex, int newIndex) {
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= projects.length) {
      return;
    }
    final project = projects.removeAt(oldIndex);
    projects.insert(newIndex.clamp(0, projects.length), project);
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

  void updateMemberName(String projectId, String memberId, String name) {
    final members = _project(projectId).members;
    final index = members.indexWhere((member) => member.id == memberId);
    if (index == -1) return;
    final member = members[index];
    members[index] = ProjectMember(
      id: member.id,
      name: name,
      colorValue: member.colorValue,
    );
    _save();
  }

  void deleteMember(String projectId, String memberId) {
    final project = _project(projectId);
    final memberIndex = project.members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) {
      return;
    }

    final member = project.members[memberIndex];
    final isUsedInReceipt = project.receipts.any(
      (receipt) => receipt.items.any(
        (item) => item.splits.any((split) => split.memberId == memberId),
      ),
    );
    if (isUsedInReceipt) {
      project.deletedMembers[member.id] = ProjectMember(
        id: member.id,
        name: 'Unknown',
        colorValue: member.colorValue,
      );
    }

    project.members.removeAt(memberIndex);
    _save();
  }

  void reorderMember(String projectId, int oldIndex, int newIndex) {
    final members = _project(projectId).members;
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= members.length) {
      return;
    }
    final member = members.removeAt(oldIndex);
    members.insert(newIndex.clamp(0, members.length), member);
    _save();
  }

  void addReceipt(String projectId, CostReceipt receipt) {
    _project(projectId).receipts.add(receipt);
    _save();
  }

  void updateReceipt(String projectId, CostReceipt updatedReceipt) {
    final receipts = _project(projectId).receipts;
    final index = receipts.indexWhere(
      (receipt) => receipt.id == updatedReceipt.id,
    );
    if (index != -1) receipts[index] = updatedReceipt;
    _save();
  }

  void deleteReceipt(String projectId, String receiptId) {
    _project(
      projectId,
    ).receipts.removeWhere((receipt) => receipt.id == receiptId);
    _save();
  }

  void checkout(String projectId, Set<String> receiptIds) {
    for (final receipt in _project(projectId).receipts) {
      if (receiptIds.contains(receipt.id)) receipt.isDone = true;
    }
    _save();
  }

  void undoCheckout(String projectId, String receiptId) {
    for (final receipt in _project(projectId).receipts) {
      if (receipt.id == receiptId) {
        receipt.isDone = false;
        break;
      }
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
    Map<String, ProjectMember>? deletedMembers,
    List<CostReceipt>? receipts,
  }) : members = members ?? [],
       deletedMembers = deletedMembers ?? {},
       receipts = receipts ?? [];

  final String id;
  final String name;
  final DateTime createdAt;
  String? ownerEmail;
  bool isCloudBacked;
  final List<ProjectMember> members;
  final Map<String, ProjectMember> deletedMembers;
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
    return deletedMembers[id];
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
    deletedMembers: (json['deletedMembers'] as Map<String, dynamic>? ?? {}).map(
      (key, value) =>
          MapEntry(key, ProjectMember.fromJson(value as Map<String, dynamic>)),
    ),
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
    'deletedMembers': deletedMembers.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
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
