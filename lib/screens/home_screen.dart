import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpn_android/vpn_android.dart';

import '../constants/app_info.dart';
import '../l10n.dart';
import '../providers.dart';
import 'about_screen.dart';
import 'import_screen.dart';
import 'logs_screen.dart';
import 'profile_edit_screen.dart';
import 'profiles_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    final selectedIdAsync = ref.watch(selectedProfileIdProvider);
    final connection = ref.watch(connectionProvider);

    final profiles = profilesAsync.valueOrNull ?? const <VpnProfile>[];
    final selectedId = selectedIdAsync.valueOrNull;
    final selected = profiles.cast<VpnProfile?>().firstWhere(
          (p) => p?.id == selectedId,
          orElse: () => profiles.isEmpty ? null : profiles.first,
        );

    final connected = connection.isConnected;
    final busy = connection.isBusy;
    final color = connected
        ? Colors.green
        : (connection.stage == 'error'
            ? Colors.red
            : Theme.of(context).colorScheme.primary);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppInfo.appName),
        actions: [
          IconButton(
            tooltip: 'О программе',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: 'Импорт',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              );
              ref.invalidate(profilesProvider);
            },
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Логи',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogsScreen()),
              );
            },
            icon: const Icon(Icons.terminal),
          ),
          IconButton(
            tooltip: 'Профили',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilesScreen()),
              );
            },
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      connected ? Icons.shield : Icons.shield_outlined,
                      size: 72,
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      stageLabelRu(connection.stage),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (connection.duration != null) ...[
                      const SizedBox(height: 8),
                      Text('Время: ${connection.duration}'),
                      Text(
                        '↓ ${connection.byteIn ?? '-'}   ↑ ${connection.byteOut ?? '-'}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Профиль', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (profiles.isEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImportScreen()),
                  );
                  ref.invalidate(profilesProvider);
                },
                icon: const Icon(Icons.file_upload),
                label: const Text('Импортировать .ovpn'),
              )
            else
              DropdownMenu<String>(
                key: ValueKey(selected?.id),
                initialSelection: selected?.id,
                enabled: !busy,
                label: const Text('Активный профиль'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: profiles
                    .map(
                      (p) => DropdownMenuEntry(
                        value: p.id,
                        label: '${p.name}${p.isDefault ? ' ★' : ''}',
                      ),
                    )
                    .toList(),
                onSelected: busy
                    ? null
                    : (id) async {
                        await ref
                            .read(selectedProfileIdProvider.notifier)
                            .select(id);
                      },
              ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Фильтр приложений: ${selected.appFilterMode.label}'),
                subtitle: Text(
                  selected.appFilterMode == AppFilterMode.all
                      ? 'Весь трафик через VPN'
                      : 'Выбрано приложений: ${selected.packageNames.length}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileEditScreen(profileId: selected.id),
                      ),
                    );
                    ref.invalidate(profilesProvider);
                  },
                ),
              ),
            ],
            const Spacer(),
            if (connection.stage == 'error')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Ошибка подключения — подробности в Логах.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: connected ? Colors.red.shade700 : null,
              ),
              onPressed: selected == null || busy
                  ? null
                  : () async {
                      try {
                        if (connected) {
                          await ref
                              .read(connectionProvider.notifier)
                              .disconnect();
                        } else {
                          final ok =
                              await VpnAndroid.instance.requestVpnPermission();
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Нужно разрешение VPN',
                                ),
                              ),
                            );
                            return;
                          }
                          await ref
                              .read(connectionProvider.notifier)
                              .connect(selected.id);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
              icon: Icon(connected ? Icons.stop : Icons.power_settings_new),
              label: Text(
                connected
                    ? 'Отключить'
                    : busy
                        ? 'Подождите…'
                        : 'Подключить',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Always-on / kill switch: Настройки Android → Сеть → VPN.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
