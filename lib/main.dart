import 'package:flutter/material.dart';

import 'services/api_service.dart';

void main() => runApp(const DairyApp());

class DairyApp extends StatefulWidget {
  const DairyApp({super.key});
  @override
  State<DairyApp> createState() => _DairyAppState();
}

class _DairyAppState extends State<DairyApp> {
  final api = ApiService();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    api.loadSession().then((_) {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: !ready
          ? const _Loading()
          : api.hasSession
          ? Dashboard(api: api)
          : AuthPage(api: api),
    );
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
      if (mounted)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => Dashboard(api: widget.api)),
        );
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

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
                      signup ? 'Set up your dairy' : 'Welcome back',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 34),
                    if (signup) ...[
                      TextFormField(
                        controller: dairyName,
                        decoration: const InputDecoration(
                          labelText: 'Dairy name',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => v != null && v.contains('@')
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v != null && v.length >= 6
                          ? null
                          : 'Use at least 6 characters',
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
                            : Text(signup ? 'Create account' : 'Log in'),
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => signup = !signup),
                      child: Text(
                        signup
                            ? 'Already have an account? Log in'
                            : 'New to Dairy Desk? Create an account',
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
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.api});
  final ApiService api;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final search = TextEditingController();
  List<Map<String, dynamic>> customers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    try {
      customers = await widget.api.getCustomers();
    } catch (_) {
      customers = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.toLowerCase();
    final visible = customers.where((c) {
      final name = '${c['name'] ?? c['fullName'] ?? ''}'.toLowerCase();
      final number =
          '${c['uniqueNumber'] ?? c['customerNumber'] ?? c['number'] ?? ''}'
              .toLowerCase();
      return name.contains(query) || number.contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () async {
              await widget.api.logout();
              if (context.mounted)
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => AuthPage(api: widget.api)),
                  (_) => false,
                );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadCustomers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          children: [
            Text(
              'Your dairy at a glance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search by name or unique number',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 22),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (visible.isEmpty)
              _EmptyState(hasSearch: query.isNotEmpty)
            else
              ...visible.map((customer) => _CustomerTile(customer: customer)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreateCustomerPage(api: widget.api),
            ),
          );
          if (added == true) loadCustomers();
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add customer'),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});
  final Map<String, dynamic> customer;
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
        subtitle: Text('Unique number  •  $number'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
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
          hasSearch ? 'No customers found' : 'No customers yet',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          hasSearch
              ? 'Try another name or number'
              : 'Add your first customer to get started',
        ),
      ],
    ),
  );
}

class CreateCustomerPage extends StatefulWidget {
  const CreateCustomerPage({super.key, required this.api});
  final ApiService api;
  @override
  State<CreateCustomerPage> createState() => _CreateCustomerPageState();
}

class _CreateCustomerPageState extends State<CreateCustomerPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(),
      uniqueNumber = TextEditingController(),
      liters = TextEditingController(),
      price = TextEditingController();
  bool busy = false;
  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.api.createCustomer({
        'name': name.text.trim(),
        'uniqueNumber': uniqueNumber.text.trim(),
        'liters': double.parse(liters.text.trim()),
        'price': double.parse(price.text.trim()),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add customer')),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Customer details',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text('Keep your collection records organized.'),
          const SizedBox(height: 24),
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: _required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: uniqueNumber,
            decoration: const InputDecoration(
              labelText: 'Unique customer number',
              prefixIcon: Icon(Icons.tag),
            ),
            validator: _required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: liters,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Liters'),
            validator: _number,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Price'),
            validator: _number,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: busy ? null : save,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: busy
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Text('Save customer'),
            ),
          ),
        ],
      ),
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

String? _number(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return double.tryParse(value.trim()) == null ? 'Enter a valid number' : null;
}
