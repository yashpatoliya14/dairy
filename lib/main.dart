import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:developer' as developer;

import 'controllers/app_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'services/app_language.dart';
import 'services/api_service.dart';
import 'widgets/send_whatsapp_bill_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const DairyApp());
}

class DairyApp extends StatelessWidget {
  const DairyApp({super.key});

  static final api = ApiService();

  @override
  Widget build(BuildContext context) {
    final appController = Get.put(AppController(api), permanent: true);
    final languageController = Get.put(
      AppLanguageController(),
      permanent: true,
    );
    return Obx(() {
      languageController.language.value;
      return GetMaterialApp(
        title: 'Dairy Desk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2d7a55)),
          scaffoldBackgroundColor: const Color(0xfff7faf8),
          textTheme: GoogleFonts.dmSansTextTheme().copyWith(
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
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              side: BorderSide(color: Color(0xffe3ebe6)),
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

class _Loading extends StatefulWidget {
  const _Loading();

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: Tween<double>(begin: .72, end: 1).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOut,
            ),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: .94, end: 1).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeInOut,
              ),
            ),
            child: SvgPicture.asset(
              'assets/dairy_management_icon.svg',
              width: 132,
              height: 132,
              semanticsLabel: 'Dairy Management',
            ),
          ),
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
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: T.t('Email address'),
                      ),
                      validator: (v) => v != null && v.contains('@')
                          ? null
                          : T.t('Enter a valid email'),
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
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
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
            validator: (value) => value != null && value.contains('@')
                ? null
                : T.t('Enter a valid email'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : submit,
            child: busy
                ? const CircularProgressIndicator(strokeWidth: 2)
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
                ? const CircularProgressIndicator(strokeWidth: 2)
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

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.api});
  final ApiService api;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardController(api));
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
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Obx(
            () => Column(
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
                  ),
                ),
                if (controller.ownerName.value.isNotEmpty)
                  Text(
                    'Hello, ${controller.ownerName.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: T.t('Refresh customers'),
              onPressed: controller.loading.value ? null : controller.load,
              icon: const Icon(LucideIcons.refreshCw),
            ),
            IconButton(
              tooltip: T.t('Settings'),
              onPressed: () async {
                final updated = await Get.to<bool>(
                  () => SettingsPage(
                    api: api,
                    defaultLiters: controller.defaultLiters.value,
                    defaultPrice: controller.defaultPrice.value,
                  ),
                );
                if (updated == true) await controller.loadSettings();
              },
              icon: const Icon(LucideIcons.settings),
            ),
          ],
        ),
        body: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 230,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.5,
                  child: Image(
                    image: AssetImage('assets/india_dairy_background.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  _pagePadding(context).horizontal / 2,
                  10,
                  _pagePadding(context).horizontal / 2,
                  250,
                ),
                children: [
                  Text(
                    T.t('Your dairy at a glance'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: controller.setSearch,
                    decoration: InputDecoration(
                      hintText: T.t('Search by name or customer number'),
                      prefixIcon: Icon(LucideIcons.search),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (controller.loading.value && controller.customers.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
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
                        api: api,
                        onChanged: controller.loadCustomers,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: T.t('Add customer'),
          onPressed: controller.loading.value
              ? null
              : () async {
                  await controller.loadSettings();
                  final added = await Get.to<bool>(
                    () => CreateCustomerPage(
                      api: api,
                      defaultLiters: controller.defaultLiters.value,
                      defaultPrice: controller.defaultPrice.value,
                    ),
                  );
                  if (added == true) await controller.loadCustomers();
                },
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

  Future<void> _addMilk(BuildContext context) async {
    final liters = TextEditingController(text: '${customer['liters'] ?? 0}');
    final price = TextEditingController(text: '${customer['price'] ?? 0}');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${T.t('Add today’s milk')} - ${customer['name']}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: liters,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: T.t('Liters')),
                validator: _number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: T.t('Price per liter')),
                validator: _number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text(T.t('Cancel'))),
          FilledButton(
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
              Get.back(result: {'liters': litersValue, 'price': priceValue});
            },
            child: Text(T.t('Save entry')),
          ),
        ],
      ),
    );
    liters.dispose();
    price.dispose();
    if (result == null || !context.mounted) {
      developer.log('Entry dialog closed without saving', name: 'MilkEntry');
      return;
    }
    final customerId = '${customer['id']}'.trim();
    final litersValue = result['liters'];
    final priceValue = result['price'];
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
        liters: litersValue as double,
        price: priceValue as double,
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

  Future<void> _openDetails() async {
    final updated = await Get.to<bool>(
      () => CustomerDetailsPage(api: api, customer: customer),
    );
    if (updated == true) await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${customer['name'] ?? customer['fullName'] ?? 'Unnamed customer'}';
    final number =
        '${customer['uniqueNumber'] ?? customer['customerNumber'] ?? customer['number'] ?? '—'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xffdcefe3),
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: _openDetails,
        subtitle: Text(
          'No. $number  •  ${customer['liters']} L  •  '
          '${customer['notificationChannel'] ?? 'whatsapp'}',
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: T.t('Send WhatsApp Bill'),
              onPressed: () => SendWhatsAppBillSheet.show(
                context,
                api: api,
                customer: customer,
              ),
              icon: const Icon(
                LucideIcons.messageCircle,
                color: Color(0xff25D366),
              ),
            ),
            IconButton(
              tooltip: T.t('Save entry'),
              onPressed: () => _addMilk(context),
              icon: const Icon(Icons.save_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: T.t('More options'),
              onSelected: (value) {
                if (value == 'whatsapp') {
                  SendWhatsAppBillSheet.show(
                    context,
                    api: api,
                    customer: customer,
                  );
                }
                if (value == 'edit') _edit(context);
                if (value == 'details') _openDetails();
                if (value == 'bill') _showBill(context);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'whatsapp',
                  child: ListTile(
                    leading: const Icon(
                      LucideIcons.messageCircle,
                      color: Color(0xff25D366),
                    ),
                    title: Text(T.t('Send WhatsApp Bill')),
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(T.t('Edit customer')),
                  ),
                ),
                PopupMenuItem(
                  value: 'details',
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(T.t('View customer details')),
                  ),
                ),
                PopupMenuItem(
                  value: 'bill',
                  child: ListTile(
                    leading: const Icon(LucideIcons.receiptText),
                    title: Text(T.t('View bill')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBill(BuildContext context) async {
    late final List<Map<String, dynamic>> entries;
    try {
      entries = await api.getMilkEntries('${customer['id']}');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (!context.mounted) return;
    final total = entries.fold<double>(
      0,
      (sum, entry) =>
          sum +
          _asDouble(
            entry['total'],
            fallback: _asDouble(entry['liters']) * _asDouble(entry['price']),
          ),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${T.t('Bill')} - ${customer['name']}'),
        content: Text(
          '${T.t('Total entries')}: ${entries.length}\n'
          '${T.t('Total amount')}: ${total.toStringAsFixed(2)}',
        ),
        actions: [TextButton(onPressed: Get.back, child: Text(T.t('Close')))],
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
  late Future<List<Map<String, dynamic>>> entries;
  String selectedMonth = 'all';

  @override
  void initState() {
    super.initState();
    entries = widget.api.getMilkEntries('${widget.customer['id']}');
  }

  void reload() {
    setState(() {
      entries = widget.api.getMilkEntries('${widget.customer['id']}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final name = '${customer['name'] ?? customer['fullName'] ?? 'Customer'}';
    final number =
        '${customer['uniqueNumber'] ?? customer['customerNumber'] ?? '—'}';
    final liters = _asDouble(customer['liters']);
    final price = _asDouble(customer['price']);
    final phone = '${customer['phoneNumber'] ?? 'Not provided'}';
    final channel = '${customer['notificationChannel'] ?? 'whatsapp'}';

    return Scaffold(
      appBar: AppBar(
        title: Text(T.t('Customer details')),
        actions: [
          IconButton(
            tooltip: T.t('Send WhatsApp Bill'),
            onPressed: () => SendWhatsAppBillSheet.show(
              context,
              api: widget.api,
              customer: widget.customer,
            ),
            icon: const Icon(
              LucideIcons.messageCircle,
              color: Color(0xff25D366),
            ),
          ),
          IconButton(
            tooltip: T.t('Edit customer'),
            onPressed: () async {
              final updated = await Get.to<bool>(
                () => EditCustomerPage(api: widget.api, customer: customer),
              );
              if (updated == true && mounted) {
                Get.back(result: true);
              }
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            _pagePadding(context).horizontal / 2,
            8,
            _pagePadding(context).horizontal / 2,
            32,
          ),
          children: [
            Card(
              child: Padding(
                padding: _pagePadding(context),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xffdcefe3),
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff2d7a55),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('${T.t('Customer no.')} $number'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DetailsSection(
              title: T.t('Contact'),
              children: [
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: T.t('Phone number'),
                  value: phone,
                ),
                _DetailRow(
                  icon: channel == 'sms'
                      ? Icons.sms_outlined
                      : Icons.chat_outlined,
                  label: T.t('Notification channel'),
                  value: channel == 'sms'
                      ? T.t('SMS / Messages')
                      : T.t('WhatsApp'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailsSection(
              title: T.t('Milk defaults'),
              children: [
                _DetailRow(
                  icon: Icons.local_drink_outlined,
                  label: T.t('Daily liters'),
                  value: '${liters.toStringAsFixed(2)} L',
                ),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: T.t('Price per liter'),
                  value: price.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              color: const Color(0xfff0fdf4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xffbbf7d0)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.messageCircle, color: Colors.white, size: 20),
                ),
                title: Text(
                  T.t('Send WhatsApp Bill'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff166534)),
                ),
                subtitle: Text(
                  T.t('Send daily milk delivery update or monthly statement'),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xff166534)),
                onTap: () => SendWhatsAppBillSheet.show(
                  context,
                  api: widget.api,
                  customer: widget.customer,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              T.t('Recent milk entries'),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: entries,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _EntryMessage(
                    icon: Icons.cloud_off_outlined,
                    message: T.t('Could not load milk history.'),
                    action: TextButton(
                      onPressed: reload,
                      child: Text(T.t('Try again')),
                    ),
                  );
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return _EntryMessage(
                    icon: Icons.receipt_long_outlined,
                    message: T.t('No milk entries yet.'),
                  );
                }
                final months =
                    history
                        .map((entry) => '${entry['entryDate'] ?? ''}')
                        .where((date) => date.length >= 7)
                        .map((date) => date.substring(0, 7))
                        .toSet()
                        .toList()
                      ..sort((a, b) => b.compareTo(a));
                final filtered = selectedMonth == 'all'
                    ? history
                    : history
                          .where(
                            (entry) => '${entry['entryDate'] ?? ''}'.startsWith(
                              selectedMonth,
                            ),
                          )
                          .toList();
                final total = filtered.fold<double>(
                  0,
                  (sum, entry) =>
                      sum +
                      _asDouble(
                        entry['total'],
                        fallback:
                            _asDouble(entry['liters']) *
                            _asDouble(entry['price']),
                      ),
                );
                return Column(
                  children: [
                    _ChoiceSelector<String>(
                      label: T.t('Filter by month'),
                      value: selectedMonth,
                      options: {
                        'all': T.t('All months'),
                        for (final month in months) month: month,
                      },
                      onChanged: (value) =>
                          setState(() => selectedMonth = value),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(T.t('Bill total')),
                        subtitle: Text('${filtered.length} ${T.t('entries')}'),
                        trailing: Text(
                          total.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...filtered.map((entry) => _MilkEntryTile(entry: entry)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    ),
  );
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

class _MilkEntryTile extends StatelessWidget {
  const _MilkEntryTile({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final liters = _asDouble(entry['liters']);
    final price = _asDouble(entry['price']);
    final total = _asDouble(entry['total'], fallback: liters * price);
    final date = '${entry['entryDate'] ?? 'Unknown date'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xffdcefe3),
          child: Icon(LucideIcons.milk, color: Color(0xff2d7a55)),
        ),
        title: Text(date),
        subtitle: Text(
          '${liters.toStringAsFixed(2)} L × ${price.toStringAsFixed(2)}',
        ),
        trailing: Text(
          total.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _EntryMessage extends StatelessWidget {
  const _EntryMessage({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          ?action,
        ],
      ),
    ),
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
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    language = Get.find<AppLanguageController>().language.value;
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => notificationsEnabled =
            preferences.getBool('notifications_enabled') ?? true,
      );
    }
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => notificationsEnabled = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('notifications_enabled', value);
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
    appBar: AppBar(title: Text(T.t('Settings'))),
    body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsSectionTitle(title: T.t('Dairy')),
          _SettingsAction(
            icon: LucideIcons.glassWater,
            title: T.t('Default milk & price'),
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
          const SizedBox(height: 32),
          Text(
            T.t('App language'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _ChoiceSelector<String>(
            label: T.t('Language'),
            value: language,
            options: {
              'en': T.t('English'),
              'hi': T.t('Hindi'),
              'gu': T.t('Gujarati'),
            },
            enabled: true,
            onChanged: (value) async {
              setState(() => language = value);
              await Get.find<AppLanguageController>().setLanguage(value);
            },
          ),
          const SizedBox(height: 28),
          _SettingsSectionTitle(title: T.t('Preferences')),
          Card(
            child: SwitchListTile.adaptive(
              secondary: const Icon(LucideIcons.bell),
              title: Text(T.t('Notifications')),
              subtitle: Text(
                notificationsEnabled
                    ? T.t('Daily reminders are enabled')
                    : T.t('Daily reminders are disabled'),
              ),
              value: notificationsEnabled,
              onChanged: _setNotifications,
            ),
          ),
          const SizedBox(height: 20),
          _SettingsSectionTitle(title: T.t('Account')),
          _SettingsAction(
            icon: LucideIcons.circleUser,
            title: T.t('View profile'),
            onTap: () => Get.to(() => ProfilePage(api: widget.api)),
          ),
          _SettingsAction(
            icon: LucideIcons.keyRound,
            title: T.t('Change password'),
            onTap: () => Get.to(() => ChangePasswordPage(api: widget.api)),
          ),
          const SizedBox(height: 20),
          _SettingsSectionTitle(title: T.t('Help & feedback')),
          _SettingsAction(
            icon: LucideIcons.headphones,
            title: T.t('Contact support'),
            onTap: () => _openSupportEmail(context),
          ),
          _SettingsAction(
            icon: LucideIcons.messageSquareText,
            title: T.t('Send feedback'),
            onTap: () => _showFeedbackDialog(context),
          ),
          const SizedBox(height: 20),
          _SettingsAction(
            icon: LucideIcons.logOut,
            title: T.t('Log out'),
            onTap: _confirmLogout,
          ),
        ],
      ),
  );
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
    appBar: AppBar(title: Text(T.t('Default milk & price'))),
    body: Form(
      key: formKey,
      child: ListView(
        padding: _pagePadding(context),
        children: [
          Text(
            T.t('Default milk & price'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            T.t(
              'These values are filled automatically when you add a customer. '
              'You can change them for any individual customer.',
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: liters,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: T.t('Default liters'),
              prefixIcon: const Icon(Icons.local_drink_outlined),
            ),
            validator: _number,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: T.t('Default price per liter'),
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
            validator: _number,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: busy ? null : save,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: busy
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Text(T.t('Save defaults')),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: const Color(0xff2d7a55)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
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

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.api});
  final ApiService api;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(T.t('Profile'))),
    body: FutureBuilder<Map<String, dynamic>>(
      future: api.getProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final profile = snapshot.data ?? {};
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
                          '${profile['email'] ?? '—'}',
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
                    value: '${profile['email'] ?? '—'}',
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
    appBar: AppBar(title: Text(T.t('Change password'))),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: current,
            obscureText: true,
            decoration: InputDecoration(labelText: T.t('Current password')),
            validator: (value) =>
                value == null || value.isEmpty ? T.t('Required') : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: next,
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
            controller: confirm,
            obscureText: true,
            decoration: InputDecoration(labelText: T.t('Confirm new password')),
            validator: (value) =>
                value == next.text ? null : T.t('Passwords do not match'),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(T.t('Change password')),
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
      await widget.api.createCustomer({
        'name': name.text.trim(),
        'liters': double.parse(liters.text.trim()),
        'price': double.parse(price.text.trim()),
        'phoneNumber': phone.text.trim(),
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
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: _phone,
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
                  ? const CircularProgressIndicator(strokeWidth: 2)
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
  late String channel;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: '${widget.customer['name'] ?? ''}');
    liters = TextEditingController(text: '${widget.customer['liters'] ?? 0}');
    price = TextEditingController(text: '${widget.customer['price'] ?? 0}');
    phone = TextEditingController(
      text: '${widget.customer['phoneNumber'] ?? ''}',
    );
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
      if (phoneValue.isNotEmpty) changes['phoneNumber'] = phoneValue;
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
            decoration: InputDecoration(labelText: T.t('Phone number')),
            validator: _optionalPhone,
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
                ? const CircularProgressIndicator(strokeWidth: 2)
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
  final horizontal = width >= 600 ? 32.0 : 20.0;
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: 20);
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

String? _phone(String? value) {
  if (value == null || value.trim().isEmpty) return T.t('Required');
  return _optionalPhone(value);
}

String? _optionalPhone(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return RegExp(r'^[0-9+()\-\s]{7,20}$').hasMatch(value.trim())
      ? null
      : 'Enter a valid phone number';
}
