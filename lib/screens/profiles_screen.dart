import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'import_screen.dart';
import 'profile_edit_screen.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Профили')),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(
              child: Text('Пока нет профилей. Импортируйте .ovpn файл.'),
            );
          }
          return ListView.separated(
            itemCount: profiles.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = profiles[index];
              return ListTile(
                leading: Icon(
                  p.isDefault ? Icons.star : Icons.vpn_key,
                  color: p.isDefault ? Colors.amber : null,
                ),
                title: Text(p.name),
                subtitle: Text(
                  '${p.appFilterMode.label}'
                  '${p.packageNames.isEmpty ? '' : ' · ${p.packageNames.length} прилож.'}',
                ),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileEditScreen(profileId: p.id),
                    ),
                  );
                  ref.invalidate(profilesProvider);
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    final notifier = ref.read(profilesProvider.notifier);
                    switch (value) {
                      case 'default':
                        await notifier.setDefault(p.id);
                        break;
                      case 'select':
                        await ref
                            .read(selectedProfileIdProvider.notifier)
                            .select(p.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Выбран: ${p.name}')),
                          );
                        }
                        break;
                      case 'delete':
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Удалить профиль?'),
                            content: Text(
                              'Удалить «${p.name}» без возможности восстановления?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await notifier.delete(p.id);
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'select',
                      child: Text('Использовать на главной'),
                    ),
                    PopupMenuItem(
                      value: 'default',
                      child: Text('Сделать по умолчанию'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ImportScreen()),
          );
          ref.invalidate(profilesProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
