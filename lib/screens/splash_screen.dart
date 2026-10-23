import 'dart:async';
import 'package:flutter/material.dart';
import 'package:passbook/firebase_options.dart';
import 'package:passbook/service/firebaseApi.dart';
import 'package:passbook/utils/error_mappers.dart';
import 'package:passbook/utils/user_facing_error.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import '../model/mem_info_model.dart';
import '../service/api_service.dart';
import '../service/language_services.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  UserFacingError? _initError;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeAppAndNavigate();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  Future<void> _initializeAppAndNavigate() async {
    try {
      // Ensure Flutter is ready
      WidgetsFlutterBinding.ensureInitialized();

      _updateStatus('Connecting to services...');

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (!mounted) return;

      final apiService = ApiService();
      final languageService = Provider.of<LanguageService>(
        context,
        listen: false,
      );

      _updateStatus('Loading user data...');
      await apiService.init();
      final MemInfoModel? savedUser = apiService.currentUser;

      if (savedUser != null && savedUser.mobNo != null) {
        languageService.changeLocaleFromLangCode(savedUser.langCode);

        // Immediate offline-first navigation using cached session (<800ms)
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MainScreen(
              userInfo: savedUser,
              registerNotifications: () => CustomFirebaseApi().initNotifications(
                savedUser.authtoken ?? '',
                savedUser.socCode,
                savedUser.membCode,
              ),
            ),
          ),
        );

        // Background session verification and delta sync (Stale-While-Revalidate pattern)
        unawaited(() async {
          try {
            debugPrint("Splash: Background session refresh and delta sync started.");
            final LoginResponse result = await ApiService.login(
              savedUser.socCode.toString(),
              savedUser.mobNo!,
              selectedMembCode: savedUser.membCode,
            );
            final freshUserInfo = result.data;
            if (freshUserInfo != null) {
              await apiService.syncMemberData(
                socCode: freshUserInfo.socCode,
                memCode: freshUserInfo.membCode,
                accNo: freshUserInfo.accno,
                appString: freshUserInfo.appString,
              );
              debugPrint("Splash: Background sync complete.");
            }
          } catch (e) {
            debugPrint("Splash: Background sync non-critical failure ($e) — continuing with cache.");
          }
        }());
        return;
      }

      // No saved user — navigate to LoginScreen
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    } catch (e) {
      debugPrint("Splash: Error during initialization: $e");
      _initError = mapUnexpectedError(e);
      setState(() {
        _hasError = true;
        _statusMessage = _initError!.title;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _showErrorDialog(_initError!);
      }
    }
  }

  void _showErrorDialog(UserFacingError error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          severityIcon(error.severity),
          color: severityColor(error.severity, Theme.of(context)),
          size: 32,
        ),
        title: Text(error.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error.message),
              if (error.guidance != null) ...[
                const SizedBox(height: 16),
                Text(
                  'What you can do',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(error.guidance!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _hasError = false;
                _initError = null;
                _statusMessage = 'Retrying...';
              });
              _initializeAppAndNavigate();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo/Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Image.asset(
                            'assets/images/logo_big.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // App Name
                    const Text(
                      'Milk Passbook',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Milk Management System',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Loading Indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        strokeWidth: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status Message
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _statusMessage,
                        key: ValueKey<String>(_statusMessage),
                        style: TextStyle(
                          fontSize: 16,
                          color: _hasError
                              ? Colors.red.shade100
                              : Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 100),

                    // Version Info
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


