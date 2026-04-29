import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/preference_controller.dart';
import 'screens/auth_gate.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/event_service.dart';
import 'services/note_service.dart';
import 'services/preference_service.dart';
import 'services/todo_service.dart';
import 'services/token_storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final apiClient = ApiClient(
    baseUrl: baseUrl,
  );

  final tokenStorageService = TokenStorageService();
  final authService = AuthService(apiClient: apiClient);
  final eventService = EventService(apiClient: apiClient);
  final preferenceService = PreferenceService(apiClient: apiClient);
  final todoService = TodoService(apiClient: apiClient);
  final noteService = NoteService(apiClient: apiClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<EventService>.value(value: eventService),
        Provider<PreferenceService>.value(value: preferenceService),
        Provider<TodoService>.value(value: todoService),
        Provider<NoteService>.value(value: noteService),
        ChangeNotifierProvider(
          create: (_) => AuthController(
            authService: authService,
            tokenStorageService: tokenStorageService,
            apiClient: apiClient,
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => PreferenceController(
            preferenceService: preferenceService,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(ColorScheme colorScheme) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamilyFallback: const [
        'Noto Sans JP',
        'Hiragino Sans',
        'Yu Gothic',
        'Meiryo',
        'sans-serif',
      ],
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.35),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.6,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedIconTheme: IconThemeData(
          color: colorScheme.primary,
        ),
        unselectedIconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
        ),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferenceController = context.watch<PreferenceController>();

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Custom Life App',
      debugShowCheckedModeBanner: false,
      themeMode: preferenceController.themeMode,
      theme: _buildTheme(lightColorScheme),
      darkTheme: _buildTheme(darkColorScheme),
      home: const AuthGate(),
    );
  }
}