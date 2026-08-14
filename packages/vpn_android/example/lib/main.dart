import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: ExampleHome()));
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('vpn_android example')),
      body: const Center(
        child: Text('Use the host ovpn_client app for full UI.'),
      ),
    );
  }
}
