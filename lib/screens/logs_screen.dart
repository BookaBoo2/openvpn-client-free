import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(logsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => ref.read(logsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Копировать',
            onPressed: () async {
              final lines = logsAsync.valueOrNull ?? const <String>[];
              await Clipboard.setData(ClipboardData(text: lines.join('\n')));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скопировано в буфер обмена')),
                );
              }
            },
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Очистить',
            onPressed: () => ref.read(logsProvider.notifier).clear(),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (lines) {
          if (lines.isEmpty) {
            return const Center(child: Text('Логов пока нет'));
          }
          return SelectionArea(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
