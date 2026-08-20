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
  static const red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RailSahayak Admin',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: red),
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
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const _Loading();
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
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const _Loading();
          final data = snapshot.data?.data();
          final role = '${data?['role'] ?? ''}'.toLowerCase();
          final approved = data?['approved'] == true || '${data?['approved']}'.toLowerCase() == 'true';
          if (data != null && role == 'admin' && approved) return const AdminDashboard();
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
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(), password: _password.text,
      );
      final doc = await FirebaseFirestore.instance.collection('admin').doc(credential.user!.uid).get();
      final data = doc.data();
      final ok = data != null && '${data['role']}'.toLowerCase() == 'admin' &&
          (data['approved'] == true || '${data['approved']}'.toLowerCase() == 'true');
      if (!ok) {
        await FirebaseAuth.instance.signOut();
        throw Exception('This account is not an approved RailSahayak administrator.');
      }
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? 'Administrator login failed.', true);
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text, bool error) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircleAvatar(radius: 40, backgroundColor: RailSahayakAdminApp.red,
              child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 42)),
            const SizedBox(height: 20),
            const Text('RailSahayak Admin', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(controller: _email, enabled: !_loading, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Administrator Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid administrator email'),
            const SizedBox(height: 16),
            TextFormField(controller: _password, enabled: !_loading, obscureText: _obscure,
              decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure))),
              validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 54, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: RailSahayakAdminApp.red, foregroundColor: Colors.white),
              onPressed: _loading ? null : _login,
              icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login),
              label: Text(_loading ? 'Signing in...' : 'Administrator Login'),
            )),
          ])),
        )),
      ),
    ))),
  );
}

bool _isPendingStaff(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data();
  final role = '${d['role'] ?? ''}'.trim().toLowerCase();
  final status = '${d['status'] ?? d['approvalStatus'] ?? ''}'.trim().toLowerCase();
  final requested = d['staffRequested'] == true || d['isStaffRequest'] == true ||
      role == 'staff_pending' || role == 'pending_staff' || role == 'staff';
  final pending = status.isEmpty && role.contains('pending') ? 'pending' : status;
  return requested && ['pending', 'requested', 'waiting', 'pending_approval', 'staff_pending'].contains(pending);
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  void _open(BuildContext c, Widget p) => Navigator.push(c, MaterialPageRoute(builder: (_) => p));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin Dashboard'), backgroundColor: RailSahayakAdminApp.red, foregroundColor: Colors.white,
      actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('requests').snapshots(),
      builder: (_, requestsSnapshot) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, usersSnapshot) {
          if (requestsSnapshot.hasError || usersSnapshot.hasError) return const Center(child: Text('Unable to load dashboard data. Check Firestore permissions.'));
          if (!requestsSnapshot.hasData || !usersSnapshot.hasData) return const _Loading();
          final users = usersSnapshot.data!.docs;
          final requests = requestsSnapshot.data!.docs;
          final staff = users.where((x) => '${x.data()['role']}'.toLowerCase() == 'staff' && !_isPendingStaff(x)).length;
          final pendingStaff = users.where(_isPendingStaff).length;
          int count(String type) => requests.where((x) {
            final s = '${x.data()['status'] ?? ''}'.toLowerCase();
            if (type == 'requested') return s == 'requested' || s == 'pending';
            if (type == 'active') return ['assigned','assisting','accepted','in_progress','in progress'].contains(s);
            return s == 'completed';
          }).length;
          return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Overview', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.25, children: [
              _Stat(icon: Icons.people, title: 'Total Users', value: '${users.length}', color: Colors.blue, onTap: () => _open(context, const UserManagementScreen())),
              _Stat(icon: Icons.badge, title: 'Staff', value: '$staff', color: RailSahayakAdminApp.red, onTap: () => _open(context, const StaffManagementScreen())),
              _Stat(icon: Icons.person_add_alt_1, title: 'Staff Pending', value: '$pendingStaff', color: Colors.orange, onTap: () => _open(context, const PendingStaffScreen())),
              _Stat(icon: Icons.hourglass_top, title: 'Requested', value: '${count('requested')}', color: Colors.orange, onTap: () => _open(context, const RequestManagementScreen(filter: 'requested'))),
              _Stat(icon: Icons.directions_run, title: 'Active', value: '${count('active')}', color: Colors.blue, onTap: () => _open(context, const RequestManagementScreen(filter: 'active'))),
              _Stat(icon: Icons.check_circle, title: 'Completed', value: '${count('completed')}', color: Colors.green, onTap: () => _open(context, const RequestManagementScreen(filter: 'completed'))),
            ]),
            const SizedBox(height: 28),
            const Text('Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, children: [
              _Admin(icon: Icons.person_add_alt_1, title: 'Staff Approval', onTap: () => _open(context, const PendingStaffScreen())),
              _Admin(icon: Icons.people_alt, title: 'Staff', onTap: () => _open(context, const StaffManagementScreen())),
              _Admin(icon: Icons.assistant, title: 'Requests', onTap: () => _open(context, const RequestManagementScreen())),
              _Admin(icon: Icons.person, title: 'Users', onTap: () => _open(context, const UserManagementScreen())),
              _Admin(icon: Icons.settings, title: 'Settings', onTap: () => _open(context, const AdminSettingsScreen())),
            ]),
          ]));
        },
      ),
    ),
  );
}

class PendingStaffScreen extends StatelessWidget {
  const PendingStaffScreen({super.key});
  Future<void> _approve(String id) => FirebaseFirestore.instance.collection('users').doc(id).set({
    'role': 'staff', 'status': 'approved', 'approved': true, 'approvalStatus': 'approved', 'staffRequested': true,
    'approvedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  Future<void> _reject(String id) => FirebaseFirestore.instance.collection('users').doc(id).set({
    'status': 'rejected', 'approved': false, 'approvalStatus': 'rejected',
    'rejectedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Staff Approval Requests')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Could not load staff requests: ${snapshot.error}'));
        if (!snapshot.hasData) return const _Loading();
        final docs = snapshot.data!.docs.where(_isPendingStaff).toList();
        if (docs.isEmpty) return const Center(child: Text('No pending staff approval requests.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16), itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data();
            return Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d['name'] ?? d['displayName'] ?? 'Staff applicant'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Email: ${d['email'] ?? '-'}\nPhone: ${d['phone'] ?? '-'}'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _reject(doc.id), icon: const Icon(Icons.close), label: const Text('Reject'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton.icon(onPressed: () => _approve(doc.id), icon: const Icon(Icons.check), label: const Text('Approve'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white))),
                ]),
              ]),
            ));
          },
        );
      },
    ),
  );
}

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => _CollectionScreen(
    title: 'Staff Management', stream: FirebaseFirestore.instance.collection('users').snapshots(), empty: 'No approved staff accounts found.',
    filter: (doc) => '${doc.data()['role']}'.toLowerCase() == 'staff' && !_isPendingStaff(doc),
    itemBuilder: (context, doc) {
      final d = doc.data(); final disabled = '${d['status']}'.toLowerCase() == 'disabled';
      return Card(child: ListTile(
        leading: Icon(disabled ? Icons.person_off : Icons.badge, color: disabled ? Colors.grey : RailSahayakAdminApp.red),
        title: Text('${d['name'] ?? 'Railway Staff'}'), subtitle: Text('${d['email'] ?? ''}\n${disabled ? 'Access disabled' : 'Approved staff'}'), isThreeLine: true,
        trailing: IconButton(icon: Icon(disabled ? Icons.person_add : Icons.block, color: RailSahayakAdminApp.red), onPressed: () => FirebaseFirestore.instance.collection('users').doc(doc.id).set({'status': disabled ? 'approved' : 'disabled', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))),
      ));
    },
  );
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => _CollectionScreen(
    title: 'User Management', stream: FirebaseFirestore.instance.collection('users').snapshots(), empty: 'No users found.',
    itemBuilder: (context, doc) {
      final d = doc.data(); final role = '${d['role'] ?? 'passenger'}'; final disabled = '${d['status']}'.toLowerCase() == 'disabled';
      return Card(child: ListTile(
        leading: CircleAvatar(child: Icon(role.toLowerCase() == 'staff' ? Icons.badge : Icons.person)),
        title: Text('${d['name'] ?? 'User'}'), subtitle: Text('${d['email'] ?? ''}\n$role${disabled ? ' • Disabled' : ''}'), isThreeLine: true,
        trailing: IconButton(icon: Icon(disabled ? Icons.person_add : Icons.block, color: RailSahayakAdminApp.red), onPressed: () => FirebaseFirestore.instance.collection('users').doc(doc.id).set({'status': disabled ? 'active' : 'disabled', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))),
      ));
    },
  );
}

class RequestManagementScreen extends StatelessWidget {
  final String? filter;
  const RequestManagementScreen({super.key, this.filter});
  bool _match(String s) {
    s = s.toLowerCase(); if (filter == null) return true;
    if (filter == 'requested') return s == 'requested' || s == 'pending';
    if (filter == 'active') return ['assigned','assisting','accepted','in_progress','in progress'].contains(s);
    return s == 'completed';
  }
  @override
  Widget build(BuildContext context) => _CollectionScreen(
    title: filter == null ? 'Assistance Requests' : '${filter![0].toUpperCase()}${filter!.substring(1)} Requests',
    stream: FirebaseFirestore.instance.collection('requests').snapshots(), empty: 'No assistance requests found.',
    filter: (doc) => _match('${doc.data()['status'] ?? 'requested'}'),
    itemBuilder: (context, doc) {
      final d = doc.data(); final status = '${d['status'] ?? 'requested'}'.toLowerCase(); const allowed = ['requested','assigned','assisting','completed','cancelled'];
      return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${d['passengerName'] ?? d['name'] ?? 'Passenger'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6), Text('Train: ${d['trainName'] ?? d['trainNo'] ?? '-'}\nCoach: ${d['coach'] ?? '-'}\nPNR: ${d['pnr'] ?? '-'}\nStatus: $status'), const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: allowed.contains(status) ? status : 'requested', items: allowed.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) FirebaseFirestore.instance.collection('requests').doc(doc.id).set({'status': v, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); }),
      ])));
    },
  );
}

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return Scaffold(appBar: AppBar(title: const Text('Admin Settings')), body: ListView(padding: const EdgeInsets.all(20), children: [
      Card(child: ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('Administrator Account'), subtitle: Text(u?.email ?? 'No email available'))),
      Card(child: ListTile(leading: const Icon(Icons.lock_reset), title: const Text('Send password reset email'), onTap: u?.email == null ? null : () async { await FirebaseAuth.instance.sendPasswordResetEmail(email: u!.email!); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.'))); })),
      Card(child: ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Sign out'), onTap: () => FirebaseAuth.instance.signOut())),
    ]));
  }
}

class _CollectionScreen extends StatelessWidget {
  final String title, empty;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool Function(QueryDocumentSnapshot<Map<String, dynamic>>) filter;
  final Widget Function(BuildContext, QueryDocumentSnapshot<Map<String, dynamic>>) itemBuilder;
  const _CollectionScreen({required this.title, required this.stream, required this.empty, required this.itemBuilder, bool Function(QueryDocumentSnapshot<Map<String, dynamic>>)? filter}) : filter = filter ?? _all;
  static bool _all(QueryDocumentSnapshot<Map<String, dynamic>> _) => true;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: stream, builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Text('Could not load data: ${snapshot.error}'));
    if (!snapshot.hasData) return const _Loading();
    final docs = snapshot.data!.docs.where(filter).toList();
    if (docs.isEmpty) return Center(child: Text(empty));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length, itemBuilder: (context, i) => itemBuilder(context, docs[i]));
  }));
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(color: RailSahayakAdminApp.red)));
}

class _Stat extends StatelessWidget {
  final IconData icon; final String title, value; final Color color; final VoidCallback onTap;
  const _Stat({required this.icon, required this.title, required this.value, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color, size: 30), Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold)), Text(title, style: const TextStyle(fontWeight: FontWeight.w600))]))));
}

class _Admin extends StatelessWidget {
  final IconData icon; final String title; final VoidCallback onTap;
  const _Admin({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 42, color: RailSahayakAdminApp.red), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))])));
}
