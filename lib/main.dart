import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

const _red = Color(0xFFC62828);
const _surface = Color(0xFFFFF8F8);
const _text = Color(0xFF1F1B1D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RailSahayakAdminApp());
}

class RailSahayakAdminApp extends StatelessWidget {
  const RailSahayakAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RailSahayak Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _red, brightness: Brightness.light),
        scaffoldBackgroundColor: _surface,
        appBarTheme: const AppBarTheme(backgroundColor: _red, foregroundColor: Colors.white),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _red, width: 2),
          ),
        ),
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
        if (snapshot.connectionState == ConnectionState.waiting) return const _Loading();
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
        if (snapshot.connectionState != ConnectionState.done) return const _Loading();
        final data = snapshot.data?.data();
        final role = '${data?['role'] ?? ''}'.toLowerCase();
        final approved = data?['approved'] == true || '${data?['approved']}'.toLowerCase() == 'true';
        if (data != null && role == 'admin' && approved) return const AdminDashboard();
        WidgetsBinding.instance.addPostFrameCallback((_) => FirebaseAuth.instance.signOut());
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
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
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
      _show(e.message ?? 'Administrator login failed.');
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Semantics(
                          header: true,
                          child: Text('RailSahayak Admin', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _text)),
                        ),
                        const SizedBox(height: 8),
                        const Text('Secure administrator access', textAlign: TextAlign.center),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _email,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Administrator email', prefixIcon: Icon(Icons.email_outlined)),
                          validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid administrator email',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          enabled: !_loading,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _loading ? null : _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: _red),
                            onPressed: _loading ? null : _login,
                            icon: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login),
                            label: Text(_loading ? 'Signing in…' : 'Sign in'),
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

bool _pending(Map<String, dynamic> data) {
  final status = '${data['status'] ?? data['approvalStatus'] ?? ''}'.trim().toLowerCase();
  return ['pending', 'requested', 'waiting', 'pending_approval', 'staff_pending'].contains(status);
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('RailSahayak Admin'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()))),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('users').snapshots(),
        builder: (context, usersSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('requests').snapshots(),
            builder: (context, requestsSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db.collection('staff_requests').where('status', isEqualTo: 'pending').snapshots(),
                builder: (context, staffSnapshot) {
                  if (usersSnapshot.hasError || requestsSnapshot.hasError || staffSnapshot.hasError) {
                    return const _Message(icon: Icons.lock_outline, title: 'Unable to load data', message: 'Check your Firestore permissions and try again.');
                  }
                  if (!usersSnapshot.hasData || !requestsSnapshot.hasData || !staffSnapshot.hasData) return const _Loading();

                  final users = usersSnapshot.data!.docs;
                  final requests = requestsSnapshot.data!.docs;
                  final pendingStaff = staffSnapshot.data!.docs.length;
                  final staff = users.where((d) => '${d.data()['role']}'.toLowerCase() == 'staff' && '${d.data()['status']}'.toLowerCase() != 'disabled').length;
                  int requestCount(String type) => requests.where((d) {
                    final s = '${d.data()['status'] ?? ''}'.toLowerCase();
                    if (type == 'active') return ['assigned', 'assisting', 'accepted', 'in_progress', 'in progress'].contains(s);
                    if (type == 'completed') return s == 'completed';
                    return s == 'requested' || s == 'pending';
                  }).length;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      const Semantics(header: true, child: Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _text))),
                      const SizedBox(height: 6),
                      const Text('Manage staff, passengers and assistance requests.'),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Summary(label: 'Pending staff', value: '$pendingStaff', icon: Icons.pending_actions, onTap: () => _open(context, const PendingStaffScreen())),
                          _Summary(label: 'Approved staff', value: '$staff', icon: Icons.badge_outlined, onTap: () => _open(context, const StaffManagementScreen())),
                          _Summary(label: 'Active requests', value: '${requestCount('active')}', icon: Icons.directions_run, onTap: () => _open(context, const RequestManagementScreen(filter: 'active'))),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Semantics(header: true, child: Text('Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _text))),
                      const SizedBox(height: 8),
                      _ActionRow(icon: Icons.how_to_reg_outlined, title: 'Staff approvals', subtitle: pendingStaff == 0 ? 'No pending applications' : '$pendingStaff waiting for review', badge: pendingStaff == 0 ? null : '$pendingStaff', onTap: () => _open(context, const PendingStaffScreen())),
                      _ActionRow(icon: Icons.badge_outlined, title: 'Staff management', subtitle: '$staff approved staff members', onTap: () => _open(context, const StaffManagementScreen())),
                      _ActionRow(icon: Icons.assistant_outlined, title: 'Assistance requests', subtitle: '${requests.length} total • ${requestCount('active')} active • ${requestCount('completed')} completed', onTap: () => _open(context, const RequestManagementScreen())),
                      _ActionRow(icon: Icons.people_outline, title: 'Passenger accounts', subtitle: '${users.length} registered users', onTap: () => _open(context, const UserManagementScreen())),
                      _ActionRow(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Administrator account settings', onTap: () => _open(context, const AdminSettingsScreen())),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _Summary({required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: $value',
    child: SizedBox(
      width: 170,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: _red), const SizedBox(height: 18),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _text)),
              Text(label),
            ]),
          ),
        ),
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Icon(icon, color: _red), const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _text)),
                const SizedBox(height: 3), Text(subtitle),
              ])),
              if (badge != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(20)), child: Text(badge!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8), const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ),
    ),
  );
}

class PendingStaffScreen extends StatelessWidget {
  const PendingStaffScreen({super.key});

  Future<void> _approve(String id, String uid, Map<String, dynamic> data) async {
    if (uid.isEmpty) return;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final user = FirebaseFirestore.instance.collection('users').doc(uid);
      final request = FirebaseFirestore.instance.collection('staff_requests').doc(id);
      tx.set(user, {
        'id': uid, 'name': data['name'] ?? 'Railway Staff',
        'username': '${data['email'] ?? ''}'.split('@').first.toLowerCase(),
        'email': data['email'] ?? '', 'phone': data['phone'] ?? '',
        'role': 'staff', 'status': 'approved', 'approved': true,
        'approvalStatus': 'approved', 'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.update(request, {'status': 'approved', 'approvedUid': uid, 'approvedAt': FieldValue.serverTimestamp()});
    });
  }

  Future<void> _reject(String id) => FirebaseFirestore.instance.collection('staff_requests').doc(id).update({'status': 'rejected', 'rejectedAt': FieldValue.serverTimestamp()});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Staff approvals')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('staff_requests').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _Message(icon: Icons.error_outline, title: 'Could not load applications', message: '${snapshot.error}');
        if (!snapshot.hasData) return const _Loading();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const _Message(icon: Icons.check_circle_outline, title: 'All caught up', message: 'There are no pending staff approval requests.');
        return ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index]; final d = doc.data(); final uid = '${d['uid'] ?? ''}';
            return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d['name'] ?? 'Staff applicant'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
              const SizedBox(height: 6), Text('${d['email'] ?? 'No email'}\n${d['phone'] ?? 'No phone'}'),
              const SizedBox(height: 16), Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _reject(doc.id), icon: const Icon(Icons.close), label: const Text('Reject'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700), onPressed: uid.isEmpty ? null : () => _approve(doc.id, uid, d), icon: const Icon(Icons.check), label: const Text('Approve'))),
              ]),
            ])));
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
    title: 'Staff management',
    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'staff').snapshots(),
    empty: 'No approved staff accounts found.',
    itemBuilder: (context, doc) {
      final d = doc.data(); final disabled = '${d['status']}'.toLowerCase() == 'disabled';
      return ListTile(
        leading: Icon(disabled ? Icons.person_off_outlined : Icons.badge_outlined, color: disabled ? Colors.grey : _red),
        title: Text('${d['name'] ?? 'Railway Staff'}'),
        subtitle: Text('${d['email'] ?? ''}\n${disabled ? 'Access disabled' : 'Approved staff'}'),
        isThreeLine: true,
        trailing: IconButton(tooltip: disabled ? 'Enable staff access' : 'Disable staff access', icon: Icon(disabled ? Icons.person_add_alt_1 : Icons.block), onPressed: () => FirebaseFirestore.instance.collection('users').doc(doc.id).set({'status': disabled ? 'approved' : 'disabled', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))),
      );
    },
  );
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => _CollectionScreen(
    title: 'Passenger accounts',
    stream: FirebaseFirestore.instance.collection('users').snapshots(),
    empty: 'No users found.',
    filter: (doc) => '${doc.data()['role']}'.toLowerCase() != 'staff',
    itemBuilder: (context, doc) {
      final d = doc.data(); final disabled = '${d['status']}'.toLowerCase() == 'disabled';
      return ListTile(
        leading: const Icon(Icons.person_outline, color: _red),
        title: Text('${d['name'] ?? 'Passenger'}'),
        subtitle: Text('${d['email'] ?? ''}\n${disabled ? 'Account disabled' : 'Active account'}'),
        isThreeLine: true,
        trailing: IconButton(tooltip: disabled ? 'Enable account' : 'Disable account', icon: Icon(disabled ? Icons.person_add_alt_1 : Icons.block), onPressed: () => FirebaseFirestore.instance.collection('users').doc(doc.id).set({'status': disabled ? 'active' : 'disabled', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))),
      );
    },
  );
}

class RequestManagementScreen extends StatelessWidget {
  final String? filter;
  const RequestManagementScreen({super.key, this.filter});

  bool _matches(String status) {
    if (filter == null) return true;
    if (filter == 'active') return ['assigned', 'assisting', 'accepted', 'in_progress', 'in progress'].contains(status);
    if (filter == 'completed') return status == 'completed';
    return status == 'requested' || status == 'pending';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Assistance requests')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('requests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _Message(icon: Icons.error_outline, title: 'Could not load requests', message: '${snapshot.error}');
        if (!snapshot.hasData) return const _Loading();
        final docs = snapshot.data!.docs.where((d) => _matches('${d.data()['status'] ?? ''}'.toLowerCase())).toList();
        if (docs.isEmpty) return const _Message(icon: Icons.inbox_outlined, title: 'No requests', message: 'There are no assistance requests in this category.');
        return ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final d = docs[index].data(); final status = '${d['status'] ?? 'Unknown'}';
            return ListTile(
              leading: const Icon(Icons.train_outlined, color: _red),
              title: Text('${d['passengerName'] ?? d['name'] ?? 'Passenger assistance'}'),
              subtitle: Text('Status: $status'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRequest(context, d),
            );
          },
        );
      },
    ),
  );

  void _showRequest(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: SelectableText(d.entries.map((e) => '${e.key}: ${e.value}').join('\n'))));
  }
}

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Administrator';
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ListTile(leading: const Icon(Icons.email_outlined, color: _red), title: const Text('Signed-in account'), subtitle: Text(email)),
        const Divider(),
        ListTile(leading: const Icon(Icons.lock_reset_outlined, color: _red), title: const Text('Send password reset email'), onTap: () async {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
        }),
        const Divider(),
        ListTile(leading: const Icon(Icons.logout, color: _red), title: const Text('Sign out'), onTap: () => FirebaseAuth.instance.signOut()),
      ]),
    );
  }
}

class _CollectionScreen extends StatelessWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String empty;
  final bool Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)? filter;
  final Widget Function(BuildContext, QueryDocumentSnapshot<Map<String, dynamic>>) itemBuilder;
  const _CollectionScreen({required this.title, required this.stream, required this.empty, required this.itemBuilder, this.filter});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _Message(icon: Icons.error_outline, title: 'Could not load data', message: '${snapshot.error}');
        if (!snapshot.hasData) return const _Loading();
        final docs = filter == null ? snapshot.data!.docs : snapshot.data!.docs.where(filter!).toList();
        if (docs.isEmpty) return _Message(icon: Icons.inbox_outlined, title: empty, message: '');
        return ListView.separated(padding: const EdgeInsets.all(12), itemCount: docs.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, i) => itemBuilder(context, docs[i]));
      },
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _Message({required this.icon, required this.title, required this.message});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 52, color: _red), const SizedBox(height: 16), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: _text)), if (message.isNotEmpty) ...[const SizedBox(height: 8), Text(message, textAlign: TextAlign.center)] ]))));
}
