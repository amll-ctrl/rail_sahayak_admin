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
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'RailSahayak Admin',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _red),
      scaffoldBackgroundColor: _surface,
      appBarTheme: const AppBarTheme(backgroundColor: _red, foregroundColor: Colors.white),
      cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 1),
    ),
    home: const AdminGate(),
  );
}

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (_, s) {
      if (s.connectionState == ConnectionState.waiting) return const _Loading();
      if (!s.hasData) return const AdminLoginScreen();
      return AdminAuthorizationGate(user: s.data!);
    },
  );
}

class AdminAuthorizationGate extends StatelessWidget {
  final User user;
  const AdminAuthorizationGate({super.key, required this.user});
  @override
  Widget build(BuildContext context) => FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    future: FirebaseFirestore.instance.collection('admin').doc(user.uid).get(),
    builder: (_, s) {
      if (s.connectionState != ConnectionState.done) return const _Loading();
      final d = s.data?.data();
      final ok = d != null && '${d['role']}'.toLowerCase() == 'admin' && (d['approved'] == true || '${d['approved']}'.toLowerCase() == 'true');
      if (ok) return const AdminDashboard();
      WidgetsBinding.instance.addPostFrameCallback((_) => FirebaseAuth.instance.signOut());
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
  bool _loading = false, _obscure = true;
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
      final d = await FirebaseFirestore.instance.collection('admin').doc(c.user!.uid).get();
      final data = d.data();
      final ok = data != null && '${data['role']}'.toLowerCase() == 'admin' && (data['approved'] == true || '${data['approved']}'.toLowerCase() == 'true');
      if (!ok) { await FirebaseAuth.instance.signOut(); throw Exception('This account is not an approved administrator.'); }
    } on FirebaseAuthException catch (e) { _show(e.message ?? 'Login failed'); }
    catch (e) { _show(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  void _show(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Card(child: Padding(
      padding: const EdgeInsets.all(28), child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(header: true, child: const Text('RailSahayak Admin', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _text))),
        const SizedBox(height: 8), const Text('Secure administrator access', textAlign: TextAlign.center), const SizedBox(height: 28),
        TextFormField(controller: _email, enabled: !_loading, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Administrator email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()), validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email'),
        const SizedBox(height: 16),
        TextFormField(controller: _password, enabled: !_loading, obscureText: _obscure, onFieldSubmitted: (_) => _loading ? null : _login(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(), suffixIcon: IconButton(tooltip: _obscure ? 'Show password' : 'Hide password', icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure))), validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null),
        const SizedBox(height: 24), SizedBox(height: 52, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _red), onPressed: _loading ? null : _login, icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login), label: Text(_loading ? 'Signing in…' : 'Sign in'))),
      ])),
    ))),
  ))));
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  void _open(BuildContext c, Widget p) => Navigator.push(c, MaterialPageRoute(builder: (_) => p));
  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('RailSahayak Admin'), actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () {}), IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('users').snapshots(), builder: (context, us) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('requests').snapshots(), builder: (context, rs) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: db.collection('staff_requests').where('status', isEqualTo: 'pending').snapshots(), builder: (context, ss) {
        if (us.hasError || rs.hasError || ss.hasError) return const Center(child: Text('Unable to load data. Check Firestore permissions.'));
        if (!us.hasData || !rs.hasData || !ss.hasData) return const _Loading();
        final users = us.data!.docs, requests = rs.data!.docs, pending = ss.data!.docs.length;
        final staff = users.where((d) => '${d.data()['role']}'.toLowerCase() == 'staff' && '${d.data()['status']}'.toLowerCase() != 'disabled').length;
        final active = requests.where((d) => ['assigned','assisting','accepted','in_progress','in progress'].contains('${d.data()['status']}'.toLowerCase())).length;
        return ListView(padding: const EdgeInsets.all(20), children: [
          Semantics(header: true, child: const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _text))), const SizedBox(height: 6), const Text('Manage staff, passengers and assistance requests.'), const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Summary(label: 'Pending staff', value: '$pending', icon: Icons.pending_actions, onTap: () => _open(context, const PendingStaffScreen())),
            _Summary(label: 'Approved staff', value: '$staff', icon: Icons.badge_outlined, onTap: () => _open(context, const StaffManagementScreen())),
            _Summary(label: 'Active requests', value: '$active', icon: Icons.directions_run, onTap: () => _open(context, const RequestManagementScreen(filter: 'active'))),
          ]), const SizedBox(height: 28),
          Semantics(header: true, child: const Text('Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _text))), const SizedBox(height: 10),
          _ActionRow(icon: Icons.how_to_reg_outlined, title: 'Staff approvals', subtitle: pending == 0 ? 'No pending applications' : '$pending waiting for review', onTap: () => _open(context, const PendingStaffScreen())),
          _ActionRow(icon: Icons.badge_outlined, title: 'Staff management', subtitle: '$staff approved staff members', onTap: () => _open(context, const StaffManagementScreen())),
          _ActionRow(icon: Icons.assistant_outlined, title: 'Assistance requests', subtitle: '${requests.length} total requests', onTap: () => _open(context, const RequestManagementScreen())),
          _ActionRow(icon: Icons.people_outline, title: 'Passenger accounts', subtitle: '${users.length} registered accounts', onTap: () => _open(context, const UserManagementScreen())),
          _ActionRow(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Administrator account information', onTap: () => _open(context, const AdminSettingsScreen())),
        ]);
      })));
    );
  }
}

class _Summary extends StatelessWidget {
  final String label, value; final IconData icon; final VoidCallback onTap;
  const _Summary({required this.label, required this.value, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(button: true, label: '$label: $value', child: SizedBox(width: 170, child: Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _red), const SizedBox(height: 18), Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), Text(label)])))));
}

class _ActionRow extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), leading: Icon(icon, color: _red), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap)));
}

class PendingStaffScreen extends StatelessWidget {
  const PendingStaffScreen({super.key});
  Future<void> _approve(String id, String uid, Map<String,dynamic> d) async {
    if (uid.isEmpty) return;
    final db = FirebaseFirestore.instance;
    await db.runTransaction((tx) async {
      tx.set(db.collection('users').doc(uid), {'id': uid, 'name': d['name'] ?? 'Railway Staff', 'username': '${d['email'] ?? ''}'.split('@').first, 'email': d['email'] ?? '', 'phone': d['phone'] ?? '', 'role': 'staff', 'status': 'approved', 'approved': true, 'approvalStatus': 'approved', 'approvedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      tx.update(db.collection('staff_requests').doc(id), {'status': 'approved', 'approvedUid': uid, 'approvedAt': FieldValue.serverTimestamp()});
    });
  }
  Future<void> _reject(String id) => FirebaseFirestore.instance.collection('staff_requests').doc(id).update({'status':'rejected','rejectedAt':FieldValue.serverTimestamp()});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Staff Approval Requests')), body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: FirebaseFirestore.instance.collection('staff_requests').where('status', isEqualTo: 'pending').snapshots(), builder: (context,s) {
    if (s.hasError) return Center(child: Text('Could not load requests: ${s.error}'));
    if (!s.hasData) return const _Loading();
    if (s.data!.docs.isEmpty) return const Center(child: Text('No pending staff approval requests.'));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: s.data!.docs.length, itemBuilder: (_,i) { final doc=s.data!.docs[i]; final d=doc.data(); final uid='${d['uid'] ?? ''}'; return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text('${d['name'] ?? 'Staff applicant'}', style: const TextStyle(fontSize:18,fontWeight:FontWeight.bold)), const SizedBox(height:6), Text('${d['email'] ?? '-'}\n${d['phone'] ?? '-'}'), const SizedBox(height:14), Row(children:[Expanded(child: OutlinedButton.icon(onPressed:()=>_reject(doc.id), icon:const Icon(Icons.close), label:const Text('Reject'))), const SizedBox(width:12), Expanded(child: FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:Colors.green), onPressed:uid.isEmpty?null:()=>_approve(doc.id,uid,d), icon:const Icon(Icons.check), label:const Text('Approve')))])]))); });
  }));
}

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => _CollectionScreen(title:'Staff Management', empty:'No approved staff accounts found.', stream:FirebaseFirestore.instance.collection('users').where('role',isEqualTo:'staff').snapshots(), itemBuilder:(context,doc){ final d=doc.data(); final disabled='${d['status']}'.toLowerCase()=='disabled'; return Card(child: ListTile(leading:Icon(disabled?Icons.person_off:Icons.badge,color:_red), title:Text('${d['name'] ?? 'Railway Staff'}'), subtitle:Text('${d['email'] ?? ''}\n${disabled?'Access disabled':'Approved staff'}'), isThreeLine:true, trailing:IconButton(tooltip:disabled?'Enable staff':'Disable staff', icon:Icon(disabled?Icons.person_add:Icons.block), onPressed:()=>FirebaseFirestore.instance.collection('users').doc(doc.id).set({'status':disabled?'approved':'disabled','updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true)))));});
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => _CollectionScreen(title:'Passenger Accounts', empty:'No users found.', stream:FirebaseFirestore.instance.collection('users').snapshots(), filter:(d)=>'${d.data()['role']}'.toLowerCase()!='staff', itemBuilder:(context,doc){ final d=doc.data(); final disabled='${d['status']}'.toLowerCase()=='disabled'; return Card(child: ListTile(leading:const Icon(Icons.person,color:_red), title:Text('${d['name'] ?? 'Passenger'}'), subtitle:Text('${d['email'] ?? ''}\n${disabled?'Account disabled':'Active account'}'), isThreeLine:true, trailing:IconButton(tooltip:disabled?'Enable account':'Disable account', icon:Icon(disabled?Icons.person_add:Icons.block), onPressed:()=>FirebaseFirestore.instance.collection('users').doc(doc.id).set({'status':disabled?'active':'disabled','updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true)))));});
}

class RequestManagementScreen extends StatelessWidget {
  final String? filter;
  const RequestManagementScreen({super.key,this.filter});
  bool _match(Map<String,dynamic> d) { if(filter==null)return true; final s='${d['status']}'.toLowerCase(); if(filter=='active')return ['assigned','assisting','accepted','in_progress','in progress'].contains(s); return s==filter || (filter=='requested'&&s=='pending'); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar:AppBar(title:const Text('Assistance Requests')), body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('requests').snapshots(),builder:(context,s){if(s.hasError)return Center(child:Text('Could not load requests: ${s.error}'));if(!s.hasData)return const _Loading();final docs=s.data!.docs.where((d)=>_match(d.data())).toList();if(docs.isEmpty)return const Center(child:Text('No assistance requests found.'));return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,itemBuilder:(_,i){final doc=docs[i];final d=doc.data();return Card(child:ListTile(title:Text('${d['passengerName'] ?? d['name'] ?? 'Passenger assistance'}'),subtitle:Text('Status: ${d['status'] ?? 'unknown'}'),trailing:const Icon(Icons.chevron_right),onTap:()=>_showRequest(context,d)));});}));
  void _showRequest(BuildContext context, Map<String,dynamic> d) { showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Padding(padding:const EdgeInsets.all(24),child:SingleChildScrollView(child:SelectableText(d.entries.map((e)=>'${e.key}: ${e.value}').join('\n')))))); }
}

class _CollectionScreen extends StatelessWidget {
  final String title, empty; final Stream<QuerySnapshot<Map<String,dynamic>>> stream; final bool Function(QueryDocumentSnapshot<Map<String,dynamic>>)? filter; final Widget Function(BuildContext,QueryDocumentSnapshot<Map<String,dynamic>>) itemBuilder;
  const _CollectionScreen({required this.title,required this.empty,required this.stream,required this.itemBuilder,this.filter});
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(title)),body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:stream,builder:(context,s){if(s.hasError)return Center(child:Text('Could not load data: ${s.error}'));if(!s.hasData)return const _Loading();final docs=filter==null?s.data!.docs:s.data!.docs.where(filter!).toList();if(docs.isEmpty)return Center(child:Text(empty));return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,itemBuilder:(context,i)=>itemBuilder(context,docs[i]));}));
}

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});
  @override
  Widget build(BuildContext context){final u=FirebaseAuth.instance.currentUser;return Scaffold(appBar:AppBar(title:const Text('Settings')),body:ListView(padding:const EdgeInsets.all(20),children:[Card(child:ListTile(leading:const Icon(Icons.admin_panel_settings,color:_red),title:Text(u?.email ?? 'Administrator'),subtitle:const Text('Approved RailSahayak administrator'))),const SizedBox(height:16),FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_red),onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout),label:const Text('Sign out'))]);}
}

class _Loading extends StatelessWidget { const _Loading(); @override Widget build(BuildContext context)=>const Scaffold(body:Center(child:CircularProgressIndicator())); }
