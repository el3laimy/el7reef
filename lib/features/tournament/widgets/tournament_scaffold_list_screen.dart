import 'package:flutter/material.dart';

class TournamentScaffoldListScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? floatingActionButton;

  const TournamentScaffoldListScreen({
    super.key,
    required this.title,
    required this.child,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
