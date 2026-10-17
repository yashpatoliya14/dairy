import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'dart:developer' as developer;

import 'controllers/app_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'services/app_language.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  final email = TextEditingController();
  final password = TextEditingController();
  final dairyName = TextEditingController();

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (signup) {
        await widget.api.signup(
          email.text.trim(),
          password.text,
          dairyName.text.trim(),
        );
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
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.local_drink_rounded,
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
                    if (signup) ...[
                      TextFormField(
                        controller: dairyName,
                        decoration: InputDecoration(
                          labelText: T.t('Dairy name'),
                          prefixIcon: Icon(Icons.storefront_outlined),
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
                        prefixIcon: Icon(Icons.email_outlined),
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
                        prefixIcon: Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? T.t('Show password')
                              : T.t('Hide password'),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) => v != null && v.length >= 8
                          ? null
                          : T.t('Use at least 8 characters'),
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
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => signup = !signup),
                      child: Text(
                        signup
                            ? T.t('Already have an account? Log in')
                            : T.t('New to Dairy Desk? Create an account'),
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
          leading: IconButton(
            tooltip: T.t('Settings'),
            icon: const Icon(Icons.settings_outlined),
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
          ),
          title: Text(T.t('Customers')),
          actions: [
            IconButton(
              tooltip: T.t('Refresh customers'),
              onPressed: controller.loading.value ? null : controller.load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: T.t('Log out'),
              onPressed: () async {
                await api.logout();
                Get.delete<DashboardController>();
                Get.offAll(() => AuthPage(api: api));
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
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
                  prefixIcon: Icon(Icons.search),
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
        floatingActionButton: FloatingActionButton.extended(
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
          icon: const Icon(Icons.person_add_alt_1),
          label: Text(T.t('Add customer')),
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
              tooltip: 'Add liters',
              onPressed: () => _addMilk(context),
              icon: const Icon(Icons.local_drink_outlined),
            ),
            IconButton(
              tooltip: 'Edit customer',
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
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
  late Future<List<Map<String, dynamic>>> entries;

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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                return Column(
                  children: history
                      .map((entry) => _MilkEntryTile(entry: entry))
                      .toList(),
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
          child: Icon(Icons.local_drink_outlined, color: Color(0xff2d7a55)),
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
          icon: const Icon(Icons.refresh),
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
  final formKey = GlobalKey<FormState>();
  late final TextEditingController liters;
  late final TextEditingController price;
  bool busy = false;
  late String language;

  @override
  void dispose() {
    liters.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    liters = TextEditingController(text: _formatNumber(widget.defaultLiters));
    price = TextEditingController(text: _formatNumber(widget.defaultPrice));
    language = Get.find<AppLanguageController>().language.value;
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
    appBar: AppBar(title: Text(T.t('Settings'))),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            T.t('Customer defaults'),
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
              prefixIcon: Icon(Icons.local_drink_outlined),
            ),
            validator: _number,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: T.t('Default price per liter'),
              prefixIcon: Icon(Icons.payments_outlined),
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
          const SizedBox(height: 32),
          Text(
            T.t('App language'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: language,
            decoration: InputDecoration(labelText: T.t('Language')),
            items: [
              DropdownMenuItem(value: 'en', child: Text(T.t('English'))),
              DropdownMenuItem(value: 'hi', child: Text(T.t('Hindi'))),
              DropdownMenuItem(value: 'gu', child: Text(T.t('Gujarati'))),
            ],
            onChanged: busy
                ? null
                : (value) async {
                    if (value == null) return;
                    setState(() => language = value);
                    await Get.find<AppLanguageController>().setLanguage(value);
                  },
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
          DropdownButtonFormField<String>(
            initialValue: channel,
            decoration: InputDecoration(
              labelText: T.t('Send daily message using'),
            ),
            items: [
              DropdownMenuItem(value: 'whatsapp', child: Text(T.t('WhatsApp'))),
              DropdownMenuItem(
                value: 'sms',
                child: Text(T.t('SMS / Messages')),
              ),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() => channel = value!),
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
          DropdownButtonFormField<String>(
            initialValue: channel,
            decoration: InputDecoration(labelText: T.t('Message channel')),
            items: [
              DropdownMenuItem(value: 'whatsapp', child: Text(T.t('WhatsApp'))),
              DropdownMenuItem(
                value: 'sms',
                child: Text(T.t('SMS / Messages')),
              ),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() => channel = value!),
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
