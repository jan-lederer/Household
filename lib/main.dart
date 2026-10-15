import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';

const ink = Color(0xFF283F35);
const sage = Color(0xFF36594B);
const muted = Color(0xFF7A857D);
const cream = Color(0xFFF8F7F3);
const line = Color(0xFFE5E8E0);
const peach = Color(0xFFFAE9DC);
const leaf = Color(0xFFE8EEE4);
const orange = Color(0xFFD48C64);
const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DwellStore();
  if (Uri.base.queryParameters['demo'] == '1') {
    store.startDemo();
  } else {
    store.initialize();
  }
  runApp(DwellApp(store: store));
}

class DwellApp extends StatelessWidget {
  const DwellApp({super.key, required this.store});
  final DwellStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dwell · A happier home',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sage,
        primary: sage,
        surface: cream,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontSize: 14),
        bodyLarge: TextStyle(color: ink, fontSize: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: sage,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: sage,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      dividerColor: line,
    ),
    home: AnimatedBuilder(
      animation: store,
      builder: (context, _) => !store.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : store.user == null
          ? AuthPage(store: store)
          : HomePage(store: store),
    ),
  );
}

class HomeMark extends StatelessWidget {
  const HomeMark({super.key, this.size = 42, this.light = false});
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: light ? Colors.white.withValues(alpha: .16) : sage,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.cottage_rounded, color: cream, size: size * .68),
        Positioned(
          right: size * .09,
          top: size * .09,
          child: Icon(
            Icons.auto_awesome,
            color: const Color(0xFFE9C695),
            size: size * .23,
          ),
        ),
      ],
    ),
  );
}

Text heading(String text, {double size = 28, Color color = ink}) => Text(
  text,
  style: TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: -.8,
    height: 1.18,
    color: color,
  ),
);
Text caption(String text, {Color color = muted}) =>
    Text(text, style: TextStyle(color: color, fontSize: 13, height: 1.5));
Widget gap([double height = 16]) => SizedBox(height: height);
void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
String dateLabel(String date) {
  final now = DateTime.now();
  if (date == dayKey(now)) return 'Today';
  if (date == dayKey(now.add(const Duration(days: 1)))) return 'Tomorrow';
  final d = DateTime.parse(date);
  return '${d.day} ${months[d.month - 1].substring(0, 3)}';
}

IconData roomIcon(String room) => switch (room) {
  'Kitchen' => Icons.kitchen_outlined,
  'Bathroom' => Icons.water_drop_outlined,
  'Living room' => Icons.chair_outlined,
  'Bedroom' => Icons.bed_outlined,
  _ => Icons.cleaning_services_outlined,
};

Future<void> serverSheet(BuildContext context, DwellStore store) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cream,
    builder: (_) => ServerSheet(store: store),
  );
}

class ServerSheet extends StatefulWidget {
  const ServerSheet({super.key, required this.store});
  final DwellStore store;
  @override
  State<ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<ServerSheet> {
  late final controller = TextEditingController(text: widget.store.server);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 28,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('Connect your home'),
        gap(8),
        caption(
          'Enter the address of your Dwell backend. Your phone and server must be able to reach each other.',
        ),
        gap(22),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Server address',
            hintText: 'https://dwell.example.com',
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        gap(12),
        caption(
          'Use HTTPS for a public server. Local HTTP is supported on your home network.',
        ),
        if (error != null) ...[
          gap(),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        gap(22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await widget.store.setServer(controller.text);
                      if (context.mounted) {
                        Navigator.pop(context);
                        toast(context, 'Connected to your Dwell server');
                      }
                    } catch (e) {
                      if (mounted) setState(() => error = '$e');
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'Connecting…' : 'Save & test connection'),
          ),
        ),
      ],
    ),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store});
  final DwellStore store;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool register = true, busy = false, obscure = true;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.authenticate(
        email: email.text.trim(),
        password: password.text,
        name: register ? name.text.trim() : null,
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const HomeMark(size: 48),
                        const SizedBox(width: 12),
                        heading('dwell', size: 34),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Server connection',
                          onPressed: () => serverSheet(context, widget.store),
                          icon: const Icon(Icons.dns_outlined, color: sage),
                        ),
                      ],
                    ),
                    gap(38),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: leaf,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'A LITTLE TEAMWORK. A HAPPIER HOME.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: sage,
                        ),
                      ),
                    ),
                    gap(18),
                    heading('Make room for\nthe good stuff.', size: 43),
                    gap(14),
                    caption(
                      'Less chasing chores. More feeling at home.\nShare the everyday with your favorite people.',
                    ),
                    gap(30),
                    heading(
                      register ? 'Find your home rhythm' : 'Welcome home',
                      size: 23,
                    ),
                    gap(6),
                    caption(
                      register
                          ? 'Create an account to get everyone together.'
                          : 'Sign in and pick up where you left off.',
                    ),
                    gap(20),
                    if (register) ...[
                      TextFormField(
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter your name'
                            : v.trim().length > 60
                            ? 'Use up to 60 characters'
                            : null,
                      ),
                      gap(12),
                    ],
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                      validator: (v) =>
                          v == null ||
                              !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(v.trim())
                          ? 'Enter a valid email'
                          : null,
                    ),
                    gap(12),
                    TextFormField(
                      controller: password,
                      obscureText: obscure,
                      autofillHints: [
                        register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: register ? 'At least 8 characters' : null,
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 8 || v.length > 128
                          ? 'Use 8–128 characters'
                          : null,
                      onFieldSubmitted: (_) => busy ? null : submit(),
                    ),
                    if (error != null || widget.store.startupError != null) ...[
                      gap(12),
                      Text(
                        error ?? widget.store.startupError!,
                        style: const TextStyle(color: Color(0xFFB45237)),
                      ),
                    ],
                    gap(22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : submit,
                        child: Text(
                          busy
                              ? 'One moment…'
                              : register
                              ? 'Create account  →'
                              : 'Sign in  →',
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                register = !register;
                                error = null;
                              }),
                        child: Text(
                          register
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account',
                        ),
                      ),
                    ),
                    const Divider(),
                    gap(4),
                    Center(
                      child: TextButton.icon(
                        onPressed: busy ? null : widget.store.startDemo,
                        icon: const Icon(Icons.explore_outlined, size: 18),
                        label: const Text('Explore a demo home'),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => serverSheet(context, widget.store),
                        child: const Text(
                          'Set up server connection',
                          style: TextStyle(color: muted, fontSize: 12),
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
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final DwellStore store;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int page = 0;
  String filter = 'All chores';
  DateTime selected = DateTime.now();
  bool busy = false;
  DwellStore get store => widget.store;
  Future<void> run(Future<void> Function() action, {String? success}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted && success != null) toast(context, success);
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 220,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: line)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const HomeMark(),
                        const SizedBox(width: 10),
                        heading('dwell', size: 30),
                      ],
                    ),
                    gap(50),
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            selected: page == i,
                            selectedTileColor: leaf,
                            selectedColor: sage,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: Icon(
                              [
                                Icons.space_dashboard_outlined,
                                Icons.checklist_rounded,
                                Icons.people_outline,
                              ][i],
                            ),
                            title: Text(['Overview', 'Chores', 'Household'][i]),
                            onTap: () => setState(() => page = i),
                          ),
                        ),
                      ),
                    const Spacer(),
                    caption('A little teamwork.\nA happier home.'),
                    gap(20),
                    OutlinedButton.icon(
                      onPressed: settings,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Settings'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  header(wide),
                  if (busy)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    const SizedBox(height: 2),
                  if (store.demo)
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFEFEADD),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            size: 15,
                            color: sage,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Demo home · changes reset when you leave',
                              style: TextStyle(fontSize: 11, color: sage),
                            ),
                          ),
                          InkWell(
                            onTap: () => run(store.signOut),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'Exit demo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: sage,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => run(store.refresh),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          wide ? 40 : 22,
                          26,
                          wide ? 40 : 22,
                          100,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1050),
                            child: store.household == null
                                ? onboarding()
                                : page == 0
                                ? dashboard(wide)
                                : page == 1
                                ? choresPage()
                                : householdPage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 72,
              backgroundColor: Colors.white,
              indicatorColor: leaf,
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checklist_rounded),
                  label: 'Chores',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: 'Household',
                ),
              ],
            ),
      floatingActionButton: store.household == null || page == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: busy ? null : () => editChore(),
              backgroundColor: sage,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add chore'),
            ),
    );
  }

  Widget header(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(wide ? 40 : 22, 16, wide ? 40 : 22, 14),
    child: Row(
      children: [
        if (!wide) ...[const HomeMark(size: 34), const SizedBox(width: 10)],
        Expanded(
          child: InkWell(
            onTap: store.households.isEmpty ? null : switchHousehold,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR SHARED SPACE',
                        style: TextStyle(
                          fontSize: 9,
                          color: muted,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        store.household?['name'] as String? ??
                            'Welcome to Dwell',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (store.households.isNotEmpty)
                  const Icon(Icons.keyboard_arrow_down, color: muted, size: 18),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Refresh household',
          onPressed: busy ? null : () => run(store.refresh),
          icon: const Icon(Icons.sync_rounded, size: 20, color: muted),
        ),
        IconButton(
          tooltip: 'Account and settings',
          onPressed: settings,
          padding: EdgeInsets.zero,
          icon: CircleAvatar(
            radius: 20,
            backgroundColor: peach,
            child: Text(
              store.firstName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: sage,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget dashboard(bool wide) {
    final todayChores = store.chores
        .where(
          (c) =>
              c.due == store.today ||
              (!c.done && c.due.compareTo(store.today) < 0),
        )
        .toList();
    final done = todayChores.where((c) => c.done).length;
    final progress = todayChores.isEmpty ? 0.0 : done / todayChores.length;
    final selectedKey = dayKey(selected);
    final tasks =
        store.chores
            .where(
              (c) =>
                  c.due == selectedKey ||
                  (selectedKey == store.today &&
                      !c.done &&
                      c.due.compareTo(store.today) < 0),
            )
            .toList()
          ..sort(
            (a, b) => a.done == b.done
                ? a.due.compareTo(b.due)
                : a.done
                ? 1
                : -1,
          );
    final upcoming =
        store.chores
            .where((c) => !c.done && c.due.compareTo(store.today) > 0)
            .toList()
          ..sort((a, b) => a.due.compareTo(b.due));
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  caption(
                    '${weekdays[DateTime.now().weekday - 1]}, ${DateTime.now().day} ${months[DateTime.now().month - 1]}',
                  ),
                  gap(8),
                  heading(
                    'Hey ${store.firstName},\nlet’s make home happy.',
                    size: wide ? 34 : 30,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Icon(Icons.wb_sunny_outlined, color: orange, size: 35),
            ),
          ],
        ),
        gap(24),
        Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            color: sage,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A LITTLE BETTER, TOGETHER',
                      style: TextStyle(
                        color: Color(0xFFCCDACB),
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    gap(12),
                    heading(
                      todayChores.isEmpty
                          ? 'A little room to breathe.'
                          : done == todayChores.length
                          ? 'Look at you go!'
                          : 'Small chores.\nBig difference.',
                      size: 25,
                      color: Colors.white,
                    ),
                    gap(12),
                    Text(
                      todayChores.isEmpty
                          ? 'Your home is all caught up today.'
                          : '$done of ${todayChores.length} chores done today',
                      style: const TextStyle(
                        color: Color(0xFFDBE5D8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 79,
                height: 79,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: .16),
                        color: const Color(0xFFE6C99D),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap(26),
        Row(
          children: [
            Expanded(child: heading('Your week, at a glance', size: 19)),
            TextButton(
              onPressed: () => setState(() => selected = DateTime.now()),
              child: const Text('Today', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        gap(12),
        weekStrip(),
        gap(26),
        Row(
          children: [
            Expanded(
              child: heading(
                selectedKey == store.today
                    ? 'On the list today'
                    : 'On the list · ${dateLabel(selectedKey)}',
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: leaf,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${tasks.where((c) => !c.done).length} to do',
                style: const TextStyle(
                  color: sage,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        gap(14),
        if (tasks.isEmpty)
          empty(
            'A clear day feels good.',
            'Add a chore or enjoy a little breathing room.',
            Icons.wb_sunny_outlined,
          )
        else
          ...tasks.map(choreTile),
        gap(26),
        Row(
          children: [
            Expanded(child: heading('A little further ahead', size: 20)),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => setState(() {
                page = 1;
                filter = 'All chores';
              }),
              child: const Text('View all', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        gap(10),
        if (upcoming.isEmpty)
          caption('Nothing coming up. Add your next shared task.')
        else
          ...upcoming.take(3).map(choreTile),
      ],
    );
    if (!wide) return main;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: main),
        const SizedBox(width: 32),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              gap(5),
              householdSummary(),
              gap(22),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: peach,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.favorite_border_rounded,
                      color: orange,
                      size: 28,
                    ),
                    gap(16),
                    heading('A home is a\nteam effort.', size: 24),
                    gap(12),
                    caption(
                      'Every small thing you do makes your shared space a little brighter.',
                    ),
                    gap(18),
                    TextButton(
                      onPressed: () => setState(() => page = 2),
                      child: const Text('Meet your home team  →'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget weekStrip() {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return Row(
      children: List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final key = dayKey(day), active = dayKey(selected) == key;
        final hasChores = store.chores.any((c) => c.due == key && !c.done);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 6 ? 0 : 5),
            child: InkWell(
              onTap: () => setState(() => selected = day),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: active ? sage : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: active ? sage : line),
                ),
                child: Column(
                  children: [
                    Text(
                      weekdays[i].substring(0, 1),
                      style: TextStyle(
                        color: active ? Colors.white70 : muted,
                        fontSize: 11,
                      ),
                    ),
                    gap(8),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        color: active ? Colors.white : ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    gap(7),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasChores
                            ? active
                                  ? const Color(0xFFE6C99D)
                                  : orange
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget choresPage() {
    final tasks =
        store.chores
            .where(
              (c) => filter == 'Completed'
                  ? c.done
                  : !c.done &&
                        (filter != 'Assigned to me' ||
                            c.assigneeId == store.userId),
            )
            .toList()
          ..sort((a, b) => a.due.compareTo(b.due));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('A place for every chore.'),
        gap(10),
        caption('Share the load. Keep the good energy.'),
        gap(24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['All chores', 'Assigned to me', 'Completed']
              .map(
                (label) => ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: filter == label,
                  onSelected: (_) => setState(() => filter = label),
                  selectedColor: leaf,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: filter == label ? sage.withValues(alpha: .3) : line,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              )
              .toList(),
        ),
        gap(24),
        if (tasks.isEmpty)
          empty(
            filter == 'Completed'
                ? 'Good things take little steps.'
                : 'All clear here.',
            filter == 'Completed'
                ? 'Chores you finish will appear here.'
                : 'Add a chore and give it a home.',
            Icons.checklist_rounded,
          )
        else
          ...tasks.map(choreTile),
      ],
    );
  }

  Widget choreTile(Chore chore) {
    final overdue = !chore.done && chore.due.compareTo(store.today) < 0;
    final tint = chore.room == 'Kitchen' || chore.room == 'Bathroom'
        ? peach
        : leaf;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: chore.done ? const Color(0xFFF0F2EC) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: busy ? null : () => editChore(chore: chore),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 8, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    roomIcon(chore.room),
                    size: 23,
                    color: chore.room == 'Kitchen' || chore.room == 'Bathroom'
                        ? const Color(0xFFAF7656)
                        : sage,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chore.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: chore.done ? muted : ink,
                          fontSize: 13,
                          height: 1.35,
                          decoration: chore.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      gap(6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            chore.room,
                            style: const TextStyle(fontSize: 10, color: muted),
                          ),
                          const Text('·', style: TextStyle(color: muted)),
                          Text(
                            chore.done
                                ? 'Done'
                                : overdue
                                ? 'Overdue · ${dateLabel(chore.due)}'
                                : dateLabel(chore.due),
                            style: TextStyle(
                              fontSize: 10,
                              color: overdue ? const Color(0xFFB06A44) : muted,
                            ),
                          ),
                          if (chore.repeat != 'none')
                            const Icon(
                              Icons.repeat_rounded,
                              size: 12,
                              color: muted,
                            ),
                        ],
                      ),
                      gap(7),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: chore.assigneeId == store.userId
                                ? leaf
                                : peach,
                            child: Text(
                              chore.assigneeId == null
                                  ? '?'
                                  : store
                                        .memberName(chore.assigneeId)
                                        .substring(0, 1),
                              style: const TextStyle(
                                fontSize: 8,
                                color: sage,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            store.memberName(chore.assigneeId),
                            style: const TextStyle(fontSize: 10, color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Semantics(
                  checked: chore.done,
                  label: 'Complete ${chore.title}',
                  child: IconButton(
                    tooltip: chore.done ? 'Reopen chore' : 'Mark as done',
                    onPressed: busy || (chore.done && chore.repeat != 'none')
                        ? null
                        : () => run(
                            () => store.complete(chore),
                            success: chore.done
                                ? 'Chore reopened'
                                : 'One less thing. Nicely done!',
                          ),
                    icon: Icon(
                      chore.done
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 25,
                      color: chore.done ? sage : const Color(0xFFCAD3C7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget householdSummary() {
    final open = store.chores.where((c) => !c.done).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: heading('The home team', size: 20)),
              const SizedBox(width: 8),
              const Icon(Icons.people_outline, color: sage),
            ],
          ),
          gap(7),
          caption('${store.members.length} people, one happy home.'),
          gap(22),
          ...store.members.map((member) {
            final count = open
                .where((c) => c.assigneeId == member['id'])
                .length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: member['id'] == store.userId
                        ? leaf
                        : peach,
                    radius: 19,
                    child: Text(
                      (member['name'] as String).substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 14, color: sage),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      store.memberName(member['id'] as String),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '$count to do',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            );
          }),
          if (open.any((c) => c.assigneeId == null))
            caption(
              '${open.where((c) => c.assigneeId == null).length} chores are open for anyone.',
            ),
        ],
      ),
    );
  }

  Widget householdPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading('Better under one roof.'),
      gap(10),
      caption('Your people. Your space. Your shared rhythm.'),
      gap(26),
      householdSummary(),
      gap(20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: leaf,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.mail_outline_rounded, color: sage),
            gap(16),
            heading('Make yourself at home.', size: 23),
            gap(10),
            caption(
              'Share this invite code with your housemates. They can create an account and join your household.',
            ),
            gap(18),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    store.household!['code'] as String,
                    style: const TextStyle(
                      fontSize: 27,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                      color: sage,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy invite code',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: store.household!['code'] as String),
                    );
                    if (mounted) {
                      toast(
                        context,
                        store.demo
                            ? 'Demo code copied · use a real household to invite'
                            : 'Invite code copied',
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined, color: sage),
                ),
              ],
            ),
          ],
        ),
      ),
      gap(24),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => groupDialog(false),
              icon: const Icon(Icons.add_home_outlined, size: 18),
              label: const Text('Create home'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => groupDialog(true),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Join home'),
            ),
          ),
        ],
      ),
      gap(18),
      caption(
        'Every household has its own chores and invite code. Switch homes from the name at the top.',
      ),
    ],
  );

  Widget onboarding() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      gap(24),
      const HomeMark(size: 72),
      gap(30),
      heading('A fresh start\nfor your shared space.', size: 36),
      gap(16),
      caption(
        'Create a household for your apartment, or join your housemates with an invite code.',
      ),
      gap(30),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => groupDialog(false),
          icon: const Icon(Icons.add_home_outlined),
          label: const Text('Create a household'),
        ),
      ),
      gap(12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => groupDialog(true),
          icon: const Icon(Icons.key_outlined),
          label: const Text('Join with an invite code'),
        ),
      ),
    ],
  );

  Widget empty(String title, String subtitle, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: line),
    ),
    child: Column(
      children: [
        Icon(icon, size: 30, color: sage),
        gap(14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        gap(7),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );

  Future<void> editChore({Chore? chore}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      useSafeArea: true,
      builder: (_) => ChoreSheet(store: store, chore: chore),
    );
  }

  Future<void> groupDialog(bool join) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      builder: (_) => GroupSheet(store: store, join: join),
    );
  }

  Future<void> switchHousehold() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('Your homes', size: 24),
              gap(18),
              ...store.households.map(
                (g) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.home_outlined, color: sage),
                  title: Text(g['name'] as String),
                  trailing: g['id'] == store.household?['id']
                      ? const Icon(Icons.check_rounded, color: sage)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    run(() => store.selectHousehold(g));
                  },
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_rounded),
                title: const Text('Create or join another home'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => page = 2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> settings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('Your little corner', size: 25),
              gap(10),
              Text(
                store.user!['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              caption(store.user!['email'] as String),
              gap(20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dns_outlined, color: sage),
                title: const Text('Server connection'),
                subtitle: Text(
                  store.demo ? 'Demo preview' : store.server,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  serverSheet(context, store);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: sage),
                title: Text(store.demo ? 'Leave demo home' : 'Sign out'),
                onTap: () {
                  Navigator.pop(ctx);
                  run(store.signOut);
                },
              ),
              gap(10),
              caption('Dwell 1.0 · A little teamwork. A happier home.'),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupSheet extends StatefulWidget {
  const GroupSheet({super.key, required this.store, required this.join});
  final DwellStore store;
  final bool join;
  @override
  State<GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<GroupSheet> {
  final controller = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 28,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          widget.join ? 'Your people are waiting.' : 'Give your home a name.',
          size: 26,
        ),
        gap(10),
        caption(
          widget.join
              ? 'Ask a housemate for the code on their Household tab.'
              : 'Something that feels like you. You can create multiple households.',
        ),
        gap(22),
        TextField(
          controller: controller,
          maxLength: widget.join ? 20 : 60,
          textCapitalization: widget.join
              ? TextCapitalization.characters
              : TextCapitalization.words,
          decoration: InputDecoration(
            labelText: widget.join ? 'Invite code' : 'Household name',
            hintText: widget.join
                ? 'e.g. A1B2C3D4'
                : 'e.g. The Willow apartment',
          ),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        gap(18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (controller.text.trim().isEmpty) {
                      setState(
                        () => error = widget.join
                            ? 'Enter an invite code.'
                            : 'Enter a household name.',
                      );
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      if (widget.join) {
                        await widget.store.joinHousehold(
                          controller.text.trim(),
                        );
                      } else {
                        await widget.store.createHousehold(
                          controller.text.trim(),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) setState(() => error = '$e');
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(
              busy
                  ? 'One moment…'
                  : widget.join
                  ? 'Join household'
                  : 'Create household',
            ),
          ),
        ),
      ],
    ),
  );
}

class ChoreSheet extends StatefulWidget {
  const ChoreSheet({super.key, required this.store, this.chore});
  final DwellStore store;
  final Chore? chore;
  @override
  State<ChoreSheet> createState() => _ChoreSheetState();
}

class _ChoreSheetState extends State<ChoreSheet> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.chore?.title);
  late String room = widget.chore?.room ?? 'Kitchen';
  late String repeat = widget.chore?.repeat ?? 'none';
  late String assignee = widget.chore?.assigneeId ?? '';
  late DateTime due = DateTime.parse(widget.chore?.due ?? widget.store.today);
  bool busy = false;
  String? error;
  bool get completed => widget.chore?.done ?? false;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.saveChore({
        'title': title.text.trim(),
        'room': room,
        'repeat': repeat,
        'assignee_id': assignee.isEmpty ? null : assignee,
        'due': dayKey(due),
      }, id: widget.chore?.id);
      if (mounted) {
        Navigator.pop(context);
        toast(
          context,
          widget.chore == null
              ? 'A little teamwork starts here'
              : 'Chore updated',
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this chore?'),
        content: Text(
          '“${widget.chore!.title}” will be removed from this household.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep chore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.deleteChore(widget.chore!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 28,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: heading(
                      completed
                          ? 'A little win for home.'
                          : widget.chore == null
                          ? 'One small thing.'
                          : 'Make it your own.',
                      size: 28,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close editor',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              caption(
                completed
                    ? 'This chore is complete. Your home thanks you.'
                    : 'Give it a name, a person, and a little time.',
              ),
              gap(24),
              TextFormField(
                controller: title,
                enabled: !completed && !busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'What needs doing?',
                  hintText: 'e.g. Water the plants',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Give your chore a name'
                    : null,
              ),
              gap(6),
              DropdownButtonFormField<String>(
                initialValue: room,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Room'),
                items:
                    {
                          ...[
                            'Kitchen',
                            'Living room',
                            'Bathroom',
                            'Bedroom',
                            'Shared spaces',
                          ],
                          room,
                        }
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                onChanged: completed || busy
                    ? null
                    : (v) => setState(() => room = v!),
              ),
              gap(14),
              DropdownButtonFormField<String>(
                initialValue: assignee,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Who’s on it?'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Anyone · leave it open'),
                  ),
                  ...widget.store.members.map(
                    (m) => DropdownMenuItem(
                      value: m['id'] as String,
                      child: Text(widget.store.memberName(m['id'] as String)),
                    ),
                  ),
                ],
                onChanged: completed || busy
                    ? null
                    : (v) => setState(() => assignee = v!),
              ),
              gap(14),
              OutlinedButton(
                onPressed: completed || busy
                    ? null
                    : () async {
                        final chosen = await showDatePicker(
                          context: context,
                          initialDate: due,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (chosen != null) setState(() => due = chosen);
                      },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(17),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 19),
                    const SizedBox(width: 12),
                    Text('Due ${dateLabel(dayKey(due))}'),
                    const Spacer(),
                    const Icon(Icons.expand_more_rounded, size: 19),
                  ],
                ),
              ),
              gap(14),
              DropdownButtonFormField<String>(
                initialValue: repeat,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('Just this once'),
                  ),
                  DropdownMenuItem(value: 'daily', child: Text('Every day')),
                  DropdownMenuItem(value: 'weekly', child: Text('Every week')),
                ],
                onChanged: completed || busy
                    ? null
                    : (v) => setState(() => repeat = v!),
              ),
              if (repeat != 'none') ...[
                gap(10),
                caption(
                  'Completing this chore creates its next occurrence. Completed repeating chores stay in your history.',
                ),
              ],
              if (error != null) ...[
                gap(14),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
              gap(24),
              if (!completed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(
                      busy
                          ? 'Saving…'
                          : widget.chore == null
                          ? 'Add to our home  →'
                          : 'Save changes',
                    ),
                  ),
                ),
              if (widget.chore != null)
                Center(
                  child: TextButton.icon(
                    onPressed: busy ? null : delete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete chore'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFA7634A),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
