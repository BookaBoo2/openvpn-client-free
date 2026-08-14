import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpn_android/vpn_android.dart';

import '../providers.dart';
import 'app_picker_screen.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  AppFilterMode _mode = AppFilterMode.all;
  List<String> _packages = [];
  VpnProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await VpnAndroid.instance.getProfile(widget.profileId);
    if (!mounted) return;
    setState(() {
      _profile = p;
      if (p != null) {
        _nameCtrl.text = p.name;
        _userCtrl.text = p.username ?? '';
        _passCtrl.text = p.password ?? '';
        _mode = p.appFilterMode;
        _packages = List.of(p.packageNames);
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final base = _profile;
    if (base == null) return;
    setState(() => _saving = true);
    final updated = base.copyWith(
      name: _nameCtrl.text.trim().isEmpty ? base.name : _nameCtrl.text.trim(),
      username: _userCtrl.text.trim().isEmpty ? null : _userCtrl.text.trim(),
      password: _passCtrl.text.isEmpty ? null : _passCtrl.text,
      appFilterMode: _mode,
      packageNames: _packages,
    );
    await ref.read(profilesProvider.notifier).updateProfile(updated);
    final connection = ref.read(connectionProvider);
    if (mounted) {
      setState(() {
        _profile = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connection.isConnected
                ? 'Сохранено. Переподключите VPN, чтобы применить фильтр приложений.'
                : 'Профиль сохранён',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Профиль не найден')),
      );
    }

    final appsAsync = ref.watch(installedAppsProvider(true));
    final appsByPackage = appsAsync.valueOrNull == null
        ? <String, InstalledApp>{}
        : {for (final a in appsAsync.valueOrNull!) a.packageName: a};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактирование профиля'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Имя',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            decoration: const InputDecoration(
              labelText: 'Логин (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Пароль (необязательно)',
              border: OutlineInputBorder(),
              helperText: 'Хранится в защищённом хранилище на устройстве',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Фильтр приложений',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<AppFilterMode>(
            segments: const [
              ButtonSegment(value: AppFilterMode.all, label: Text('Все')),
              ButtonSegment(
                value: AppFilterMode.whitelist,
                label: Text('Белый'),
              ),
              ButtonSegment(
                value: AppFilterMode.blacklist,
                label: Text('Чёрный'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            _mode == AppFilterMode.all
                ? 'Все приложения идут через VPN.'
                : _mode == AppFilterMode.whitelist
                    ? 'Через VPN только выбранные приложения, остальные — напрямую.'
                    : 'Выбранные приложения обходят VPN, остальные идут через него.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_mode != AppFilterMode.all) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Выбранные приложения (${_packages.length})'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.of(context).push<List<String>>(
                  MaterialPageRoute(
                    builder: (_) => AppPickerScreen(
                      initiallySelected: _packages,
                      mode: _mode,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() => _packages = result);
                }
              },
            ),
            if (_packages.isNotEmpty) ...[
              const SizedBox(height: 4),
              ..._packages.map(
                (pkg) => _SelectedAppTile(
                  packageName: pkg,
                  app: appsByPackage[pkg],
                  onRemove: () => setState(() => _packages.remove(pkg)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SelectedAppTile extends StatelessWidget {
  const _SelectedAppTile({
    required this.packageName,
    required this.app,
    required this.onRemove,
  });

  final String packageName;
  final InstalledApp? app;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = app?.label ?? 'Неизвестное приложение';
    Widget leading;
    if (app?.iconBase64 != null) {
      try {
        leading = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(app!.iconBase64!),
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.android, size: 36),
          ),
        );
      } catch (_) {
        leading = const Icon(Icons.android, size: 36);
      }
    } else {
      leading = const Icon(Icons.android, size: 36);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: leading,
        title: Text(label),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Убрать',
          onPressed: onRemove,
        ),
      ),
    );
  }
}
