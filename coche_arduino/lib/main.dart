import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/bluetooth_screen.dart';
import 'screens/splash_screen.dart';
import 'services/action_executor.dart';
import 'services/bluetooth_service.dart';
import 'services/macro_repository.dart';
import 'services/preferences_service.dart';
import 'services/program_repository.dart';
import 'services/sign_repository.dart';
import 'services/variable_store.dart';

late PreferencesService prefsService;
late SignRepository signRepository;
late ProgramRepository programRepository;
late MacroRepository macroRepository;
late VariableStore variableStore;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  prefsService = await PreferencesService.init();
  signRepository = SignRepository(prefsService);
  programRepository = ProgramRepository(prefsService);
  macroRepository = MacroRepository(prefsService);
  variableStore = VariableStore(prefsService.raw);
  runApp(const CocheArduinoApp());
}

class CocheArduinoApp extends StatefulWidget {
  const CocheArduinoApp({super.key});

  @override
  State<CocheArduinoApp> createState() => _CocheArduinoAppState();
}

class _CocheArduinoAppState extends State<CocheArduinoApp> {
  final BluetoothService _bluetoothService = BluetoothService();
  late final ActionExecutor _actionExecutor =
      ActionExecutor(_bluetoothService, variableStore)
        ..attachRepositories(
          programs: programRepository,
          macros: macroRepository,
        );

  @override
  void dispose() {
    _actionExecutor.dispose();
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coche Arduino',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF9800),
          secondary: Color(0xFFFF9800),
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
        ),
      ),
      home: SplashScreen(
        nextScreen: BluetoothScreen(
          bluetoothService: _bluetoothService,
          executor: _actionExecutor,
        ),
      ),
    );
  }
}
