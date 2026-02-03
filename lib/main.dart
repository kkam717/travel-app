import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, FlutterAuthClientOptions, AuthFlowType;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme.dart';
import 'core/theme_mode_notifier.dart';
import 'core/locale_notifier.dart';
import 'core/analytics.dart';
import 'l10n/app_strings.dart';
import 'router.dart';

final themeModeNotifier = ThemeModeNotifier.instance;
final localeNotifier = LocaleNotifier.instance;

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await dotenv.load(fileName: '.env').catchError((_) {});
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      if (url.isEmpty || anonKey.isEmpty ||
          url.contains('your-project') || anonKey == 'your-anon-key') {
        runApp(const SetupRequiredApp());
        return;
      }
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          detectSessionInUri: true,
        ),
      );
      Analytics.setUserId(Supabase.instance.client.auth.currentUser?.id);
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        Analytics.setUserId(data.session?.user.id);
      });
      runApp(const TravelApp());
    } catch (e, stack) {
      debugPrint('Init error: $e\n$stack');
      runApp(ErrorApp(error: e.toString()));
    }
  }, (error, stack) {
    debugPrint('Zone error: $error\n$stack');
    runApp(ErrorApp(error: error.toString()));
  });
}

class TravelApp extends StatefulWidget {
  const TravelApp({super.key});

  @override
  State<TravelApp> createState() => _TravelAppState();
}

class _TravelAppState extends State<TravelApp> {
  @override
  void initState() {
    super.initState();
    themeModeNotifier.addListener(_onThemeChanged);
    localeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeModeNotifier.removeListener(_onThemeChanged);
    localeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.s(localeNotifier.locale!.languageCode, 'app_name'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeModeNotifier.themeMode,
      locale: localeNotifier.locale,
      supportedLocales: supportedLocales.keys.map((k) => Locale(k)).toList(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: createRouter(),
    );
  }
}

class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.settings, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                Text(AppStrings.s('en', 'setup_required'), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text(
                  'Add your Supabase credentials to .env:\n\nSUPABASE_URL=https://your-project.supabase.co\nSUPABASE_ANON_KEY=your-anon-key',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text('Copy .env.example to .env and fill in your values.', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                Text(AppStrings.s(localeNotifier.locale?.languageCode ?? 'en', 'something_went_wrong'), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text(error, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
