import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

const Color _red = Color(0xFFC62828);
const Color _surface = Color(0xFFFFF8F8);
const Color _text = Color(0xFF1F1B1D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        colorScheme: ColorScheme.fromSeed(seedColor: _red),
        scaffoldBackgroundColor: _surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: _red,
          foregroundColor: Colors.white,
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Loading();
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

  bool _approved(Map<String, dynamic>? data) {
    if (data == null) return false;
    final role = '${data['role'] ?? ''}'.toLowerCase();
    final approved = data['approved'] == true ||
        '${data['approved'] ?? ''}'.toLowerCase() == 'true';
    return role == 'admin' && approved;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('admin').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Loading();
        }
        if (_approved(snapshot.data?.data())) return const AdminDashboard();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FirebaseAuth.instance.signOut();
        });
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(credential.user!.uid)
          .get();
      final data = doc.data();
      final allowed = data != null &&
          '${data['role'] ?? ''}'.toLowerCase() == 'admin' &&
          (data['approved'] == true ||
              '${data['approved'] ?? ''}'.toLowerCase() == 'true');
      if (!allowed) {
        await FirebaseAuth.instance.signOut();
        throw Exception('This account is not an approved administrator.');
      }
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? 'Login failed');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'RailSahayak Admin',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Secure administrator access',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _email,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Administrator email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (value ?? '').contains('@')
                                  ? null
                                  : 'Enter a valid email',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          enabled: !_loading,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() => _obscure = !_obscure);
                              },
                            ),
                          ),
                          validator: (value) => (value ?? '').isEmpty
                              ? 'Enter your password'
                              : null,
                          onFieldSubmitted: (_) {
                            if (!_loading) _login();
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _red,
                            ),
                            onPressed: _loading ? null : _login,
                            icon: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _loading ? 'Signing in…' : 'Sign in',
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
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('users').snapshots(),
        builder: (context, usersSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('requests').snapshots(),
            builder: (context, requestsSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db.collection('staff_requests').snapshots(),
                builder: (context, staffSnapshot) {
                  if (usersSnapshot.hasError ||
                      requestsSnapshot.hasError ||
                      staffSnapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load data. Check Firestore permissions.'),
                    );
                  }
                  if (!usersSnapshot.hasData ||
                      !requestsSnapshot.hasData ||
                      !staffSnapshot.hasData) {
                    return const _Loading();
                  }

                  final users = usersSnapshot.data!.docs;
                  final requests = requestsSnapshot.data!.docs;
                  final pendingDocs = staffSnapshot.data!.docs.where((doc) {
                    return '${doc.data()['status'] ?? ''}'.toLowerCase() ==
                        'pending';
                  }).toList();
                  final staffCount = users.where((doc) {
                    final data = doc.data();
                    return '${data['role'] ?? ''}'.toLowerCase() == 'staff' &&
                        '${data['status'] ?? ''}'.toLowerCase() != 'disabled';
                  }).length;
                  final activeCount = requests.where((doc) {
                    const active = [
                      'assigned',
                      'assisting',
                      'accepted',
                      'in_progress',
                      'in progress',
                    ];
                    return active.contains(
                      '${doc.data()['status'] ?? ''}'.toLowerCase(),
                    );
                  }).length;

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Manage staff, passengers and assistance requests.',
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Summary(
                            label: 'Pending staff',
                            value: '${pendingDocs.length}',
                            icon: Icons.pending_actions,
                            onTap: () => _open(
                              context,
                              const PendingStaffScreen(),
                            ),
                          ),
                          _Summary(
                            label: 'Approved staff',
                            value: '$staffCount',
                            icon: Icons.badge_outlined,
                            onTap: () => _open(
                              context,
                              const StaffManagementScreen(),
                            ),
                          ),
                          _Summary(
                            label: 'Active requests',
                            value: '$activeCount',
                            icon: Icons.directions_run,
                            onTap: () => _open(
                              context,
                              const RequestManagementScreen(filter: 'active'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Management',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ActionRow(
                        icon: Icons.how_to_reg_outlined,
                        title: 'Staff approvals',
                        subtitle: pendingDocs.isEmpty
                            ? 'No pending applications'
                            : '${pendingDocs.length} waiting for review',
                        onTap: () => _open(
                          context,
                          const PendingStaffScreen(),
                        ),
                      ),
                      _ActionRow(
                        icon: Icons.badge_outlined,
                        title: 'Staff management',
                        subtitle: '$staffCount approved staff members',
                        onTap: () => _open(
                          context,
                          const StaffManagementScreen(),
                        ),
                      ),
                      _ActionRow(
                        icon: Icons.assistant_outlined,
                        title: 'Assistance requests',
                        subtitle: '${requests.length} total requests',
                        onTap: () => _open(
                          context,
                          const RequestManagementScreen(),
                        ),
                      ),
                      _ActionRow(
                        icon: Icons.people_outline,
                        title: 'Passenger accounts',
                        subtitle: '${users.length} registered accounts',
                        onTap: () => _open(
                          context,
                          const UserManagementScreen(),
                        ),
                      ),
                      _ActionRow(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Administrator account information',
                        onTap: () => _open(
                          context,
                          const AdminSettingsScreen(),
                        ),
                      ),
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

  const _Summary({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: SizedBox(
        width: 170,
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: _red),
                  const SizedBox(height: 18),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: Icon(icon, color: _red),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class PendingStaffScreen extends StatelessWidget {
  const PendingStaffScreen({super.key});

  Future<void> _approve(
    String requestId,
    String uid,
    Map<String, dynamic> data,
  ) async {
    if (uid.isEmpty) return;
    final db = FirebaseFirestore.instance;
    await db.runTransaction((transaction) async {
      transaction.set(
        db.collection('users').doc(uid),
        {
          'id': uid,
          'name': data['name'] ?? 'Railway Staff',
          'username': '${data['email'] ?? ''}'.split('@').first,
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'role': 'staff',
          'status': 'approved',
          'approved': true,
          'approvalStatus': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.update(
        db.collection('staff_requests').doc(requestId),
        {
          'status': 'approved',
          'approvedUid': uid,
          'approvedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Future<void> _reject(String requestId) {
    return FirebaseFirestore.instance
        .collection('staff_requests')
        .doc(requestId)
        .update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Approval Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('staff_requests').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load requests: ${snapshot.error}'));
          }
          if (!snapshot.hasData) return const _Loading();
          final docs = snapshot.data!.docs.where((doc) {
            return '${doc.data()['status'] ?? ''}'.toLowerCase() == 'pending';
          }).toList();
          if (docs.isEmpty) {
            return const Center(child: Text('No pending staff approval requests.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final uid = '${data['uid'] ?? ''}';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['name'] ?? 'Staff applicant'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${data['email'] ?? '-'}\n${data['phone'] ?? '-'}'),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _reject(doc.id),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: uid.isEmpty
                                  ? null
                                  : () => _approve(doc.id, uid, data),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CollectionScreen(
      title: 'Staff Management',
      empty: 'No approved staff accounts found.',
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      filter: (doc) =>
          '${doc.data()['role'] ?? ''}'.toLowerCase() == 'staff',
      itemBuilder: (context, doc) {
        final data = doc.data();
        final disabled = '${data['status'] ?? ''}'.toLowerCase() == 'disabled';
        return Card(
          child: ListTile(
            leading: Icon(disabled ? Icons.person_off : Icons.badge, color: _red),
            title: Text('${data['name'] ?? 'Railway Staff'}'),
            subtitle: Text(
              '${data['email'] ?? ''}\n${disabled ? 'Access disabled' : 'Approved staff'}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: disabled ? 'Enable staff' : 'Disable staff',
              icon: Icon(disabled ? Icons.person_add : Icons.block),
              onPressed: () {
                FirebaseFirestore.instance.collection('users').doc(doc.id).set(
                  {
                    'status': disabled ? 'approved' : 'disabled',
                    'updatedAt': FieldValue.serverTimestamp(),
                  },
                  SetOptions(merge: true),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CollectionScreen(
      title: 'Passenger Accounts',
      empty: 'No users found.',
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      filter: (doc) =>
          '${doc.data()['role'] ?? ''}'.toLowerCase() != 'staff',
      itemBuilder: (context, doc) {
        final data = doc.data();
        final disabled = '${data['status'] ?? ''}'.toLowerCase() == 'disabled';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.person, color: _red),
            title: Text('${data['name'] ?? 'Passenger'}'),
            subtitle: Text(
              '${data['email'] ?? ''}\n${disabled ? 'Account disabled' : 'Active account'}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: disabled ? 'Enable account' : 'Disable account',
              icon: Icon(disabled ? Icons.person_add : Icons.block),
              onPressed: () {
                FirebaseFirestore.instance.collection('users').doc(doc.id).set(
                  {
                    'status': disabled ? 'active' : 'disabled',
                    'updatedAt': FieldValue.serverTimestamp(),
                  },
                  SetOptions(merge: true),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class RequestManagementScreen extends StatelessWidget {
  final String? filter;
  const RequestManagementScreen({super.key, this.filter});

  bool _matches(Map<String, dynamic> data) {
    if (filter == null) return true;
    final status = '${data['status'] ?? ''}'.toLowerCase();
    if (filter == 'active') {
      return const [
        'assigned',
        'assisting',
        'accepted',
        'in_progress',
        'in progress',
      ].contains(status);
    }
    return status == filter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistance Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('requests').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load requests: ${snapshot.error}'));
          }
          if (!snapshot.hasData) return const _Loading();
          final docs = snapshot.data!.docs
              .where((doc) => _matches(doc.data()))
              .toList();
          if (docs.isEmpty) {
            return const Center(child: Text('No assistance requests found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.assistant, color: _red),
                  title: Text('${data['name'] ?? data['passengerName'] ?? 'Assistance request'}'),
                  subtitle: Text(
                    'Status: ${data['status'] ?? 'unknown'}\n${data['station'] ?? data['fromStation'] ?? ''}',
                  ),
                  isThreeLine: true,
                  onTap: () => _showDetails(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: SelectableText(
                data.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CollectionScreen extends StatelessWidget {
  final String title;
  final String empty;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)? filter;
  final Widget Function(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) itemBuilder;

  const _CollectionScreen({
    required this.title,
    required this.empty,
    required this.stream,
    required this.itemBuilder,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load data: ${snapshot.error}'));
          }
          if (!snapshot.hasData) return const _Loading();
          var docs = snapshot.data!.docs;
          if (filter != null) docs = docs.where(filter!).toList();
          if (docs.isEmpty) return Center(child: Text(empty));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => itemBuilder(context, docs[index]),
          );
        },
      ),
    );
  }
}

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: _red),
              title: Text(user?.email ?? 'Administrator'),
              subtitle: const Text('Approved RailSahayak administrator'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
