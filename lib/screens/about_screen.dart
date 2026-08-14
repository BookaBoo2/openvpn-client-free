import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_info.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('О программе')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  AppInfo.appName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('Версия ${AppInfo.version}'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Лицензия',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Это свободное программное обеспечение, распространяемое на '
            'условиях GNU General Public License v2 (или более поздней версии). '
            'Вы можете копировать, изменять и распространять программу '
            'в соответствии с текстом лицензии.',
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Исходный код (GPL)'),
              subtitle: SelectableText(AppInfo.sourceRepositoryUrl),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Открыть',
                onPressed: () => _openUrl(AppInfo.sourceRepositoryUrl),
              ),
              onTap: () => _openUrl(AppInfo.sourceRepositoryUrl),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: AppInfo.sourceRepositoryUrl),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ссылка скопирована')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Скопировать ссылку на исходники'),
          ),
          const SizedBox(height: 24),
          Text(
            'Сторонние компоненты',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Приложение использует движок OpenVPN (GPLv2), основанный на '
            'проектах ics-openvpn и openvpn_library. '
            'Полный список — в файле docs/THIRD_PARTY_NOTICES.md в репозитории.',
          ),
          const SizedBox(height: 24),
          Text(
            'Товарный знак',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'OpenVPN® — зарегистрированный товарный знак OpenVPN Inc. '
            'Данное приложение не аффилировано с OpenVPN Inc. и не является '
            'официальным клиентом. Поддерживается протокол OpenVPN (.ovpn).',
          ),
          const SizedBox(height: 24),
          Text(
            'Конфиденциальность',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Профили .ovpn, логины и пароли хранятся только на вашем устройстве. '
            'Разработчик не получает ваши VPN-данные. '
            'Подробнее — PRIVACY.md в репозитории.',
          ),
        ],
      ),
    );
  }
}
