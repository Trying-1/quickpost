import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/home_shell_screen.dart';
import 'screens/onboarding/onboarding_flow_screen.dart';
import 'services/subscription_service.dart';
import 'services/audio_library_service.dart';
import 'services/watermark_preset_service.dart';
import 'services/image_post_preset_service.dart';
import 'services/anime_post_preset_service.dart';
import 'services/carousel_post_preset_service.dart';
import 'services/app_update_service.dart';
import 'services/app_review_service.dart';
import 'services/onboarding_service.dart';
import 'services/video_perf_service.dart';
import 'widgets/share_intent_handler.dart';
import 'utils/custom_font_manager.dart';
import 'services/google_font_service.dart';
import 'services/favorite_fonts_manager.dart';
import 'utils/watermark_settings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/analytics_service.dart';
import 'services/ad_service.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Small delay to ensure logs are captured by the logger
  await Future.delayed(const Duration(milliseconds: 500));
  
  print('====================================================');
  print('APP STARTING: main()');
  print('PLATFORM: $defaultTargetPlatform');
  print('APPS BEFORE: ${Firebase.apps.length}');
  
  // Initialize Firebase
  try {
    print('FIREBASE: Initializing...');
    if (defaultTargetPlatform == TargetPlatform.android) {
      // On Android, Firebase.initializeApp() without options reads from google-services.json automatically
      // which is often more robust when dealing with channel-errors.
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    print('FIREBASE: Success! Apps: ${Firebase.apps.length}');
    await AnalyticsService().logAppOpen();
  } catch (e) {
    print('FIREBASE: FAILED');
    print('ERROR: $e');
  }
  print('====================================================');
  
  // Initialize Audio Library Service
  await AudioLibraryService.init();
 
  // Initialize Watermark Preset
  await WatermarkPresetService.init();

  // Initialize Watermark Settings
  await WatermarkSettings.init();
 
  // Initialize Image Post Preset
  await ImagePostPresetService.init();

  // Initialize Anime Post Preset
  await AnimePostPresetService.init();

  // Initialize Carousel Post Preset
  await CarouselPostPresetService.init();
 
  // Initialize Video Perf Service
  await VideoPerfService.init();
 
  // Initialize Subscription Service
  await SubscriptionService.init();
 
  // Initialize Custom Font Manager (register user-uploaded fonts)
  try {
    await CustomFontManager().init();
  } catch (e) {
    print('CustomFontManager init error: $e');
  }
 
  // Initialize Google Font Service (register downloaded Google fonts)
  try {
    await GoogleFontService().init();
  } catch (e) {
    print('GoogleFontService init error: $e');
  }

  // Initialize Favorite Fonts Manager
  try {
    await FavoriteFontsManager().init();
  } catch (e) {
    print('FavoriteFontsManager init error: $e');
  }
 
  
  // Initialize App Review Service
  await AppReviewService().initialize();
  
  // Initialize AdService
  await AdService().initialize();
  
  // App update checks disabled in this build to reduce noisy logs and PlayCore errors.
  // If you want to re-enable, call AppUpdateService().checkForUpdate() here.
  
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                'Render error:\n\n${details.exceptionAsString()}\n\n${details.stack}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  };
  runApp(const MyApp());
}
 
class MyApp extends StatefulWidget {
  const MyApp({super.key});
 
  @override
  State<MyApp> createState() => _MyAppState();
}
 
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  String? _sharedPurpose;
  List<String>? _sharedImagePaths;
  bool _forceSkipOnboarding = false;
  Future<bool>? _onboardingCompletedFuture;
 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onboardingCompletedFuture = OnboardingService.isCompleted();
    
    // Show App Open Ad on first launch (cold start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().showAppOpenAdOnColdStart();
    });
  }
 
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
 
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AdService().setLastPausedTime(DateTime.now());
    } else if (state == AppLifecycleState.resumed) {
      AdService().showAppOpenAdOnResume();
    }
  }
 
  void _markOnboardingDoneAndShowHome() {
    setState(() {
      _onboardingCompletedFuture = Future.value(true);
    });
  }
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Post',
      theme: AppTheme.lightTheme,
      home: ShareIntentHandler(
        onImagesSelected: (imagePaths, purpose) {
          setState(() {
            _sharedImagePaths = imagePaths;
            _sharedPurpose = purpose;
            _forceSkipOnboarding = true;
          });
          OnboardingService.setCompleted(true);
          // Navigate to appropriate screen based on purpose
          _handleSharedImages(imagePaths, purpose);
        },
        child: FutureBuilder<bool>(
          future: _onboardingCompletedFuture,
          builder: (context, snapshot) {
            final completed = snapshot.data ?? false;
            final showOnboarding = !completed && !_forceSkipOnboarding;
 
            if (showOnboarding) {
              return OnboardingFlowScreen(
                onFinished: () {
                  _markOnboardingDoneAndShowHome();
                },
              );
            }
 
            if (_sharedImagePaths != null && _sharedImagePaths!.isNotEmpty) {
              return HomeShellScreen(
                sharedImagePaths: _sharedImagePaths,
                sharedPurpose: _sharedPurpose,
              );
            }
 
            return HomeShellScreen(initialIndex: 0);
          },
        ),
      ),
    );
  }

  void _handleSharedImages(List<String> imagePaths, String purpose) {
    // This will be handled by HomeShellScreen
    // The shared images and purpose are passed as parameters
  }
}
