import 'package:flutter/material.dart';
import '../main.dart'
    show macroRepository, programRepository, signRepository, prefsService;
import '../services/action_executor.dart';
import '../services/bluetooth_service.dart';
import 'tabs/algorithms_tab.dart';
import 'tabs/macros_tab.dart';
import 'tabs/programs_tab.dart';
import 'tabs/signs_tab.dart';

class LibraryScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final ActionExecutor executor;
  final int initialTab;

  const LibraryScreen({
    super.key,
    required this.bluetoothService,
    required this.executor,
    this.initialTab = 0,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca', style: TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.image_outlined, size: 18), text: 'Senales'),
            Tab(icon: Icon(Icons.code, size: 18), text: 'Programas'),
            Tab(icon: Icon(Icons.fiber_manual_record, size: 18), text: 'Macros'),
            Tab(icon: Icon(Icons.tune, size: 18), text: 'Algoritmos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          SignsTab(
            bluetoothService: widget.bluetoothService,
            repository: signRepository,
            executor: widget.executor,
          ),
          ProgramsTab(
            repository: programRepository,
            executor: widget.executor,
          ),
          MacrosTab(
            bluetoothService: widget.bluetoothService,
            repository: macroRepository,
            executor: widget.executor,
          ),
          AlgorithmsTab(
            bluetoothService: widget.bluetoothService,
            prefsService: prefsService,
          ),
        ],
      ),
    );
  }
}
