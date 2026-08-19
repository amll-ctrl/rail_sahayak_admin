import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RailSahayakAdminApp());
}

class RailSahayakAdminApp extends StatelessWidget {
  const RailSahayakAdminApp({super.key});

  static const adminRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RailSahayak Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: adminRed),
        scaffoldBackgroundColor: const Color(0xFFFFF8F8),
      ),
      home: const AdminGate(),
    );
  }
}

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) return const AdminLoginScreen();
        return AdminAuthorizationGate(user: snapshot.data!);
      },
    );
  }
}

class AdminAuthorizationGate extends StatelessWidget {
  final User user;
  const AdminAuthorizationGate({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('admin').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data?.data();
        final role = data?['role']?.toString().trim().toLowerCase();
        final approved = data?['approved'] == true ||
            data?['approved']?.toString().trim().toLowerCase() == 'true';
        if (snapshot.hasData && data != null && role == 'admin' && approved) {
          return const AdminDashboard();
        }
        FirebaseAuth.instance.signOut();
        return const AdminLoginScreen();
      },
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );
      final uid = credential.user?.uid;
      if (uid == null) throw Exception('No Firebase user returned.');
      final adminDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .get();
      final data = adminDoc.data();
      final role = data?['role']?.toString().trim().toLowerCase();
      final approved = data?['approved'] == true ||
          data?['approved']?.toString().trim().toLowerCase() == 'true';
      if (!adminDoc.exists || role != 'admin' || !approved) {
        await FirebaseAuth.instance.signOut();
        throw Exception('This account is not an approved RailSahayak administrator.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authMessage(e)), backgroundColor: Colors.red.shade700),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The administrator email or password is incorrect.';
      case 'invalid-email':
        return 'Enter a valid administrator email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return e.message ?? 'Administrator login failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    const red = RailSahayakAdminApp.adminRed;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 8,
                shadowColor: red.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: red,
                          child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 42),
                        ),
                        const SizedBox(height: 20),
                        const Text('RailSahayak Admin', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Approved administrators only', style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 30),
                        TextFormField(
                          controller: _emailController,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Administrator Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                              return 'Enter a valid administrator email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_loading,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _login,
                            icon: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login),
                            label: Text(_loading ? 'Signing in...' : 'Administrator Login', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  static const red = RailSahayakAdminApp.adminRed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('requests').snapshots(),
        builder: (context, requestSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              if (requestSnapshot.hasError || userSnapshot.hasError) {
                return const Center(child: Text('Unable to load dashboard data. Check Firestore permissions.'));
              }
              if (!requestSnapshot.hasData || !userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = requestSnapshot.data!.docs;
              final users = userSnapshot.data!.docs;
              var staff = 0;
              var requested = 0;
              var active = 0;
              var completed = 0;
              for (final user in users) {
                final role = user.data()['role']?.toString().toLowerCase();
                if (role == 'staff') staff++;
              }
              for (final request in requests) {
                final status = request.data()['status']?.toString().trim().toLowerCase() ?? '';
                if (status == 'requested' || status == 'pending') {
                  requested++;
                } else if (status == 'assigned' || status == 'assisting' || status == 'accepted' || status == 'in_progress' || status == 'in progress') {
                  active++;
                } else if (status == 'completed') {
                  completed++;
                }
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overview', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Live RailSahayak system statistics', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.2,
                      children: [
                        _StatCard(icon: Icons.people_rounded, title: 'Total Users', value: users.length.toString(), color: Colors.blue),
                        _StatCard(icon: Icons.badge_rounded, title: 'Staff', value: staff.toString(), color: Colors.deepPurple),
                        _StatCard(icon: Icons.hourglass_top_rounded, title: 'Requested', value: requested.toString(), color: Colors.orange),
                        _StatCard(icon: Icons.directions_run_rounded, title: 'Active', value: active.toString(), color: Colors.blue),
                        _StatCard(icon: Icons.check_circle_rounded, title: 'Completed', value: completed.toString(), color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text('Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: const [
                        _AdminCard(icon: Icons.people_alt_rounded, title: 'Staff'),
                        _AdminCard(icon: Icons.assistant_rounded, title: 'Requests'),
                        _AdminCard(icon: Icons.person_rounded, title: 'Users'),
                        _AdminCard(icon: Icons.settings_rounded, title: 'Settings'),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 32),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  const _AdminCard({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    const red = RailSahayakAdminApp.adminRed;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title management will be added next.')),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: red),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
