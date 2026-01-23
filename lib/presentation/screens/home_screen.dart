import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'round_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _createRound(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(roundsControllerProvider.notifier);

    final titleController = TextEditingController(text: 'Today\'s Round');

    final title = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New round'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Round name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, titleController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty) return;

    final round = await controller.createRound(title: title);

    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoundScreen(roundId: round.id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundsAsync = ref.watch(roundsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoRoute Driver'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(roundsControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createRound(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Round'),
      ),
      body: roundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: $e'),
          ),
        ),
        data: (rounds) {
          if (rounds.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No rounds yet. Tap “New Round” to create one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: rounds.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rounds[i];
              return ListTile(
                title: Text(r.title),
                subtitle: Text('${r.stops.length} stops'),
                trailing: IconButton(
                  tooltip: 'Delete round',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete round?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(roundsControllerProvider.notifier)
                          .deleteRound(r.id);
                    }
                  },
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => RoundScreen(roundId: r.id)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
