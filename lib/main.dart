import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:developer' as developer;

import 'controllers/app_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'services/app_language.dart';
import 'services/api_service.dart';
import 'widgets/dairy_milk_loader.dart';
import 'widgets/dashboard_screen.dart';
import 'widgets/monthly_entries_screen.dart';
import 'widgets/send_whatsapp_bill_sheet.dart';
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
        home: Obx(
          () => !appController.ready.value
              ? const _Loading()
              : appController.api.hasSession
              ? Dashboard(api: api)
              : AuthPage(api: api),
        ),
      );
    });
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xfff7faf8),
      body: Center(
        child: DairyMilkLoader(
          size: 54,
          message: 'Starting Dairy Desk...',
          subtitle: 'Pure & Fresh Dairy Management',
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.api});
  final ApiService api;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool signup = false, busy = false;
  bool obscurePassword = true;
  final formKey = GlobalKey<FormState>();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final dairyName = TextEditingController();

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
          () => VerifyEmailPage(api: widget.api, email: email.text.trim()),
        );
        return;
      } else {
        await widget.api.login(email.text.trim(), password.text);
      }
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      LucideIcons.milk,
                      size: 54,
                      color: Color(0xff2d7a55),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Dairy Desk',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      T.t(signup ? 'Set up your dairy' : 'Welcome back'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 34),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: false, label: Text(T.t('Log in'))),
                        ButtonSegment(
                          value: true,
                          label: Text(T.t('Create account')),
                        ),
                      ],
                      selected: {signup},
                      onSelectionChanged: busy
                          ? null
                          : (selection) =>
                                setState(() => signup = selection.first),
                    ),
                    const SizedBox(height: 22),
                    if (signup) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: firstName,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: T.t('First name'),
                              ),
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: lastName,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: T.t('Last name'),
                              ),
                              validator: _required,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: dairyName,
                        decoration: InputDecoration(
                          labelText: T.t('Dairy name'),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: email,
                      keyboardType: signup
                          ? TextInputType.emailAddress
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: signup
                            ? T.t('Email address')
                            : T.t('Email address or mobile number'),
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
                        // Login mode accepts email or mobile number
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
                    TextFormField(
                      controller: password,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: T.t('Password'),
                        helperText: signup
                            ? T.t(
                                'Minimum 6 characters, 1 number, 1 special character',
                              )
                            : null,
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? T.t('Show password')
                              : T.t('Hide password'),
                          icon: Icon(
                            obscurePassword
                                ? LucideIcons.eye
                                : LucideIcons.eyeOff,
                          ),
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          signup ? _strongPasswordError(v) : _required(v),
                    ),
                    if (!signup)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () => Get.to(
                                  () => ForgotPasswordPage(api: widget.api),
                                ),
                          child: Text(T.t('Forgot password?')),
                        ),
                      ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: busy
                            ? DairyMilkLoader.mini(color: Colors.white, size: 22)
                            : Text(T.t(signup ? 'Create account' : 'Log in')),
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

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? T.t('Required') : null;
}

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.api, required this.email});
  final ApiService api;
  final String email;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final code = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (code.text.trim().length != 6) return;
    setState(() => busy = true);
    try {
      await widget.api.verifyEmail(widget.email, code.text.trim());
      if (mounted) Get.offAll(() => Dashboard(api: widget.api));
    } catch (error) {
      if (mounted) _showAuthMessage(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    setState(() => busy = true);
    try {
      await widget.api.resendVerification(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(T.t('Verification code sent'))));
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
    onSubmit: verify,
    onResend: resend,
  );
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.api});
  final ApiService api;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.api.requestPasswordReset(email.text.trim());
      if (!mounted) return;
      await Get.to(
        () => ResetPasswordPage(api: widget.api, email: email.text.trim()),
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
            T.t('Enter your email and we will send you a reset code.'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: T.t('Email address')),
            validator: (value) => value != null && _isValidEmail(value)
                ? null
                : T.t('Enter a valid email'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : submit,
            child: busy
                ? DairyMilkLoader.mini(color: Colors.white, size: 22)
                : Text(T.t('Send reset code')),
          ),
        ],
      ),
    ),
  );
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.api, required this.email});
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

  @override
  void dispose() {
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
        Get.offAll(() => AuthPage(api: widget.api));
        Get.snackbar(T.t('Success'), T.t('Password reset successfully'));
      }
    } catch (error) {
      if (mounted) _showAuthMessage(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    setState(() => busy = true);
    try {
      await widget.api.requestPasswordReset(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(T.t('Reset code sent'))));
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
          TextFormField(
            controller: code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(labelText: T.t('6-digit reset code')),
            validator: (value) => value?.trim().length == 6
                ? null
                : T.t('Enter the 6-digit reset code'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: T.t('New password'),
              helperText: T.t(
                'Minimum 6 characters, 1 number, 1 special character',
              ),
            ),
            validator: _strongPasswordError,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: confirmation,
            obscureText: true,
            decoration: InputDecoration(labelText: T.t('Confirm new password')),
            validator: (value) =>
                value == password.text ? null : T.t('Passwords do not match'),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: busy ? null : resend,
            child: Text(T.t('Resend code')),
          ),
          const SizedBox(height: 8),
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
  });
  final String title;
  final String description;
  final TextEditingController controller;
  final String buttonText;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: _pagePadding(context),
      children: [
        Text(description),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(labelText: T.t('6-digit code')),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: Text(buttonText),
        ),
        TextButton(
          onPressed: busy ? null : onResend,
          child: Text(T.t('Resend code')),
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
    controller = Get.put(DashboardController(widget.api));
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
                  'Hello, ${controller.ownerName.value}',
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
                    const Center(
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
        floatingActionButton: FloatingActionButton(
          tooltip: T.t('Add customer'),
          onPressed: controller.loading.value
              ? null
              : () => _openAddCustomer(context, controller),
          child: const Icon(Icons.person_add_alt_1),
        ),
      );
    });
  }
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
    final liters = TextEditingController(text: '${customer['liters'] ?? 0}');
    final price = TextEditingController(text: '${customer['price'] ?? 0}');
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
      await api.addMilkEntry(
        customerId,
        date: DateTime.now(),
        liters: litersValue,
        price: priceValue,
      );
      developer.log('Entry API call succeeded', name: 'MilkEntry');
      if (!context.mounted) return;
      await onChanged();
      developer.log(
        'Customer list refreshed after entry save',
        name: 'MilkEntry',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(T.t('Milk entry saved'))));
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
    final liters = (customer['liters'] ?? customer['defaultLiters'] ?? 0);
    final price = (customer['price'] ?? customer['defaultPrice'] ?? 0);
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar with sequential number & optional WhatsApp badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffdcefe3), Color(0xffc2e7cf)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        number.isNotEmpty ? number : '#',
                        style: const TextStyle(
                          fontSize: 16,
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
                const SizedBox(width: 12),

                // Customer info & metrics
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
                      const SizedBox(height: 5),

                      // Metrics row: Liters pill & Rate pill
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffdcefe3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.droplets,
                                  size: 11,
                                  color: Color(0xff2d7a55),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$liters L',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff2d7a55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
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
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff166534),
                              ),
                            ),
                          ),
                          if (phone.isNotEmpty && phone != 'null')
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Save Milk Entry Button
                Tooltip(
                  message: T.t('Save entry'),
                  child: Material(
                    color: const Color(0xff2d7a55),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _addMilk(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.circlePlus,
                              size: 15,
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
                const SizedBox(width: 2),

                // Three-dot popup menu
                PopupMenuButton<String>(
                  tooltip: T.t('More options'),
                  icon: Icon(
                    LucideIcons.moreVertical,
                    size: 19,
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
                                      hasPhone ? phone : T.t('Not provided'),
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
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: const Color(0xff2d7a55)),
    title: Text(label),
    subtitle: Text(value),
  );
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
          hasSearch ? Icons.search_off : Icons.people_outline,
          size: 54,
          color: Colors.grey,
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
        title: Text(T.t('Log out?')),
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
    Get.delete<DashboardController>();
    Get.offAll(() => AuthPage(api: widget.api));
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
                subtitle: 'support@dairydesk.app',
                onTap: () => _openSupportEmail(context),
              ),
              const Divider(height: 1, indent: 54, endIndent: 14, color: Color(0xfff1f5f9)),
              _SettingsListTile(
                icon: LucideIcons.messageSquareText,
                iconBg: const Color(0xfff3e8ff),
                iconColor: const Color(0xff9333ea),
                title: T.t('Send feedback'),
                subtitle: T.t('Help us improve Dairy Desk'),
                onTap: () => _showFeedbackDialog(context),
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

        // App Footer & Version Info
        Center(
          child: Column(
            children: [
              Text(
                'Dairy Desk • v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(T.t('Profile')),
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
        return ListView(
          padding: _pagePadding(context),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff2d7a55), Color(0xff55a776)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white,
                          child: Text(
                            _profileInitial(profile),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff2d7a55),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${profile['name'] ?? profile['email'] ?? 'Dairy owner'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email.isEmpty ? '—' : email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xffe1f1e8),
                        child: Icon(
                          LucideIcons.store,
                          color: Color(0xff2d7a55),
                        ),
                      ),
                      title: Text(T.t('Dairy name')),
                      subtitle: Text('${profile['dairyName'] ?? '—'}'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSectionTitle(title: T.t('Account information')),
            Card(
              child: Column(
                children: [
                  _DetailRow(
                    icon: LucideIcons.circleUser,
                    label: T.t('Name'),
                    value: '${profile['name'] ?? '—'}',
                  ),
                  _DetailRow(
                    icon: LucideIcons.mail,
                    label: T.t('Email address'),
                    value: email.isEmpty ? '—' : email,
                  ),
                  if (phone.isNotEmpty)
                    _DetailRow(
                      icon: LucideIcons.phone,
                      label: T.t('Phone number'),
                      value: phone,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

String _profileInitial(Map<String, dynamic> profile) {
  final value = '${profile['name'] ?? profile['email'] ?? ''}'.trim();
  return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
}

Future<void> _openSupportEmail(BuildContext context) async {
  final uri = Uri(
    scheme: 'mailto',
    path: 'support@dairydesk.app',
    queryParameters: {'subject': 'Dairy Desk support request'},
  );
  if (await launchUrl(uri)) return;
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(T.t('No email app is available'))));
  }
}

Future<void> _showFeedbackDialog(BuildContext context) async {
  final feedback = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(T.t('Send feedback')),
      content: TextField(
        controller: feedback,
        maxLines: 5,
        autofocus: true,
        decoration: InputDecoration(
          hintText: T.t('Tell us what we can improve'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(T.t('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(T.t('Continue')),
        ),
      ],
    ),
  );
  final message = feedback.text.trim();
  feedback.dispose();
  if (submitted != true || message.isEmpty || !context.mounted) return;
  final uri = Uri(
    scheme: 'mailto',
    path: 'feedback@dairydesk.app',
    queryParameters: {'subject': 'Dairy Desk feedback', 'body': message},
  );
  if (await launchUrl(uri)) return;
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(T.t('No email app is available'))));
  }
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
          const SizedBox(height: 14),
          _ChoiceSelector<String>(
            label: T.t('Send daily message using'),
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


