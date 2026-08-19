import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RailSahayakAdminApp());
}

class RailSahayakAdminApp extends StatelessWidget {
  const RailSahayakAdminApp({super.key});
  static const adminRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) => MaterialApp(
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

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasData) return const AdminLoginScreen();
          return AdminAuthorizationGate(user: snapshot.data!);
        },
      );
}

class AdminAuthorizationGate extends StatelessWidget {
  final User user;
  const AdminAuthorizationGate({super.key, required this.user});
  @override
  Widget build(BuildContext context) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('admin').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final data = snapshot.data?.data();
          final role = data?['role']?.toString().trim().toLowerCase();
          final approved = data?['approved'] == true || data?['approved']?.toString().trim().toLowerCase() == 'true';
          if (snapshot.hasData && data != null && role == 'admin' && approved) return const AdminDashboard();
          FirebaseAuth.instance.signOut();
          return const AdminLoginScreen();
        },
      );
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
      final doc = await FirebaseFirestore.instance.collection('admin').doc(uid).get();
      final data = doc.data();
      final role = data?['role']?.toString().trim().toLowerCase();
      final approved = data?['approved'] == true || data?['approved']?.toString().trim().toLowerCase() == 'true';
      if (!doc.exists || role != 'admin' || !approved) {
        await FirebaseAuth.instance.signOut();
        throw Exception('This account is not an approved RailSahayak administrator.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _snack(_authMessage(e), error: true);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : null),
      );

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found': return 'The administrator email or password is incorrect.';
      case 'invalid-email': return 'Enter a valid administrator email address.';
      case 'too-many-requests': return 'Too many attempts. Please wait and try again.';
      default: return e.message ?? 'Administrator login failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    const red = RailSahayakAdminApp.adminRed;
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Card(
        elevation: 8,
        shadowColor: red.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(padding: const EdgeInsets.all(28), child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircleAvatar(radius: 40, backgroundColor: red, child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 42)),
          const SizedBox(height: 20),
          const Text('RailSahayak Admin', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), Text('Approved administrators only', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 30),
          TextFormField(controller: _emailController, enabled: !_loading, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Administrator Email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))), validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid administrator email'),
          const SizedBox(height: 16),
          TextFormField(controller: _passwordController, enabled: !_loading, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))), validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 54, child: ElevatedButton.icon(onPressed: _loading ? null : _login, icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login), label: Text(_loading ? 'Signing in...' : 'Administrator Login', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        ]))),
      )),
    )));
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  static const red = RailSahayakAdminApp.adminRed;

  void _open(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'), backgroundColor: red, foregroundColor: Colors.white,
          actions: [IconButton(tooltip: 'Refresh', onPressed: () {}, icon: const Icon(Icons.refresh)), IconButton(tooltip: 'Sign out', onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('requests').snapshots(),
          builder: (context, requestSnapshot) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              if (requestSnapshot.hasError || userSnapshot.hasError) return const Center(child: Text('Unable to load dashboard data. Check Firestore permissions.'));
              if (!requestSnapshot.hasData || !userSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: red));
              final requests = requestSnapshot.data!.docs;
              final users = userSnapshot.data!.docs;
              final staff = users.where((u) => '${u.data()['role']}'.toLowerCase() == 'staff').length;
              int count(String type) => requests.where((r) {
                final s = '${r.data()['status'] ?? ''}'.trim().toLowerCase();
                if (type == 'requested') return s == 'requested' || s == 'pending';
                if (type == 'active') return ['assigned', 'assisting', 'accepted', 'in_progress', 'in progress'].contains(s);
                return s == 'completed';
              }).length;
              return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Overview', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Live RailSahayak system statistics', style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: 24),
                GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.2, children: [
                  _StatCard(icon: Icons.people_rounded, title: 'Total Users', value: users.length.toString(), color: Colors.blue, onTap: () => _open(context, const UserManagementScreen())),
                  _StatCard(icon: Icons.badge_rounded, title: 'Staff', value: staff.toString(), color: red, onTap: () => _open(context, const StaffManagementScreen())),
                  _StatCard(icon: Icons.hourglass_top_rounded, title: 'Requested', value: count('requested').toString(), color: Colors.orange, onTap: () => _open(context, const RequestManagementScreen(filter: 'requested'))),
                  _StatCard(icon: Icons.directions_run_rounded, title: 'Active', value: count('active').toString(), color: Colors.blue, onTap: () => _open(context, const RequestManagementScreen(filter: 'active'))),
                  _StatCard(icon: Icons.check_circle_rounded, title: 'Completed', value: count('completed').toString(), color: Colors.green, onTap: () => _open(context, const RequestManagementScreen(filter: 'completed'))),
                ]),
                const SizedBox(height: 28), const Text('Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 14),
                GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, children: [
                  _AdminCard(icon: Icons.people_alt_rounded, title: 'Staff', onTap: () => _open(context, const StaffManagementScreen())),
                  _AdminCard(icon: Icons.assistant_rounded, title: 'Requests', onTap: () => _open(context, const RequestManagementScreen())),
                  _AdminCard(icon: Icons.person_rounded, title: 'Users', onTap: () => _open(context, const UserManagementScreen())),
                  _AdminCard(icon: Icons.settings_rounded, title: 'Settings', onTap: () => _open(context, const AdminSettingsScreen())),
                ]),
              ]));
            },
          ),
        ),
      );
}

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});
  static const red = RailSahayakAdminApp.adminRed;
  @override
  Widget build(BuildContext context) => _CollectionScreen(
    title: 'Staff Management', stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'staff').snapshots(),
    empty: 'No staff accounts found.',
    itemBuilder: (context, doc) { final d = doc.data(); final disabled = '${d['status']}'.toLowerCase() == 'disabled'; return Card(child: ListTile(leading: Icon(disabled ? Icons.person_off : Icons.badge, color: disabled ? Colors.grey : red), title: Text('${d['name'] ?? 'Railway Staff'}'), subtitle: Text('${d['email'] ?? ''}\n${disabled ? 'Access disabled' : 'Active staff'}'), isThreeLine: true, trailing: IconButton(tooltip: disabled ? 'Enable staff' : 'Disable staff', icon: Icon(disabled ? Icons.person_add : Icons.block, color: red), onPressed: () => FirebaseFirestore.instance.collection('users').doc(doc.id).set({'status': disabled ? 'approved' : 'disabled', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)))),); },
  );
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});
  static const red = RailSahayakAdminApp.adminRed;
  @override
  Widget build(BuildContext context) => _CollectionScreen(
    title: 'User Management', stream: FirebaseFirestore.instance.collection('users').snapshots(), empty: 'No users found.',
    itemBuilder: (context, doc) { final d = doc.data(); final role = '${d['role'] ?? 'passenger'}'; final disabled = '${d['status']}'.toLowerCase() == 'disabled'; return Card(child: ListTile(leading: CircleAvatar(child: Icon(role.toLowerCase() == 'staff' ? Icons.badge : Icons.person)), title: Text('${d['name'] ?? 'User'}'), subtitle: Text('${d['email'] ?? ''}\n$role${disabled ? ' • Disabled' : ''}'), isThreeLine: true, trailing: IconButton(tooltip: disabled ? 'Enable user' : 'Disable user', icon: Icon(disabled ? Icons.person_add : Icons.block, color: red), onPressed: () => FirebaseFirestore.instance.collection('users').doc(doc.id).set({'status': disabled ? 'active' : 'disabled', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)))); },
  );
}

class RequestManagementScreen extends StatelessWidget {
  final String? filter;
  const RequestManagementScreen({super.key, this.filter});
  static const red = RailSahayakAdminApp.adminRed;
  bool _matches(String status) { final s = status.toLowerCase(); if (filter == null) return true; if (filter == 'requested') return s == 'requested' || s == 'pending'; if (filter == 'active') return ['assigned','assisting','accepted','in_progress','in progress'].contains(s); return s == 'completed'; }
  @override
  Widget build(BuildContext context) => _CollectionScreen(
    title: filter == null ? 'Assistance Requests' : '${filter![0].toUpperCase()}${filter!.substring(1)} Requests', stream: FirebaseFirestore.instance.collection('requests').snapshots(), empty: 'No assistance requests found.',
    itemBuilder: (context, doc) { final d = doc.data(); final status = '${d['status'] ?? 'requested'}'; if (!_matches(status)) return const SizedBox.shrink(); return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${d['passengerName'] ?? d['name'] ?? 'Passenger'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text('Train: ${d['trainName'] ?? d['trainNo'] ?? '-'}\nCoach: ${d['coach'] ?? '-'}\nPNR: ${d['pnr'] ?? '-'}\nStatus: $status'), const SizedBox(height: 10), DropdownButtonFormField<String>(value: ['requested','assigned','assisting','completed','cancelled'].contains(status.toLowerCase()) ? status.toLowerCase() : 'requested', decoration: const InputDecoration(labelText: 'Update status', border: OutlineInputBorder()), items: const ['requested','assigned','assisting','completed','cancelled'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (value) { if (value != null) FirebaseFirestore.instance.collection('requests').doc(doc.id).update({'status': value, 'updatedAt': FieldValue.serverTimestamp()}); })]))); },
  );
}

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});
  static const red = RailSahayakAdminApp.adminRed;
  @override
  Widget build(BuildContext context) { final user = FirebaseAuth.instance.currentUser; return Scaffold(appBar: AppBar(title: const Text('Settings'), backgroundColor: red, foregroundColor: Colors.white), body: ListView(padding: const EdgeInsets.all(20), children: [Card(child: ListTile(leading: const Icon(Icons.email_outlined, color: red), title: const Text('Administrator account'), subtitle: Text(user?.email ?? 'No email'))), Card(child: ListTile(leading: const Icon(Icons.lock_reset, color: red), title: const Text('Send password reset email'), subtitle: const Text('Send a reset link to the administrator email'), onTap: user?.email == null ? null : () async { await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.'))); })), Card(child: ListTile(leading: const Icon(Icons.logout, color: red), title: const Text('Sign out'), onTap: () => FirebaseAuth.instance.signOut()))])); }
}

class _CollectionScreen extends StatelessWidget {
  final String title; final Stream<QuerySnapshot<Map<String, dynamic>>> stream; final String empty; final Widget Function(BuildContext, QueryDocumentSnapshot<Map<String, dynamic>>) itemBuilder;
  const _CollectionScreen({required this.title, required this.stream, required this.empty, required this.itemBuilder});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title), backgroundColor: RailSahayakAdminApp.adminRed, foregroundColor: Colors.white), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: stream, builder: (context, snapshot) { if (snapshot.hasError) return Center(child: Text('Could not load data: ${snapshot.error}')); if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); final docs = snapshot.data!.docs; if (docs.isEmpty) return Center(child: Text(empty)); return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length, itemBuilder: (context, i) => itemBuilder(context, docs[i])); }));
}

class _StatCard extends StatelessWidget {
  final IconData icon; final String title; final String value; final Color color; final VoidCallback onTap;
  const _StatCard({required this.icon, required this.title, required this.value, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color, size: 32), Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), Text(title, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500))]))));
}

class _AdminCard extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback onTap;
  const _AdminCard({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) { const red = RailSahayakAdminApp.adminRed; return Card(elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 48, color: red), const SizedBox(height: 14), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]))); }
}
