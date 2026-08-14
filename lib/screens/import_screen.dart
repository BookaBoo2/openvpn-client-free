import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../providers.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _nameCtrl = TextEditingController();
  final _configCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _saving = false;
  String? _pickedFileName;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _configCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      return;
    }
    setState(() {
      _configCtrl.text = content;
      _pickedFileName = file.name;
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = p.basenameWithoutExtension(file.name);
      }
    });
  }

  Future<void> _import() async {
    final config = _configCtrl.text.trim();
    if (config.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tabs.index == 0
                ? 'Выберите .ovpn файл'
                : 'Вставьте конфиг вручную',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim().isEmpty
          ? 'Импортированный профиль'
          : _nameCtrl.text.trim();
      final profile = await ref.read(profilesProvider.notifier).importProfile(
            name: name,
            ovpnConfig: config,
            username:
                _userCtrl.text.trim().isEmpty ? null : _userCtrl.text.trim(),
            password: _passCtrl.text.isEmpty ? null : _passCtrl.text,
          );
      await ref.read(selectedProfileIdProvider.notifier).select(profile.id);
      if (mounted) {
        Navigator.of(context).pop(profile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт профиля'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'По файлу'),
            Tab(text: 'Вручную'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _FileTab(
                  pickedFileName: _pickedFileName,
                  onPick: _pickFile,
                ),
                _ManualTab(controller: _configCtrl),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Имя профиля',
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
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _import,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_done),
                  label: const Text('Импортировать'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTab extends StatelessWidget {
  const _FileTab({
    required this.pickedFileName,
    required this.onPick,
  });

  final String? pickedFileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.folder_open),
          label: const Text('Выбрать .ovpn файл'),
        ),
        const SizedBox(height: 16),
        if (pickedFileName != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(pickedFileName!),
              subtitle: const Text('Файл выбран'),
            ),
          )
        else
          Text(
            'Выберите файл конфигурации OpenVPN (.ovpn)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _ManualTab extends StatelessWidget {
  const _ManualTab({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: controller,
          maxLines: 16,
          decoration: const InputDecoration(
            labelText: 'Конфиг OVPN',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
            hintText: 'Вставьте содержимое .ovpn сюда…',
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    );
  }
}
