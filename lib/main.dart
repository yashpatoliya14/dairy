import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:async';
import 'dart:developer' as developer;

import 'controllers/app_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'services/app_language.dart';
import 'services/app_update_service.dart';
import 'services/api_service.dart';
import 'views/app_update_screen.dart';
import 'widgets/dairy_milk_loader.dart';
import 'widgets/dashboard_screen.dart';
import 'widgets/monthly_entries_screen.dart';
import 'widgets/send_whatsapp_bill_sheet.dart';
import 'widgets/support_bottom_sheet.dart';
import 'widgets/whatsapp_messaging_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const DairyApp());
}

bool _isValidEmail(String email) {
  final trimmed = email.trim().toLowerCase();
  final regex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );
  if (!regex.hasMatch(trimmed)) return false;

  final parts = trimmed.split('@');
  if (parts.length != 2) return false;
  final local = parts[0];
  final domain = parts[1];

  if (local.isEmpty || local.length > 64) return false;
  if (domain.isEmpty || domain.length > 255) return false;
  if (local.contains('..') || domain.contains('..')) return false;

  final domainLabels = domain.split('.');
  if (domainLabels.length < 2) return false;
  final tld = domainLabels.last;
  if (tld.length < 2 || !RegExp(r'^[a-zA-Z]+$').hasMatch(tld)) return false;

  // Reject typos where numbers precede domain provider, like "426gmail.com"
  for (final label in domainLabels) {
    if (RegExp(r'^\d+[a-zA-Z]+$').hasMatch(label)) {
      return false;
    }
  }

  return true;
}

TextTheme _buildTextTheme(String language) {
  if (language == 'gu') {
    return GoogleFonts.notoSansGujaratiTextTheme().copyWith(
      displayLarge: GoogleFonts.notoSansGujarati(
        fontSize: 57,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.notoSansGujarati(
        fontSize: 45,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: GoogleFonts.notoSansGujarati(
        fontSize: 36,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.notoSansGujarati(
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: GoogleFonts.notoSansGujarati(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );
  } else if (language == 'hi') {
    return GoogleFonts.notoSansDevanagariTextTheme().copyWith(
      displayLarge: GoogleFonts.notoSansDevanagari(
        fontSize: 57,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.notoSansDevanagari(
        fontSize: 45,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: GoogleFonts.notoSansDevanagari(
        fontSize: 36,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.notoSansDevanagari(
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: GoogleFonts.notoSansDevanagari(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  return GoogleFonts.dmSansTextTheme().copyWith(
    displayLarge: GoogleFonts.manrope(
      fontSize: 57,
      fontWeight: FontWeight.w700,
    ),
    displayMedium: GoogleFonts.manrope(
      fontSize: 45,
      fontWeight: FontWeight.w700,
    ),
    displaySmall: GoogleFonts.manrope(
      fontSize: 36,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: GoogleFonts.manrope(
      fontSize: 28,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: GoogleFonts.manrope(
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
  );
}

class DairyApp extends StatelessWidget {
  const DairyApp({super.key});

  static final api = ApiService();

  @override
  Widget build(BuildContext context) {
    final appController = Get.put(
      AppController(api, authPageBuilder: (api) => AuthPage(api: api)),
      permanent: true,
    );
    final languageController = Get.put(
      AppLanguageController(),
      permanent: true,
    );
    return Obx(() {
      final currentLang = languageController.language.value;
      return GetMaterialApp(
        title: 'Dairy Desk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff2d7a55),
            primary: const Color(0xff1b4d36),
          ),
          scaffoldBackgroundColor: const Color(0xfff1f5f9),
          textTheme: _buildTextTheme(currentLang),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: Color(0xff1b4d36),
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.white),
            actionsIconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xff1b4d36),
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            indicatorColor: const Color(0xff2d7a55),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Colors.white, size: 22);
              }
              return const IconThemeData(color: Color(0xffc2e7cf), size: 22);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                );
              }
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xffc2e7cf),
              );
            }),
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.symmetric(vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              side: BorderSide(color: Color(0xffe2e8f0)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xff2d7a55)),
            ),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xff192342),
            ),
          ),
          useMaterial3: true,
        ),
        defaultTransition: Transition.cupertino,
        builder: (context, child) => DairyMilkOverlay(
          child: child ?? const SizedBox.shrink(),
        ),
        getPages: [
          GetPage(
            name: '/auth',
            page: () => AuthPage(api: api),
          ),
          GetPage(
            name: '/dashboard',
            page: () => Dashboard(api: api),
          ),
        ],
        home: Obx(() {
          if (!appController.ready.value) {
            return DairySplashScreen(
              statusText: appController.api.hasSession
                  ? T.t('Loading dashboard...')
                  : T.t('Starting Dairy Desk...'),
            );
          }
          final latest = appController.updateService.latestInfo.value;
          if (appController.updateService.hasUpdate.value && latest != null) {
            return AppUpdateScreen(
              info: latest,
              updateService: appController.updateService,
            );
          }
          return appController.api.hasSession
              ? Dashboard(api: api)
              : AuthPage(api: api);
        }),
      );
    });
  }
}

class DairySplashScreen extends StatelessWidget {
  const DairySplashScreen({super.key, this.statusText});

  final String? statusText;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final shortest = media.shortestSide;
    // Responsive loader icon size scaling with screen width/height:
    // Small phones (~320-360px): ~100-108px
    // Standard phones (~390-430px): ~120-130px
    // Tablets / Large screens (>600px): ~160-180px
    final loaderSize = (shortest * 0.30).clamp(100.0, 180.0);

    return Scaffold(
      backgroundColor: const Color(0xfff7faf8),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xfff8fbf9),
                  Color(0xffedf5f0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    DairyMilkLoader(
                      size: loaderSize,
                      showText: false,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Dairy Desk',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: (shortest * 0.07).clamp(24.0, 34.0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: const Color(0xff1b4d36),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      T.t('Pure & Fresh Dairy Management'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: (shortest * 0.035).clamp(13.0, 16.0),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff2d7a55),
                      ),
                    ),
                    const Spacer(flex: 4),
                    Text(
                      'Smart & Simple Milk Accounting',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.api, this.initialEmail});
  final ApiService api;
  final String? initialEmail;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool signup = false, busy = false;
  bool obscurePassword = true;
  final formKey = GlobalKey<FormState>();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  late final TextEditingController email;
  final password = TextEditingController();
  final dairyName = TextEditingController();

  @override
  void initState() {
    super.initState();
    email = TextEditingController(text: widget.initialEmail ?? '');
    if (widget.initialEmail == null || widget.initialEmail!.trim().isEmpty) {
      widget.api.getLastAccountEmail().then((saved) {
        if (saved != null && saved.isNotEmpty && mounted && email.text.trim().isEmpty) {
          setState(() => email.text = saved);
        }
      });
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (signup) {
        await widget.api.signup(
          firstName.text.trim(),
          lastName.text.trim(),
          email.text.trim(),
          password.text,
          dairyName.text.trim(),
        );
        if (!mounted) return;
        await Get.to(
          () => VerifyEmailPage(
            api: widget.api,
            email: email.text.trim(),
          ),
        );
        return;
      } else {
        await widget.api.login(email.text.trim(), password.text);
        await widget.api.saveLastAccountEmail(email.text.trim());
      }
      if (!mounted) return;
      final dashCtrl = Get.isRegistered<DashboardController>()
          ? Get.find<DashboardController>()
          : Get.put(DashboardController(widget.api));
      await dashCtrl.load().timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
      if (!mounted) return;
      Get.offAll(() => Dashboard(api: widget.api));
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showMessage(String message) => Get.snackbar(
    T.t('Unable to continue'),
    message,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
  );

  @override
  Widget build(BuildContext context) {
    final langController = Get.isRegistered<AppLanguageController>()
        ? Get.find<AppLanguageController>()
        : null;

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  // Top Row: Language Quick Switcher
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (langController != null)
                        PopupMenuButton<String>(
                          onSelected: (code) => langController.setLanguage(code),
                          tooltip: T.t('Language & localization'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xffe2e8f0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.globe,
                                  size: 14,
                                  color: Color(0xff166534),
                                ),
                                const SizedBox(width: 6),
                                Obx(() {
                                  final current = langController.language.value;
                                  final label = current == 'gu'
                                      ? 'ગુજરાતી'
                                      : current == 'hi'
                                          ? 'हिन्दी'
                                          : 'English';
                                  return Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff166534),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 4),
                                const Icon(
                                  LucideIcons.chevronDown,
                                  size: 12,
                                  color: Color(0xff166534),
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            const PopupMenuItem(
                              value: 'gu',
                              child: Text('ગુજરાતી (Gujarati)'),
                            ),
                            const PopupMenuItem(
                              value: 'hi',
                              child: Text('हिन्दी (Hindi)'),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Brand Hero Header
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xffecfdf5), Color(0xffd1fae5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xffa7f3d0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff059669).withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.milk,
                        size: 38,
                        color: Color(0xff15803d),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Dairy Desk',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff0f172a),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    T.t(signup
                        ? 'Create your dairy account'
                        : 'Welcome back to your dairy desk'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Modern Form Container Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xffe2e8f0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return const Color(0xfff1f5f9);
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xff166534);
                                }
                                return const Color(0xff64748b);
                              }),
                              elevation: WidgetStateProperty.resolveWith<double>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return 1.5;
                                }
                                return 0;
                              }),
                              side: const WidgetStatePropertyAll(BorderSide(color: Color(0xffe2e8f0))),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(
                                  T.t('Log in'),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(
                                  T.t('Create account'),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                            selected: {signup},
                            onSelectionChanged: busy
                                ? null
                                : (selection) => setState(() => signup = selection.first),
                          ),

                          const SizedBox(height: 20),

                          if (signup) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: firstName,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: InputDecoration(
                                      labelText: T.t('First name'),
                                      prefixIcon: const Icon(LucideIcons.user, size: 18),
                                      filled: true,
                                      fillColor: const Color(0xfff8fafc),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xff166534), width: 2),
                                      ),
                                    ),
                                    validator: _required,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: lastName,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: InputDecoration(
                                      labelText: T.t('Last name'),
                                      prefixIcon: const Icon(LucideIcons.user, size: 18),
                                      filled: true,
                                      fillColor: const Color(0xfff8fafc),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xff166534), width: 2),
                                      ),
                                    ),
                                    validator: _required,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: dairyName,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: T.t('Dairy name'),
                                prefixIcon: const Icon(LucideIcons.store, size: 18),
                                filled: true,
                                fillColor: const Color(0xfff8fafc),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xff166534), width: 2),
                                ),
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Email or Mobile Field
                          TextFormField(
                            controller: email,
                            keyboardType: signup
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: signup
                                  ? T.t('Email address')
                                  : T.t('Email address or mobile number'),
                              prefixIcon: Icon(
                                signup ? LucideIcons.mail : LucideIcons.userCheck,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: const Color(0xfff8fafc),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xff166534), width: 2),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return T.t('Required');
                              }
                              final val = v.trim();
                              if (signup) {
                                return _isValidEmail(val)
                                    ? null
                                    : T.t('Enter a valid email');
                              }
                              if (val.contains('@')) {
                                return _isValidEmail(val)
                                    ? null
                                    : T.t('Enter a valid email');
                              }
                              final digits = val.replaceAll(RegExp(r'\D'), '');
                              if (digits.length >= 10 && digits.length <= 15) {
                                return null;
                              }
                              return T.t('Enter a valid email or 10-digit mobile number');
                            },
                          ),

                          const SizedBox(height: 14),

                          // Password Field
                          TextFormField(
                            controller: password,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: T.t('Password'),
                              prefixIcon: const Icon(LucideIcons.lock, size: 18),
                              filled: true,
                              fillColor: const Color(0xfff8fafc),
                              helperText: signup
                                  ? T.t('Minimum 6 characters, 1 number, 1 special character')
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xff166534), width: 2),
                              ),
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? T.t('Show password')
                                    : T.t('Hide password'),
                                icon: Icon(
                                  obscurePassword
                                      ? LucideIcons.eye
                                      : LucideIcons.eyeOff,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                signup ? _strongPasswordError(v) : _required(v),
                          ),

                          if (!signup) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xff166534),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: busy
                                    ? null
                                    : () => Get.to(
                                          () => ForgotPasswordPage(
                                            api: widget.api,
                                            initialEmail: email.text.trim(),
                                          ),
                                        ),
                                icon: const Icon(LucideIcons.keyRound, size: 13),
                                label: Text(
                                  T.t('Forgot password?'),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Submit Button
                          FilledButton(
                            onPressed: busy ? null : submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff166534),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: busy
                                ? DairyMilkLoader.mini(color: Colors.white, size: 22)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        signup ? LucideIcons.userPlus : LucideIcons.logIn,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        T.t(signup ? 'Create account' : 'Log in'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Need Help? Contact Support Button
                  InkWell(
                    onTap: () => SupportHelper.showSupportSheet(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.headphones,
                            size: 14,
                            color: Color(0xff166534),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            T.t('Need help? Contact Support'),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    super.key,
    required this.api,
    required this.email,
  });
  final ApiService api;
  final String email;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final code = TextEditingController();
  bool busy = false;
  int resendCountdown = 30;
  Timer? resendTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    resendTimer?.cancel();
    if (mounted) setState(() => resendCountdown = 30);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => resendCountdown = 0);
      } else {
        if (mounted) setState(() => resendCountdown--);
      }
    });
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    code.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (code.text.trim().length != 6) return;
    setState(() => busy = true);
    try {
      await widget.api.verifyEmail(widget.email, code.text.trim());
      final dashCtrl = Get.isRegistered<DashboardController>()
          ? Get.find<DashboardController>()
          : Get.put(DashboardController(widget.api));
      await dashCtrl.load().timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
      if (mounted) Get.offAll(() => Dashboard(api: widget.api));
    } catch (error) {
      if (mounted) _showAuthMessage(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    if (resendCountdown > 0 || busy) return;
    setState(() => busy = true);
    try {
      await widget.api.resendVerification(widget.email);
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text(T.t('Verification code sent')),
          backgroundColor: const Color(0xff2d7a55),
        ));
      }
    } catch (error) {
      if (mounted) _showAuthMessage(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _CodePage(
    title: T.t('Verify your email'),
    description: '${T.t('Enter the 6-digit code sent to')} ${widget.email}',
    controller: code,
    buttonText: T.t('Verify email'),
    busy: busy,
    resendCountdown: resendCountdown,
    onSubmit: verify,
    onResend: resend,
  );
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.api, this.initialEmail});
  final ApiService api;
  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController email;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    final targetEmail = email.text.trim();
    setState(() => busy = true);
    try {
      await widget.api.requestPasswordReset(targetEmail);
      if (!mounted) return;
      await Get.to(
        () => ResetPasswordPage(
          api: widget.api,
          email: targetEmail,
        ),
      );
    } catch (error) {
      if (mounted) _showAuthMessage(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(T.t('Forgot password'))),
    body: Form(
      key: formKey,
      child: ListView(
        padding: _pagePadding(context),
        children: [
          Text(
            T.t('Enter your registered email address to receive a 6-digit password reset code.'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: T.t('Email address'),
              prefixIcon: const Icon(LucideIcons.mail, size: 18),
              hintText: 'name@example.com',
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return T.t('Required');
              return _isValidEmail(v) ? null : T.t('Enter a valid email address');
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy ? null : submit,
            icon: busy
                ? const SizedBox.shrink()
                : const Icon(LucideIcons.send, size: 18),
            label: busy
                ? DairyMilkLoader.mini(color: Colors.white, size: 22)
                : Text(T.t('Send reset code')),
          ),
        ],
      ),
    ),
  );
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.api,
    required this.email,
  });
  final ApiService api;
  final String email;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final code = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  int resendCountdown = 30;
  Timer? resendTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    resendTimer?.cancel();
    if (mounted) setState(() => resendCountdown = 30);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => resendCountdown = 0);
      } else {
        if (mounted) setState(() => resendCountdown--);
      }
    });
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    code.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> reset() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.api.resetPassword(
        widget.email,
        code.text.trim(),
        password.text,
      );
      if (mounted) {
        Get.offAll(() => AuthPage(api: widget.api, initialEmail: widget.email));
        Get.snackbar(
          T.t('Success'),
          T.t('Password reset successfully'),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xff2d7a55),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (error) {
      if (mounted) _showAuthMessage(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    if (resendCountdown > 0 || busy) return;
    setState(() => busy = true);
    try {
      await widget.api.requestPasswordReset(widget.email);
      _startCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(T.t('Reset code sent')),
            backgroundColor: const Color(0xff2d7a55),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showAuthMessage(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(T.t('Reset password'))),
    body: Form(
      key: formKey,
      child: ListView(
        padding: _pagePadding(context),
        children: [
          Text(
            '${T.t('Enter the 6-digit code sent to')} ${widget.email}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              labelText: T.t('6-digit reset code'),
              hintText: '123456',
            ),
            validator: (value) => value?.trim().length == 6
                ? null
                : T.t('Enter the 6-digit reset code'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: password,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: T.t('New password'),
              helperText: T.t(
                'Minimum 6 characters, 1 number, 1 special character',
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                ),
                onPressed: () =>
                    setState(() => obscurePassword = !obscurePassword),
              ),
            ),
            validator: _strongPasswordError,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: confirmation,
            obscureText: obscureConfirm,
            decoration: InputDecoration(
              labelText: T.t('Confirm new password'),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureConfirm ? LucideIcons.eye : LucideIcons.eyeOff,
                ),
                onPressed: () =>
                    setState(() => obscureConfirm = !obscureConfirm),
              ),
            ),
            validator: (value) =>
                value == password.text ? null : T.t('Passwords do not match'),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: resendCountdown > 0 || busy ? null : resend,
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: Text(
                resendCountdown > 0
                    ? '${T.t('Resend code')} (${resendCountdown}s)'
                    : T.t('Resend code'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : reset,
            child: busy
                ? DairyMilkLoader.mini(color: Colors.white, size: 22)
                : Text(T.t('Reset password')),
          ),
        ],
      ),
    ),
  );

}

class _CodePage extends StatelessWidget {
  const _CodePage({
    required this.title,
    required this.description,
    required this.controller,
    required this.buttonText,
    required this.busy,
    required this.onSubmit,
    required this.onResend,
    this.resendCountdown = 0,
  });
  final String title;
  final String description;
  final TextEditingController controller;
  final String buttonText;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  final int resendCountdown;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: _pagePadding(context),
      children: [
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            labelText: T.t('6-digit code'),
            hintText: '123456',
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: resendCountdown > 0 || busy ? null : onResend,
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: Text(
              resendCountdown > 0
                  ? '${T.t('Resend code')} (${resendCountdown}s)'
                  : T.t('Resend code'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: busy
              ? DairyMilkLoader.mini(color: Colors.white, size: 22)
              : Text(buttonText),
        ),
      ],
    ),
  );
}

void _showAuthMessage(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
}
class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.api});
  final ApiService api;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentTab = 0;
  late final DashboardController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : Get.put(DashboardController(widget.api));

    if (Get.isRegistered<AppController>()) {
      final appCtrl = Get.find<AppController>();
      final latest = appCtrl.updateService.latestInfo.value;
      if (appCtrl.updateService.hasUpdate.value && latest != null) {
        appCtrl.updateService.navigateToUpdateScreen(latest);
        return;
      }
    }
  }

  Future<void> _openAddCustomer(
      BuildContext context, DashboardController controller) async {
    await controller.loadSettings();
    final added = await Get.to<bool>(
      () => CreateCustomerPage(
        api: widget.api,
        defaultLiters: controller.defaultLiters.value,
        defaultPrice: controller.defaultPrice.value,
      ),
    );
    if (added == true) {
      await controller.loadCustomers();
      await controller.loadTodaySummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<AppController>()) {
        final appCtrl = Get.find<AppController>();
        final updateInfo = appCtrl.updateService.latestInfo.value;
        if (appCtrl.updateService.hasUpdate.value && updateInfo != null) {
          return AppUpdateScreen(
            info: updateInfo,
            updateService: appCtrl.updateService,
          );
        }
      }
      return Scaffold(
        body: IndexedStack(
          index: _currentTab,
          children: [
            DashboardScreen(
              api: widget.api,
              controller: controller,
              onNavigateTab: (tabIndex) => setState(() => _currentTab = tabIndex),
              onOpenAddCustomer: () => _openAddCustomer(context, controller),
            ),
            _buildCustomersView(context, controller),
            WhatsAppMessagingScreen(api: widget.api),
            SettingsPage(
              api: widget.api,
              defaultLiters: controller.defaultLiters.value,
              defaultPrice: controller.defaultPrice.value,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xff1b4d36),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: NavigationBar(
            backgroundColor: const Color(0xff1b4d36),
            selectedIndex: _currentTab,
            onDestinationSelected: (index) {
              setState(() => _currentTab = index);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(LucideIcons.layoutDashboard),
                label: T.t('Dashboard'),
              ),
              NavigationDestination(
                icon: const Icon(LucideIcons.users),
                label: T.t('Customers'),
              ),
              NavigationDestination(
                icon: const Icon(LucideIcons.messageCircle),
                label: T.t('Messages'),
              ),
              NavigationDestination(
                icon: const Icon(LucideIcons.settings),
                label: T.t('Settings'),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCustomersView(
      BuildContext context, DashboardController controller) {
    return Obx(() {
      final query = controller.searchQuery.value;
      final visible = controller.customers.where((customer) {
        final name = '${customer['name'] ?? customer['fullName'] ?? ''}'
            .toLowerCase();
        final number =
            '${customer['uniqueNumber'] ?? customer['customerNumber'] ?? customer['number'] ?? ''}'
                .toLowerCase();
        return name.contains(query) || number.contains(query);
      }).toList();

      return Scaffold(
        backgroundColor: const Color(0xfff1f5f9),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xff1b4d36),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.dairyName.value.isEmpty
                    ? T.t('Dairy Desk')
                    : controller.dairyName.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.2,
                  color: Colors.white,
                ),
              ),
              if (controller.ownerName.value.isNotEmpty)
                Text(
                  '${T.t("Welcome back")}, ${controller.ownerName.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffdcefe3),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              _pagePadding(context).horizontal / 2,
              10,
              _pagePadding(context).horizontal / 2,
              100,
            ),
            children: [
              Container(
                height: 36,
                margin: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  onChanged: controller.setSearch,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    hintText: T.t('Search by name or customer number'),
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(LucideIcons.search, size: 16),
                    suffixIcon: controller.searchQuery.value.isNotEmpty
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(LucideIcons.x, size: 14),
                            onPressed: () => controller.setSearch(''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xff2d7a55)),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ),
              if (controller.loading.value && controller.customers.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: DairyMilkLoader(
                          size: 48,
                          message: 'Loading customers...',
                        ),
                      ),
                    )
                  else if (controller.error.isNotEmpty &&
                      controller.customers.isEmpty)
                    _ErrorState(
                      message: controller.error.value,
                      onRetry: controller.load,
                    )
                  else if (visible.isEmpty)
                    _EmptyState(hasSearch: query.isNotEmpty)
                  else
                    ...visible.map(
                      (customer) => _CustomerTile(
                        customer: customer,
                        api: widget.api,
                        onChanged: () async {
                          await controller.loadCustomers();
                          await controller.loadTodaySummary();
                        },
                      ),
                    ),
                ],
              ),
            ),
        floatingActionButton: FloatingActionButton.extended(
          tooltip: T.t('Add customer'),
          onPressed: controller.loading.value
              ? null
              : () => _openAddCustomer(context, controller),
          backgroundColor: const Color(0xff1b4d36),
          foregroundColor: Colors.white,
          elevation: 3,
          highlightElevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xff2d7a55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.userPlus,
              size: 18,
              color: Colors.white,
            ),
          ),
          label: Text(
            T.t('Add customer'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    });
  }
}

String formatDisplayPhoneNumber(String? raw) {
  if (raw == null) return '';
  final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '').trim();
  if (cleaned.isEmpty || cleaned == 'null') return '';
  String digits = cleaned.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length == 10) {
    return '+91 $digits';
  }
  return cleaned.startsWith('+') ? cleaned : '+91 $cleaned';
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.api,
    required this.onChanged,
  });
  final Map<String, dynamic> customer;
  final ApiService api;
  final Future<void> Function() onChanged;

  static String _formatLiters(double val) {
    if (val == val.truncateToDouble()) return val.toStringAsFixed(0);
    String s = val.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s;
  }

  Widget _buildPresetChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xfff0fdf4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xff86efac), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xff166534),
          ),
        ),
      ),
    );
  }

  Future<void> _addMilk(BuildContext context) async {
    final hasToday = customer['hasTodayEntry'] == true || customer['todayLiters'] != null;
    final existingTodayLiters = customer['todayLiters'] != null
        ? (double.tryParse('${customer['todayLiters']}') ?? 0.0)
        : (hasToday ? (double.tryParse('${customer['liters']}') ?? 0.0) : 0.0);
    final defaultToAdd = customer['defaultLiters'] != null
        ? '${customer['defaultLiters']}'
        : (!hasToday ? '${customer['liters'] ?? 1}' : '1');
    final liters = TextEditingController(text: defaultToAdd);
    final price = TextEditingController(text: '${customer['todayPrice'] ?? customer['price'] ?? 0}');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (dialogContext) {
        double currentLiters = double.tryParse(liters.text.trim()) ?? 0;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${T.t('Add today’s milk')} - ${customer['name']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: T.t('Close'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: hasToday ? const Color(0xffecfdf5) : const Color(0xfff0fdf4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: hasToday ? const Color(0xffa7f3d0) : const Color(0xffbbf7d0)),
                      ),
                      child: Row(
                        children: [
                          Icon(hasToday ? Icons.check_circle_outline : LucideIcons.info, size: 16, color: const Color(0xff166534)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasToday && existingTodayLiters > 0
                                  ? '${T.t('Today\'s current')}: ${existingTodayLiters.toStringAsFixed(1)} L. ${T.t('Adding')} ${currentLiters.toStringAsFixed(1)} L → ${T.t('Total')}: ${(existingTodayLiters + currentLiters).toStringAsFixed(1)} L'
                                  : T.t('Adds to today’s total (e.g. 2 + 2 = 4 L)'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Plus/Minus row for liters
                    Row(
                      children: [
                        Material(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: currentLiters > 0
                                ? () {
                                    setDialogState(() {
                                      currentLiters = double.parse(
                                        (currentLiters - 0.25).clamp(0, double.infinity).toStringAsFixed(2),
                                      );
                                      liters.text = _formatLiters(currentLiters);
                                    });
                                  }
                                : null,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.remove, color: Colors.red.shade400),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: liters,
                            autofocus: false,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: T.t('Liters'),
                              suffixText: 'L',
                            ),
                            onChanged: (value) {
                              final parsed = double.tryParse(value.trim());
                              if (parsed != null && parsed >= 0) {
                                setDialogState(() => currentLiters = parsed);
                              }
                            },
                            validator: _number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: const Color(0xffdcefe3),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setDialogState(() {
                                currentLiters = double.parse(
                                  (currentLiters + 0.25).toStringAsFixed(2),
                                );
                                liters.text = _formatLiters(currentLiters);
                              });
                            },
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.add, color: Color(0xff2d7a55)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Quick Presets: +250 ml, +500 ml, +750 ml, +1 L
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildPresetChip(
                          label: '+250 ml',
                          onTap: () {
                            setDialogState(() {
                              currentLiters = double.parse(
                                (currentLiters + 0.25).toStringAsFixed(2),
                              );
                              liters.text = _formatLiters(currentLiters);
                            });
                          },
                        ),
                        _buildPresetChip(
                          label: '+500 ml',
                          onTap: () {
                            setDialogState(() {
                              currentLiters = double.parse(
                                (currentLiters + 0.50).toStringAsFixed(2),
                              );
                              liters.text = _formatLiters(currentLiters);
                            });
                          },
                        ),
                        _buildPresetChip(
                          label: '+750 ml',
                          onTap: () {
                            setDialogState(() {
                              currentLiters = double.parse(
                                (currentLiters + 0.75).toStringAsFixed(2),
                              );
                              liters.text = _formatLiters(currentLiters);
                            });
                          },
                        ),
                        _buildPresetChip(
                          label: '+1 L',
                          onTap: () {
                            setDialogState(() {
                              currentLiters = double.parse(
                                (currentLiters + 1.00).toStringAsFixed(2),
                              );
                              liters.text = _formatLiters(currentLiters);
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: price,
                      autofocus: false,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: T.t('Price per liter'),
                        prefixText: '₹ ',
                      ),
                      validator: _number,
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff2d7a55),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    developer.log(
                      'Save entry button pressed for customer ${customer['id']}',
                      name: 'MilkEntry',
                    );
                    if (!formKey.currentState!.validate()) return;
                    final litersValue = double.parse(liters.text.trim());
                    final priceValue = double.parse(price.text.trim());
                    developer.log(
                      'Entry form valid: liters=$litersValue price=$priceValue',
                      name: 'MilkEntry',
                    );
                    Navigator.of(dialogContext).pop({'liters': litersValue, 'price': priceValue});
                  },
                  child: Text(
                    T.t('Save entry'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    liters.dispose();
    price.dispose();
    if (result == null || !context.mounted) {
      developer.log('Entry dialog closed without saving', name: 'MilkEntry');
      return;
    }
    final customerId = '${customer['id'] ?? customer['cid'] ?? ''}'.trim();
    if (customerId.isEmpty || customerId == 'null') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.t('Cannot save entry: customer ID is missing.'))),
        );
      }
      return;
    }
    final litersValue = result['liters'] ?? 0.0;
    final priceValue = result['price'] ?? 0.0;
    developer.log(
      'Starting entry API call: customerId=$customerId '
      'liters=$litersValue price=$priceValue '
      'baseUrl=${api.baseUrl}',
      name: 'MilkEntry',
    );
    try {
      final entryRes = await api.addMilkEntry(
        customerId,
        date: DateTime.now(),
        liters: litersValue,
        price: priceValue,
        mode: 'add',
      );
      developer.log('Entry API call succeeded', name: 'MilkEntry');
      if (!context.mounted) return;
      await onChanged();
      developer.log(
        'Customer list refreshed after entry save',
        name: 'MilkEntry',
      );
      if (!context.mounted) return;
      final savedLiters = entryRes['liters'] != null
          ? double.tryParse('${entryRes['liters']}')?.toStringAsFixed(1) ?? '$litersValue'
          : '$litersValue';
      final phone = (customer['phoneNumber'] ?? customer['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${T.t('Milk entry saved')} ($savedLiters L)',
          ),
          action: phone.length >= 10
              ? SnackBarAction(
                  label: 'WhatsApp',
                  textColor: Colors.amberAccent,
                  onPressed: () async {
                    try {
                      final dateStr = DateTime.now().toIso8601String().split('T').first;
                      final res = await api.sendDailyWhatsAppEntry(
                        customerId: customerId,
                        date: dateStr,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res['success'] == true
                                  ? 'WhatsApp receipt sent!'
                                  : 'Could not send: ${res['error'] ?? 'Opening WhatsApp...'}',
                            ),
                          ),
                        );
                      }
                      if (res['success'] != true) {
                        final clean = phone.startsWith('91') ? phone : '91$phone';
                        final text = Uri.encodeComponent(
                          'Milk Delivery Update\nCustomer: ${customer['name']}\nQuantity: $savedLiters L\nDairy Desk',
                        );
                        final uri = Uri.parse('whatsapp://send?phone=$clean&text=$text');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    } catch (e) {
                      final clean = phone.startsWith('91') ? phone : '91$phone';
                      final text = Uri.encodeComponent(
                        'Milk Delivery Update\nCustomer: ${customer['name']}\nQuantity: $savedLiters L\nDairy Desk',
                      );
                      final uri = Uri.parse('whatsapp://send?phone=$clean&text=$text');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                )
              : null,
        ),
      );
    } catch (error) {
      developer.log(
        'Entry API call failed: $error',
        name: 'MilkEntry',
        error: error,
        stackTrace: StackTrace.current,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await Get.to<bool>(
      () => EditCustomerPage(api: api, customer: customer),
    );
    if (updated == true) await onChanged();
  }

  Future<void> _openBillAndEntries() async {
    final updated = await Get.to<bool>(
      () => MonthlyEntriesScreen(api: api, customer: customer),
    );
    if (updated == true) await onChanged();
  }

  Future<void> _deleteCustomer(BuildContext context) async {
    final customerId = '${customer['id'] ?? customer['cid'] ?? ''}'.trim();
    if (customerId.isEmpty) return;
    final name = '${customer['name'] ?? customer['fullName'] ?? 'Customer'}'.trim();
    final number = '${customer['uniqueNumber'] ?? customer['customerNumber'] ?? ''}'.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xfffee2e2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.trash2, color: Color(0xffdc2626), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                T.t('Delete Customer'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '${T.t('Are you sure you want to delete customer')} #$number ($name)?\n\n'
          '${T.t('All milk entries and payment history for this customer will be removed.')}\n\n'
          '${T.t('Note: Customer numbers for other customers (e.g. 1, 2, 3, 5) will remain unchanged.')}',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(T.t('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xffdc2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(T.t('Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await api.deleteCustomer(customerId);
        await onChanged();
        Get.snackbar(
          T.t('Customer Deleted'),
          '$name (#$number) ${T.t('has been removed')}',
          backgroundColor: const Color(0xff1e293b),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      } catch (e) {
        Get.snackbar(
          T.t('Error'),
          '${T.t('Failed to delete customer')}: $e',
          backgroundColor: const Color(0xffdc2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      }
    }
  }

  Future<void> _openDetails() async {
    final updated = await Get.to<bool>(
      () => CustomerDetailsPage(api: api, customer: customer),
    );
    if (updated == true) await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${customer['name'] ?? customer['fullName'] ?? 'Unnamed customer'}'.trim();
    final number =
        '${customer['uniqueNumber'] ?? customer['customerNumber'] ?? customer['number'] ?? ''}'.trim();
    final phone =
        '${customer['phoneNumber'] ?? customer['mobileNumber'] ?? customer['phone'] ?? ''}'.trim();
    final hasTodayEntry = customer['hasTodayEntry'] == true || customer['todayLiters'] != null;
    final todayLiters = customer['todayLiters'] ?? (hasTodayEntry ? customer['liters'] : null);
    final liters = (todayLiters ?? customer['liters'] ?? customer['defaultLiters'] ?? 0);
    final price = (customer['todayPrice'] ?? customer['price'] ?? customer['defaultPrice'] ?? 0);
    final channel =
        '${customer['notificationChannel'] ?? 'whatsapp'}'.toLowerCase();
    final isWhatsApp = channel == 'whatsapp';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff1e293b).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openDetails,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Customer Details (Name & Phone) + 3-Dot Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar with sequential number & optional WhatsApp badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xffdcefe3), Color(0xffc2e7cf)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            number.isNotEmpty ? '#$number' : '#',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff2d7a55),
                            ),
                          ),
                        ),
                        if (isWhatsApp)
                          Positioned(
                            right: -3,
                            bottom: -3,
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xff25D366),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.messageCircle,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),

                    // Customer info: Name and Phone with generous width
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff111827),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (phone.isNotEmpty && phone != 'null') ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.phone,
                                  size: 11,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    formatDisplayPhoneNumber(phone),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Three-dot popup menu
                    PopupMenuButton<String>(
                      tooltip: T.t('More options'),
                      icon: Icon(
                        LucideIcons.moreVertical,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 170),
                      onSelected: (value) {
                        if (value == 'bill_entries' ||
                            value == 'milk_card' ||
                            value == 'monthly') {
                          _openBillAndEntries();
                        }
                        if (value == 'whatsapp') {
                          SendWhatsAppBillSheet.show(
                            context,
                            api: api,
                            customer: customer,
                          );
                        }
                        if (value == 'edit') _edit(context);
                        if (value == 'details') _openDetails();
                        if (value == 'delete') _deleteCustomer(context);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'bill_entries',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              LucideIcons.receiptText,
                              color: Color(0xff2d7a55),
                              size: 18,
                            ),
                            title: Text(
                              T.t('Bill & Entries'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'whatsapp',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              LucideIcons.messageCircle,
                              color: Color(0xff25D366),
                              size: 18,
                            ),
                            title: Text(
                              T.t('Send WhatsApp Bill'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                            ),
                            title: Text(
                              T.t('Edit customer'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'details',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.person_outline,
                              size: 18,
                            ),
                            title: Text(
                              T.t('View customer details'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              LucideIcons.trash2,
                              color: Color(0xffdc2626),
                              size: 18,
                            ),
                            title: Text(
                              T.t('Delete customer'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xffdc2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Bottom Row: Metrics & Quick Action Buttons (Adaptive Wrap)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Metrics row: Liters pill & Rate pill
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: hasTodayEntry ? const Color(0xffdcfce7) : const Color(0xffdcefe3),
                            borderRadius: BorderRadius.circular(6),
                            border: hasTodayEntry ? Border.all(color: const Color(0xff86efac), width: 0.8) : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.droplets,
                                size: 12,
                                color: Color(0xff2d7a55),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$liters L',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff2d7a55),
                                ),
                              ),
                              if (hasTodayEntry) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff2d7a55),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    T.t('Today'),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xfff0fdf4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xffbbf7d0),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '₹$price/L',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff166534),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Action buttons: Entry & Bill
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Save Milk Entry Button
                        Tooltip(
                          message: T.t('Save entry'),
                          child: Material(
                            color: const Color(0xff2d7a55),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => _addMilk(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.circlePlus,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      T.t('Entry'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Bill & Entries Button
                        Tooltip(
                          message: T.t('Bill & Entries'),
                          child: Material(
                            color: const Color(0xfff0fdf4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(
                                color: Color(0xff86efac),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: _openBillAndEntries,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.receiptText,
                                      size: 13,
                                      color: Color(0xff166534),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      T.t('Bill'),
                                      style: const TextStyle(
                                        color: Color(0xff166534),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerDetailsPage extends StatefulWidget {
  const CustomerDetailsPage({
    super.key,
    required this.api,
    required this.customer,
  });
  final ApiService api;
  final Map<String, dynamic> customer;

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  late Map<String, dynamic> _customer;

  @override
  void initState() {
    super.initState();
    _customer = Map<String, dynamic>.from(widget.customer);
  }

  Future<void> _editCustomer() async {
    final updated = await Get.to<bool>(
      () => EditCustomerPage(api: widget.api, customer: _customer),
    );
    if (updated == true && mounted) {
      Get.back(result: true);
    }
  }

  Future<void> _deleteCustomer() async {
    final customerId = '${_customer['id'] ?? _customer['cid'] ?? ''}'.trim();
    if (customerId.isEmpty) return;
    final name = '${_customer['name'] ?? _customer['fullName'] ?? 'Customer'}'.trim();
    final number = '${_customer['uniqueNumber'] ?? _customer['customerNumber'] ?? ''}'.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xfffee2e2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.trash2, color: Color(0xffdc2626), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                T.t('Delete Customer'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '${T.t('Are you sure you want to delete customer')} #$number ($name)?\n\n'
          '${T.t('All milk entries and payment history for this customer will be removed.')}\n\n'
          '${T.t('Note: Customer numbers for other customers (e.g. 1, 2, 3, 5) will remain unchanged.')}',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(T.t('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xffdc2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(T.t('Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.api.deleteCustomer(customerId);
        Get.back(result: true);
        Get.snackbar(
          T.t('Customer Deleted'),
          '$name (#$number) ${T.t('has been removed')}',
          backgroundColor: const Color(0xff1e293b),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      } catch (e) {
        Get.snackbar(
          T.t('Error'),
          '${T.t('Failed to delete customer')}: $e',
          backgroundColor: const Color(0xffdc2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final name = '${customer['name'] ?? customer['fullName'] ?? 'Customer'}';
    final number =
        '${customer['uniqueNumber'] ?? customer['customerNumber'] ?? '—'}';
    final liters = _asDouble(customer['liters']);
    final price = _asDouble(customer['price']);
    final dailyTotal = liters * price;
    final phone = '${customer['phoneNumber'] ?? ''}'.trim();
    final hasPhone =
        phone.isNotEmpty && phone != 'null' && phone != 'Not provided';
    final channel =
        '${customer['notificationChannel'] ?? 'whatsapp'}'.toLowerCase();
    final isSms = channel == 'sms';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xfff1f5f9),
      appBar: AppBar(
        title: Text(
          T.t('Customer details'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xff1b4d36),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: T.t('Bill & Entries'),
            onPressed: () => Get.to(
              () => MonthlyEntriesScreen(
                api: widget.api,
                customer: _customer,
              ),
            ),
            icon: const Icon(
              LucideIcons.receiptText,
              color: Colors.white,
            ),
          ),
          IconButton(
            tooltip: T.t('Send WhatsApp Bill'),
            onPressed: () => SendWhatsAppBillSheet.show(
              context,
              api: widget.api,
              customer: _customer,
            ),
            icon: const Icon(
              LucideIcons.messageCircle,
              color: Color(0xff4ade80),
            ),
          ),
          IconButton(
            tooltip: T.t('Edit customer'),
            onPressed: _editCustomer,
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: T.t('Delete customer'),
            onPressed: _deleteCustomer,
            icon: const Icon(LucideIcons.trash2, color: Color(0xfff87171)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: _pagePadding(context).horizontal / 2,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FIRST TILE: COMPACT CUSTOMER PROFILE & CONTACT
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color:
                      isDark ? Colors.grey.shade800 : const Color(0xffE2E8F0),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xffdcefe3),
                      child: Text(
                        number == '—' ? '1' : number,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff2d7a55),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              InkWell(
                                onTap: hasPhone
                                    ? () => launchUrl(Uri.parse('tel:$phone'))
                                    : null,
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 13.5,
                                      color: hasPhone
                                          ? const Color(0xff2d7a55)
                                          : Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasPhone ? formatDisplayPhoneNumber(phone) : T.t('Not provided'),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: hasPhone
                                            ? (isDark
                                                ? Colors.grey.shade300
                                                : const Color(0xff334155))
                                            : Colors.grey.shade500,
                                        decoration: hasPhone
                                            ? TextDecoration.underline
                                            : TextDecoration.none,
                                        decorationColor:
                                            const Color(0xff2d7a55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSms
                                      ? const Color(0xffeff6ff)
                                      : const Color(0xfff0fdf4),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isSms
                                        ? const Color(0xffbfdbfe)
                                        : const Color(0xffbbf7d0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSms
                                          ? LucideIcons.messageSquare
                                          : LucideIcons.messageCircle,
                                      size: 11.5,
                                      color: isSms
                                          ? const Color(0xff2563eb)
                                          : const Color(0xff16a34a),
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      isSms ? 'SMS' : 'WhatsApp',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isSms
                                            ? const Color(0xff1e40af)
                                            : const Color(0xff15803d),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Color(0xff2d7a55),
                      ),
                      tooltip: T.t('Edit customer'),
                      onPressed: _editCustomer,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // SECOND TILE: COMPACT & PROFESSIONAL MILK DEFAULTS
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color:
                      isDark ? Colors.grey.shade800 : const Color(0xffE2E8F0),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.milk,
                          size: 16,
                          color: Color(0xff2d7a55),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          T.t('Milk defaults'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade300
                                : const Color(0xff334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade900
                                  : const Color(0xfff8fafc),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : const Color(0xffe2e8f0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  T.t('Daily liters'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${liters.toStringAsFixed(2)} L',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade900
                                  : const Color(0xfff8fafc),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : const Color(0xffe2e8f0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  T.t('Price per liter'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xfff0fdf4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xffbbf7d0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  T.t('Daily amount'),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff166534),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${dailyTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff15803d),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // THIRD TILE: BILL & ENTRIES
            Card(
              color: const Color(0xfff0fdf4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xff86efac)),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xff2d7a55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.receiptText,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                title: Text(
                  T.t('Bill & Entries'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xff166534),
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  T.t('Month-wise milk entries & bill display page'),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: Color(0xff166534),
                ),
                onTap: () => Get.to(
                  () => MonthlyEntriesScreen(
                    api: widget.api,
                    customer: _customer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // QUICK ACTION: SEND WHATSAPP BILL
            Card(
              color: const Color(0xfff0fdf4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xffbbf7d0)),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xff25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.messageCircle,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                title: Text(
                  T.t('Send WhatsApp Bill'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xff166534),
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  T.t('Send daily milk delivery update or monthly statement'),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: Color(0xff166534),
                ),
                onTap: () => SendWhatsAppBillSheet.show(
                  context,
                  api: widget.api,
                  customer: _customer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconBg = const Color(0xfff0fdf4),
    this.iconColor = const Color(0xff2d7a55),
  });
  final IconData icon;
  final String label;
  final String value;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff1f2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch});
  final bool hasSearch;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Column(
      children: [
        Icon(
          hasSearch ? LucideIcons.searchX : LucideIcons.users,
          size: 48,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 12),
        Text(
          hasSearch ? T.t('No customers found') : T.t('No customers yet'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          hasSearch
              ? T.t('Try another name or number')
              : T.t('Add your first customer to get started'),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 50),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 52, color: Colors.grey),
        const SizedBox(height: 12),
        Text(
          T.t('Could not load customers'),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          T.t('Check your connection and try again.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(LucideIcons.refreshCw),
          label: Text(T.t('Try again')),
        ),
      ],
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.api,
    required this.defaultLiters,
    required this.defaultPrice,
  });
  final ApiService api;
  final double defaultLiters;
  final double defaultPrice;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String language;

  @override
  void initState() {
    super.initState();
    language = Get.find<AppLanguageController>().language.value;
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                T.t('Log out?'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: T.t('Close'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
          ],
        ),
        content: Text(T.t('Are you sure you want to log out?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(T.t('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xffdc2626)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(T.t('Log out')),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;

    await widget.api.logout();
    await DashboardController.clearCache();
    Get.delete<DashboardController>();
    Get.offAll(() => AuthPage(api: widget.api));
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    if (!Get.isRegistered<AppController>()) return;
    final appCtrl = Get.find<AppController>();
    Get.snackbar(
      T.t('App Updates'),
      T.t('Checking for latest version...'),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
    );
    final info = await appCtrl.updateService.checkForUpdate(silent: false);
    if (info != null && info.isUpdateAvailable) {
      appCtrl.updateService.navigateToUpdateScreen(info);
    } else if (info != null && !info.isUpdateAvailable) {
      Get.snackbar(
        T.t('Up to Date'),
        '${T.t("You are using the latest version")} (v${AppUpdateService.currentVersion})',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xff1b4d36),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } else {
      Get.snackbar(
        T.t('App Updates'),
        T.t('Unable to reach update server. Please check internet.'),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff1f5f9),
    appBar: AppBar(
      backgroundColor: const Color(0xff1b4d36),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        T.t('Settings'),
        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // 1. Dairy Configuration
        _SettingsSectionTitle(
          title: T.t('Dairy configuration'),
          icon: LucideIcons.milk,
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xffe2e8f0)),
          ),
          color: Colors.white,
          child: _SettingsListTile(
            icon: LucideIcons.milk,
            iconBg: const Color(0xffe8f5e9),
            iconColor: const Color(0xff2d7a55),
            title: T.t('Default milk & price'),
            subtitle:
                '${_formatNumber(widget.defaultLiters)} L • ₹${_formatNumber(widget.defaultPrice)} / L',
            onTap: () async {
              final updated = await Get.to<bool>(
                () => DefaultMilkPricePage(
                  api: widget.api,
                  defaultLiters: widget.defaultLiters,
                  defaultPrice: widget.defaultPrice,
                ),
              );
              if (updated == true && mounted) {
                Get.back(result: true);
              }
            },
          ),
        ),
        const SizedBox(height: 18),

        // 2. Language & Localization
        _SettingsSectionTitle(
          title: T.t('Language & localization'),
          icon: LucideIcons.languages,
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xffe2e8f0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xffe0f2fe),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.globe,
                        color: Color(0xff0284c7),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      T.t('Language'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xff1f2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildLanguageChip(
                      code: 'en',
                      label: 'English',
                      subLabel: 'English',
                    ),
                    const SizedBox(width: 8),
                    _buildLanguageChip(
                      code: 'gu',
                      label: 'ગુજરાતી',
                      subLabel: 'Gujarati',
                    ),
                    const SizedBox(width: 8),
                    _buildLanguageChip(
                      code: 'hi',
                      label: 'हिन्दी',
                      subLabel: 'Hindi',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 3. Account & Security
        _SettingsSectionTitle(
          title: T.t('Account & security'),
          icon: LucideIcons.shieldCheck,
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xffe2e8f0)),
          ),
          color: Colors.white,
          child: Column(
            children: [
              _SettingsListTile(
                icon: LucideIcons.user,
                iconBg: const Color(0xffede9fe),
                iconColor: const Color(0xff7c3aed),
                title: T.t('View profile'),
                onTap: () => Get.to(() => ProfilePage(api: widget.api)),
              ),
              const Divider(height: 1, indent: 54, endIndent: 14, color: Color(0xfff1f5f9)),
              _SettingsListTile(
                icon: LucideIcons.keyRound,
                iconBg: const Color(0xfffef3c7),
                iconColor: const Color(0xffd97706),
                title: T.t('Change password'),
                onTap: () => Get.to(() => ChangePasswordPage(api: widget.api)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 4. Help & Support
        _SettingsSectionTitle(
          title: T.t('Help & support'),
          icon: LucideIcons.lifeBuoy,
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xffe2e8f0)),
          ),
          color: Colors.white,
          child: Column(
            children: [
              _SettingsListTile(
                icon: LucideIcons.headphones,
                iconBg: const Color(0xffccfbf1),
                iconColor: const Color(0xff0f766e),
                title: T.t('Contact support'),
                subtitle: '+91 91041 52524 (WhatsApp / Call)',
                onTap: () => SupportHelper.showSupportSheet(context),
              ),
              const Divider(height: 1, indent: 54, endIndent: 14, color: Color(0xfff1f5f9)),
              _SettingsListTile(
                icon: LucideIcons.messageSquareText,
                iconBg: const Color(0xfff3e8ff),
                iconColor: const Color(0xff9333ea),
                title: T.t('Send feedback'),
                subtitle: T.t('Send feedback via WhatsApp (+91 91041 52524)'),
                onTap: () => SupportHelper.showFeedbackDialog(context),
              ),
              const Divider(height: 1, indent: 54, endIndent: 14, color: Color(0xfff1f5f9)),
              _SettingsListTile(
                icon: LucideIcons.downloadCloud,
                iconBg: const Color(0xffe0f2fe),
                iconColor: const Color(0xff0284c7),
                title: T.t('Check for updates'),
                subtitle: 'v${AppUpdateService.currentVersion} • ${T.t("Tap to check")}',
                onTap: () => _checkForUpdates(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 5. Log Out Action
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xfffee2e2)),
          ),
          color: Colors.white,
          child: _SettingsListTile(
            icon: LucideIcons.logOut,
            iconBg: const Color(0xfffee2e2),
            iconColor: const Color(0xffdc2626),
            title: T.t('Log out'),
            titleColor: const Color(0xffdc2626),
            onTap: _confirmLogout,
          ),
        ),
        const SizedBox(height: 28),

        // App Footer & Dynamic Version Info
        Center(
          child: InkWell(
            onLongPress: () {
              // Allows owner to preview and test the update screen lockout
              if (Get.isRegistered<AppController>()) {
                final appCtrl = Get.find<AppController>();
                appCtrl.updateService.navigateToUpdateScreen(
                  AppVersionInfo(
                    latestVersion: '1.0.2',
                    buildNumber: 3,
                    minSupportedVersion: '1.0.2',
                    forceUpdate: true,
                    title: 'New Version Available! 🚀',
                    releaseNotes: '• Dynamic version tracking in Settings\n• Full-screen update lockout preview\n• Direct OTA update installation',
                    downloadUrl: '/app/download-latest',
                    apkSize: '59.7 MB',
                    publishedAt: DateTime.now().toIso8601String(),
                    isUpdateAvailable: true,
                    mustForceUpdate: true,
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Text(
                    'Dairy Desk • v${AppUpdateService.currentVersion} (Build ${AppUpdateService.currentBuildNumber})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smart Dairy Management Solution',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildLanguageChip({
    required String code,
    required String label,
    required String subLabel,
  }) {
    final isSelected = language == code;
    return Expanded(
      child: InkWell(
        onTap: () async {
          setState(() => language = code);
          await Get.find<AppLanguageController>().setLanguage(code);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff1b4d36) : const Color(0xfff8fafc),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xff1b4d36) : const Color(0xffe2e8f0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isSelected ? Colors.white : const Color(0xff1f2937),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? const Color(0xffc2e7cf) : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DefaultMilkPricePage extends StatefulWidget {
  const DefaultMilkPricePage({
    super.key,
    required this.api,
    required this.defaultLiters,
    required this.defaultPrice,
  });
  final ApiService api;
  final double defaultLiters;
  final double defaultPrice;

  @override
  State<DefaultMilkPricePage> createState() => _DefaultMilkPricePageState();
}

class _DefaultMilkPricePageState extends State<DefaultMilkPricePage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController liters;
  late final TextEditingController price;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    liters = TextEditingController(text: _formatNumber(widget.defaultLiters));
    price = TextEditingController(text: _formatNumber(widget.defaultPrice));
  }

  @override
  void dispose() {
    liters.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.api.updateSettings(
        defaultLiters: double.parse(liters.text.trim()),
        defaultPrice: double.parse(price.text.trim()),
      );
      if (mounted) Get.back(result: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff1f5f9),
    appBar: AppBar(
      backgroundColor: const Color(0xff1b4d36),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        T.t('Default milk & price'),
        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      ),
    ),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffe2e8f0)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xffe8f5e9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.milk,
                          color: Color(0xff2d7a55),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              T.t('Default milk & price'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff1f2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              T.t(
                                'These values are filled automatically when you add a customer. '
                                'You can change them for any individual customer.',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: liters,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: T.t('Default liters'),
                      prefixIcon: const Icon(LucideIcons.milk, size: 18),
                    ),
                    validator: _number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: T.t('Default price per liter'),
                      prefixIcon: const Icon(LucideIcons.indianRupee, size: 18),
                    ),
                    validator: _number,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: busy
                          ? DairyMilkLoader.mini(color: Colors.white, size: 22)
                          : Text(T.t('Save defaults')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SettingsListTile extends StatelessWidget {
  const _SettingsListTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: titleColor ?? const Color(0xff1f2937),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.title, this.icon});
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: const Color(0xff1b4d36)),
          const SizedBox(width: 6),
        ],
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xff475569),
          ),
        ),
      ],
    ),
  );
}

class _ChoiceSelector<Option> extends StatelessWidget {
  const _ChoiceSelector({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });
  final String label;
  final Option value;
  final Map<Option, String> options;
  final ValueChanged<Option> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.entries
            .map(
              (entry) => ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == value,
                onSelected: enabled ? (_) => onChanged(entry.key) : null,
              ),
            )
            .toList(),
      ),
    ],
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.api});
  final ApiService api;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    setState(() {
      _profileFuture = widget.api.getProfile();
    });
  }

  Future<void> _openEditProfileDialog(Map<String, dynamic> profile) async {
    final firstNameCtrl = TextEditingController(text: '${profile['firstName'] ?? ''}'.trim());
    final lastNameCtrl = TextEditingController(text: '${profile['lastName'] ?? ''}'.trim());
    final dairyNameCtrl = TextEditingController(text: '${profile['dairyName'] ?? ''}'.trim());
    final phoneCtrl = TextEditingController(text: '${profile['phoneNumber'] ?? profile['phone'] ?? ''}'.trim());
    final editFormKey = GlobalKey<FormState>();
    bool saving = false;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: editFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        T.t('Edit Profile'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff1b4d36),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: () => Navigator.pop(bottomSheetContext, false),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: firstNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: T.t('First name'),
                            prefixIcon: const Icon(LucideIcons.user, size: 18),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? T.t('Required') : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: lastNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: T.t('Last name'),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? T.t('Required') : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: dairyNameCtrl,
                    decoration: InputDecoration(
                      labelText: T.t('Dairy name'),
                      prefixIcon: const Icon(LucideIcons.store, size: 18),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? T.t('Required') : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: T.t('Mobile number'),
                      prefixIcon: const Icon(LucideIcons.phone, size: 18),
                      hintText: '9876543210',
                    ),
                    validator: (v) {
                      final val = v?.trim() ?? '';
                      if (val.isEmpty) return null;
                      final digits = val.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 10 || digits.length > 15) {
                        return T.t('Enter a valid 10-15 digit mobile number');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!editFormKey.currentState!.validate()) return;
                            setModalState(() => saving = true);
                            try {
                              await widget.api.updateProfile(
                                firstName: firstNameCtrl.text.trim(),
                                lastName: lastNameCtrl.text.trim(),
                                dairyName: dairyNameCtrl.text.trim(),
                                phoneNumber: phoneCtrl.text.trim(),
                              );
                              if (Get.isRegistered<DashboardController>()) {
                                final dashCtrl = Get.find<DashboardController>();
                                dashCtrl.dairyName.value = dairyNameCtrl.text.trim();
                                dashCtrl.ownerName.value = '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}'.trim();
                              }
                              if (bottomSheetContext.mounted) {
                                Navigator.pop(bottomSheetContext, true);
                              }
                            } catch (error) {
                              setModalState(() => saving = false);
                              Get.snackbar(
                                T.t('Update Failed'),
                                error.toString(),
                                snackPosition: SnackPosition.BOTTOM,
                                margin: const EdgeInsets.all(16),
                              );
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: saving
                          ? DairyMilkLoader.mini(color: Colors.white, size: 22)
                          : Text(T.t('Save Changes')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (updated == true) {
      _loadProfile();
      Get.snackbar(
        T.t('Profile Updated'),
        T.t('Your profile details have been saved successfully.'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xff1b4d36),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff1f5f9),
    appBar: AppBar(
      title: Text(T.t('Distributor Profile')),
      actions: [
        IconButton(
          tooltip: T.t('Refresh'),
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          onPressed: _loadProfile,
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: DairyMilkLoader(
              size: 48,
              message: 'Loading profile...',
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.alertCircle, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    T.t('Unable to load profile data'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadProfile,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: Text(T.t('Try again')),
                  ),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data ?? {};
        final email = '${profile['email'] ?? ''}'.trim();
        final phone = '${profile['phoneNumber'] ?? profile['phone'] ?? ''}'.trim();
        final dairyName = '${profile['dairyName'] ?? 'Dairy Desk'}'.trim();
        final fullName = '${profile['name'] ?? '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'}'.trim();

        // Access dashboard controller observables if registered
        DashboardController? dashCtrl;
        if (Get.isRegistered<DashboardController>()) {
          dashCtrl = Get.find<DashboardController>();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // 1. Hero Profile Card with Edit Button
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff1b4d36), Color(0xff2d7a55)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              child: Text(
                                _profileInitial(profile),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff1b4d36),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xff22c55e),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fullName.isEmpty ? T.t('Dairy Owner') : fullName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.store, color: Color(0xffdcefe3), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                dairyName,
                                style: const TextStyle(
                                  color: Color(0xffdcefe3),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _openEditProfileDialog(profile),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xffe8f5e9),
                              foregroundColor: const Color(0xff1b4d36),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(LucideIcons.pencil, size: 16),
                            label: Text(T.t('Edit Profile Details')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Dairy Business Operations Overview
            _SettingsSectionTitle(
              title: T.t('Dairy Business Operations'),
              icon: LucideIcons.barChart3,
            ),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: T.t('Default Delivery'),
                            value: '${dashCtrl?.defaultLiters.value.toStringAsFixed(1) ?? '1.0'} L',
                            icon: LucideIcons.milk,
                            color: const Color(0xff0284c7),
                            bg: const Color(0xffe0f2fe),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            label: T.t('Default Price'),
                            value: '₹${dashCtrl?.defaultPrice.value.toStringAsFixed(1) ?? '60.0'}',
                            icon: LucideIcons.indianRupee,
                            color: const Color(0xff16a34a),
                            bg: const Color(0xffdcfce7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: T.t('Active Customers'),
                            value: '${dashCtrl?.customers.length ?? 0} ${T.t("Members")}',
                            icon: LucideIcons.users,
                            color: const Color(0xff7c3aed),
                            bg: const Color(0xffede9fe),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 3. Contact & Account Details
            _SettingsSectionTitle(
              title: T.t('Personal & Contact Info'),
              icon: LucideIcons.circleUser,
            ),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              color: Colors.white,
              child: Column(
                children: [
                  _DetailRow(
                    icon: LucideIcons.user,
                    iconBg: const Color(0xffe0f2fe),
                    iconColor: const Color(0xff0284c7),
                    label: T.t('Full Name'),
                    value: fullName.isEmpty ? '—' : fullName,
                  ),
                  const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xfff1f5f9)),
                  _DetailRow(
                    icon: LucideIcons.mail,
                    iconBg: const Color(0xfffef3c7),
                    iconColor: const Color(0xffd97706),
                    label: T.t('Email Address'),
                    value: email.isEmpty ? '—' : email,
                  ),
                  const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xfff1f5f9)),
                  _DetailRow(
                    icon: LucideIcons.phone,
                    iconBg: const Color(0xffdcfce7),
                    iconColor: const Color(0xff16a34a),
                    label: T.t('Mobile Number'),
                    value: phone.isEmpty ? T.t('Not provided') : formatDisplayPhoneNumber(phone),
                  ),
                  const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xfff1f5f9)),
                  _DetailRow(
                    icon: LucideIcons.store,
                    iconBg: const Color(0xffede9fe),
                    iconColor: const Color(0xff7c3aed),
                    label: T.t('Registered Dairy'),
                    value: dairyName,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. System & Account Status
            _SettingsSectionTitle(
              title: T.t('Security & App Status'),
              icon: LucideIcons.shieldCheck,
            ),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              color: Colors.white,
              child: Column(
                children: [
                  _SettingsListTile(
                    icon: LucideIcons.keyRound,
                    iconBg: const Color(0xfffef3c7),
                    iconColor: const Color(0xffd97706),
                    title: T.t('Change password'),
                    subtitle: T.t('Update your login credentials'),
                    onTap: () => Get.to(() => ChangePasswordPage(api: widget.api)),
                  ),
                  const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xfff1f5f9)),
                  _DetailRow(
                    icon: LucideIcons.checkCheck,
                    iconBg: const Color(0xffdcfce7),
                    iconColor: const Color(0xff15803d),
                    label: T.t('Account Role'),
                    value: 'Distributor (Administrator)',
                  ),
                  const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xfff1f5f9)),
                  _DetailRow(
                    icon: LucideIcons.sparkles,
                    iconBg: const Color(0xffccfbf1),
                    iconColor: const Color(0xff0f766e),
                    label: T.t('Application Version'),
                    value: 'v${AppUpdateService.currentVersion} (Build ${AppUpdateService.currentBuildNumber})',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xff1f2937)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _profileInitial(Map<String, dynamic> profile) {
  final value = '${profile['name'] ?? profile['email'] ?? ''}'.trim();
  return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
}


class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, required this.api});
  final ApiService api;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final formKey = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool hideCurrent = true;
  bool hideNext = true;
  bool hideConfirm = true;
  bool busy = false;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.api.changePassword(
        currentPassword: current.text,
        newPassword: next.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.t('Password changed successfully'))),
      );
      Get.back();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff1f5f9),
    appBar: AppBar(
      backgroundColor: const Color(0xff1b4d36),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        T.t('Change password'),
        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      ),
    ),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffe2e8f0)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xfffef3c7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.keyRound,
                          color: Color(0xffd97706),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              T.t('Change password'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff1f2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              T.t(
                                'Minimum 6 characters, 1 number, 1 special character',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: current,
                    obscureText: hideCurrent,
                    decoration: InputDecoration(
                      labelText: T.t('Current password'),
                      prefixIcon: const Icon(LucideIcons.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideCurrent ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => hideCurrent = !hideCurrent),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? T.t('Required') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: next,
                    obscureText: hideNext,
                    decoration: InputDecoration(
                      labelText: T.t('New password'),
                      prefixIcon: const Icon(LucideIcons.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideNext ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18,
                        ),
                        onPressed: () => setState(() => hideNext = !hideNext),
                      ),
                    ),
                    validator: _strongPasswordError,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirm,
                    obscureText: hideConfirm,
                    decoration: InputDecoration(
                      labelText: T.t('Confirm new password'),
                      prefixIcon: const Icon(LucideIcons.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => hideConfirm = !hideConfirm),
                      ),
                    ),
                    validator: (value) =>
                        value == next.text ? null : T.t('Passwords do not match'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: busy
                          ? DairyMilkLoader.mini(
                              color: Colors.white,
                              size: 20,
                            )
                          : Text(T.t('Change password')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CreateCustomerPage extends StatefulWidget {
  const CreateCustomerPage({
    super.key,
    required this.api,
    required this.defaultLiters,
    required this.defaultPrice,
  });
  final ApiService api;
  final double defaultLiters;
  final double defaultPrice;
  @override
  State<CreateCustomerPage> createState() => _CreateCustomerPageState();
}

class _CreateCustomerPageState extends State<CreateCustomerPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController liters;
  late final TextEditingController price;
  late final TextEditingController phone;
  String selectedCountryCode = '+91';
  String channel = 'whatsapp';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController();
    liters = TextEditingController(text: _formatNumber(widget.defaultLiters));
    price = TextEditingController(text: _formatNumber(widget.defaultPrice));
    phone = TextEditingController();
  }

  @override
  void dispose() {
    name.dispose();
    liters.dispose();
    price.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final fullPhone = buildCustomerPhoneNumber(
        phone.text.trim(),
        selectedCountryCode,
      );
      await widget.api.createCustomer({
        'name': name.text.trim(),
        'liters': double.parse(liters.text.trim()),
        'price': double.parse(price.text.trim()),
        'phoneNumber': fullPhone,
        'notificationChannel': channel,
      });
      if (mounted) Get.back(result: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(T.t('Add customer'))),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            T.t('Customer details'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(T.t('Keep your collection records organized.')),
          const SizedBox(height: 24),
          TextFormField(
            controller: name,
            decoration: InputDecoration(labelText: T.t('Full name')),
            validator: _required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: liters,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: T.t('Liters')),
            validator: _number,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: T.t('Price')),
            validator: _number,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: T.t('Customer phone number'),
              hintText: selectedCountryCode.isNotEmpty
                  ? '98765 43210'
                  : '+91 98765 43210',
              helperText: T.t(
                '10-digit number or country-wise format (e.g. +91 98765 43210)',
              ),
              helperMaxLines: 2,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: PopupMenuButton<String>(
                  tooltip: T.t('Select Country'),
                  initialValue: selectedCountryCode,
                  onSelected: (code) {
                    setState(() {
                      selectedCountryCode = code;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kPopularCountries
                            .firstWhere(
                              (c) => c.code == selectedCountryCode,
                              orElse: () =>
                                  const CountryDialCode('', '', '🌐'),
                            )
                            .flag,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedCountryCode.isNotEmpty
                            ? selectedCountryCode
                            : '🌐',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                      Container(
                        height: 20,
                        width: 1,
                        color: const Color(0xffcbd5e1),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ],
                  ),
                  itemBuilder: (context) => kPopularCountries
                      .map(
                        (c) => PopupMenuItem<String>(
                          value: c.code,
                          child: Row(
                            children: [
                              Text(
                                c.flag,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${c.name} ${c.code.isNotEmpty ? "(${c.code})" : ""}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            validator: (val) => _validateCustomerPhone(
              val,
              selectedCountryCode,
              required: true,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: busy ? null : save,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: busy
                  ? DairyMilkLoader.mini(color: Colors.white, size: 22)
                  : Text(T.t('Save customer')),
            ),
          ),
        ],
      ),
    ),
  );
}

class EditCustomerPage extends StatefulWidget {
  const EditCustomerPage({
    super.key,
    required this.api,
    required this.customer,
  });
  final ApiService api;
  final Map<String, dynamic> customer;

  @override
  State<EditCustomerPage> createState() => _EditCustomerPageState();
}

class _EditCustomerPageState extends State<EditCustomerPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController liters;
  late final TextEditingController price;
  late final TextEditingController phone;
  late String selectedCountryCode;
  late String channel;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: '${widget.customer['name'] ?? ''}');
    liters = TextEditingController(text: '${widget.customer['liters'] ?? 0}');
    price = TextEditingController(text: '${widget.customer['price'] ?? 0}');
    final rawPhone = '${widget.customer['phoneNumber'] ?? ''}'.trim();
    final parsed = parseCustomerPhone(rawPhone);
    selectedCountryCode = parsed.$1;
    phone = TextEditingController(text: parsed.$2);
    channel = '${widget.customer['notificationChannel'] ?? 'whatsapp'}';
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final changes = <String, dynamic>{
        'name': name.text.trim(),
        'liters': double.parse(liters.text.trim()),
        'price': double.parse(price.text.trim()),
        'notificationChannel': channel,
      };
      final phoneValue = phone.text.trim();
      if (phoneValue.isNotEmpty) {
        changes['phoneNumber'] = buildCustomerPhoneNumber(
          phoneValue,
          selectedCountryCode,
        );
      }
      await widget.api.updateCustomer('${widget.customer['id']}', changes);
      if (mounted) Get.back(result: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(T.t('Edit customer'))),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: name,
            decoration: InputDecoration(labelText: T.t('Full name')),
            validator: _required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: liters,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: T.t('Default liters')),
            validator: _number,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: T.t('Default price per liter'),
            ),
            validator: _number,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: T.t('Customer phone number'),
              hintText: selectedCountryCode.isNotEmpty
                  ? '98765 43210'
                  : '+91 98765 43210',
              helperText: T.t(
                '10-digit number or country-wise format (e.g. +91 98765 43210)',
              ),
              helperMaxLines: 2,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: PopupMenuButton<String>(
                  tooltip: T.t('Select Country'),
                  initialValue: selectedCountryCode,
                  onSelected: (code) {
                    setState(() {
                      selectedCountryCode = code;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kPopularCountries
                            .firstWhere(
                              (c) => c.code == selectedCountryCode,
                              orElse: () =>
                                  const CountryDialCode('', '', '🌐'),
                            )
                            .flag,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedCountryCode.isNotEmpty
                            ? selectedCountryCode
                            : '🌐',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                      Container(
                        height: 20,
                        width: 1,
                        color: const Color(0xffcbd5e1),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ],
                  ),
                  itemBuilder: (context) => kPopularCountries
                      .map(
                        (c) => PopupMenuItem<String>(
                          value: c.code,
                          child: Row(
                            children: [
                              Text(
                                c.flag,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${c.name} ${c.code.isNotEmpty ? "(${c.code})" : ""}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            validator: (val) => _validateCustomerPhone(
              val,
              selectedCountryCode,
              required: false,
            ),
          ),
          const SizedBox(height: 14),
          _ChoiceSelector<String>(
            label: T.t('Message channel'),
            value: channel,
            options: {
              'whatsapp': T.t('WhatsApp'),
              'sms': T.t('SMS / Messages'),
            },
            enabled: !busy,
            onChanged: (value) => setState(() => channel = value),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: busy ? null : save,
            child: busy
                ? DairyMilkLoader.mini(color: Colors.white, size: 22)
                : Text(T.t('Save changes')),
          ),
        ],
      ),
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

EdgeInsets _pagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width >= 600
      ? 32.0
      : (width < 360 ? 12.0 : 16.0);
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: 16);
}

String? _strongPasswordError(String? value) {
  if (value == null || value.length < 6) {
    return T.t('Use at least 6 characters');
  }
  if (!RegExp(r'\d').hasMatch(value)) {
    return T.t('Include at least 1 number');
  }
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
    return T.t('Include at least 1 special character');
  }
  return null;
}

String _formatNumber(double value) =>
    value == value.truncateToDouble() ? value.toStringAsFixed(0) : '$value';

String? _number(String? value) {
  if (value == null || value.trim().isEmpty) return T.t('Required');
  final number = double.tryParse(value.trim());
  if (number == null || !number.isFinite) return T.t('Enter a valid number');
  return number < 0 ? 'Cannot be negative' : null;
}

class CountryDialCode {
  final String name;
  final String code;
  final String flag;

  const CountryDialCode(this.name, this.code, this.flag);
}

const List<CountryDialCode> kPopularCountries = [
  CountryDialCode('India', '+91', '🇮🇳'),
  CountryDialCode('United States', '+1', '🇺🇸'),
  CountryDialCode('United Kingdom', '+44', '🇬🇧'),
  CountryDialCode('Canada', '+1', '🇨🇦'),
  CountryDialCode('Australia', '+61', '🇦🇺'),
  CountryDialCode('UAE', '+971', '🇦🇪'),
  CountryDialCode('Saudi Arabia', '+966', '🇸🇦'),
  CountryDialCode('New Zealand', '+64', '🇳🇿'),
  CountryDialCode('Singapore', '+65', '🇸🇬'),
  CountryDialCode('Germany', '+49', '🇩🇪'),
  CountryDialCode('France', '+33', '🇫🇷'),
  CountryDialCode('Kenya', '+254', '🇰🇪'),
  CountryDialCode('South Africa', '+27', '🇿🇦'),
  CountryDialCode('Nepal', '+977', '🇳🇵'),
  CountryDialCode('Bangladesh', '+880', '🇧🇩'),
  CountryDialCode('Pakistan', '+92', '🇵🇰'),
  CountryDialCode('Direct (No code)', '', '🌐'),
];

/// Validates whether a phone input strictly follows:
/// 1. Exactly 10 digits (national 10-digit format for any country), OR
/// 2. Country-wise international format (10-15 digits total, E.164 compliant).
///
/// Strictly rejects inputs < 10 digits (such as 7 digits), > 15 digits, or invalid characters.
bool isValidCustomerPhoneNumber(String? value) {
  if (value == null) return false;
  final clean = value.trim();
  if (clean.isEmpty) return false;

  // Only allow digits, optional leading '+', and formatting characters (spaces, hyphens, parentheses)
  if (!RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(clean)) return false;

  final digits = clean.replaceAll(RegExp(r'\D'), '');

  // Must have between 10 and 15 digits (ITU-T E.164 recommendation)
  if (digits.length < 10 || digits.length > 15) return false;

  // Case 1: If starts with '+', country code cannot start with '0'
  if (clean.startsWith('+')) {
    final withoutPlus = clean.substring(1).replaceAll(RegExp(r'\D'), '');
    return withoutPlus.length >= 10 && !withoutPlus.startsWith('0');
  }

  // Case 2: Exactly 10 digits (works for any country's 10-digit numbers, not restricted to India)
  if (digits.length == 10) {
    return true;
  }

  // Case 3: 11-15 digits without '+'
  return !digits.startsWith('0');
}

String buildCustomerPhoneNumber(String rawPhone, String countryCode) {
  final clean = rawPhone.trim();
  if (clean.isEmpty) return '';

  if (clean.startsWith('+')) {
    final digits = clean.substring(1).replaceAll(RegExp(r'\D'), '');
    return '+$digits';
  }

  final digits = clean.replaceAll(RegExp(r'\D'), '');
  if (countryCode.isNotEmpty) {
    final prefixDigits = countryCode.replaceAll(RegExp(r'\D'), '');
    if (prefixDigits.isNotEmpty &&
        digits.startsWith(prefixDigits) &&
        digits.length > 10) {
      return '+$digits';
    }
    return '$countryCode$digits';
  }

  return digits;
}

(String, String) parseCustomerPhone(String storedPhone) {
  final clean = storedPhone.trim();
  if (clean.isEmpty) return ('+91', '');

  if (clean.startsWith('+')) {
    for (final c in kPopularCountries) {
      if (c.code.isNotEmpty && clean.startsWith(c.code)) {
        return (c.code, clean.substring(c.code.length).trim());
      }
    }
    return ('', clean);
  }

  if (clean.length == 10) {
    return ('+91', clean);
  }
  if (clean.length == 12 && clean.startsWith('91')) {
    return ('+91', clean.substring(2));
  }

  return ('', clean);
}

String? _validateCustomerPhone(
  String? value,
  String countryCode, {
  bool required = true,
}) {
  if (value == null || value.trim().isEmpty) {
    return required ? T.t('Required') : null;
  }

  final fullNumber = buildCustomerPhoneNumber(value, countryCode);
  if (!isValidCustomerPhoneNumber(fullNumber)) {
    return T.t('Enter a valid 10-digit number or country format');
  }
  return null;
}


