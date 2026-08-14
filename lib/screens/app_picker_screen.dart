import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpn_android/vpn_android.dart';

import '../providers.dart';

class AppPickerScreen extends ConsumerStatefulWidget {
  const AppPickerScreen({
    super.key,
    required this.initiallySelected,
    required this.mode,
  });

  final List<String> initiallySelected;
  final AppFilterMode mode;

  @override
  ConsumerState<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends ConsumerState<AppPickerScreen> {
  late final Set<String> _selected;
  String _query = '';
  bool _hideSystem = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initiallySelected.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider(true));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == AppFilterMode.whitelist
              ? 'Белый список'
              : 'Чёрный список',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected.toList()..sort()),
            child: const Text('Готово'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск приложений',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          SwitchListTile(
            title: const Text('Скрыть системные'),
            value: _hideSystem,
            onChanged: (v) => setState(() => _hideSystem = v),
          ),
          Expanded(
            child: appsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Не удалось загрузить приложения: $e')),
              data: (apps) {
                final filtered = apps.where((a) {
                  if (_hideSystem && a.systemApp) return false;
                  if (_query.isEmpty) return true;
                  return a.label.toLowerCase().contains(_query) ||
                      a.packageName.toLowerCase().contains(_query);
                }).toList();

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    final checked = _selected.contains(app.packageName);
                    Widget? leading;
                    if (app.iconBase64 != null) {
                      try {
                        leading = Image.memory(
                          base64Decode(app.iconBase64!),
                          width: 40,
                          height: 40,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.android),
                        );
                      } catch (_) {
                        leading = const Icon(Icons.android);
                      }
                    } else {
                      leading = const Icon(Icons.android);
                    }
                    return CheckboxListTile(
                      value: checked,
                      secondary: leading,
                      title: Text(app.label),
                      subtitle: Text(
                        app.packageName,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(app.packageName);
                          } else {
                            _selected.remove(app.packageName);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
