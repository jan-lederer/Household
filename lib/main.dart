import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'store.dart';
import 'template_icons.dart';

const appVersion = '1.2.2';

bool _darkPalette = false;
Color get ink =>
    _darkPalette ? const Color(0xFFF1F5FA) : const Color(0xFF172235);
Color get sage =>
    _darkPalette ? const Color(0xFF86D7B5) : const Color(0xFF2C9B76);
Color get muted =>
    _darkPalette ? const Color(0xFFB6C3D4) : const Color(0xFF56657B);
Color get cream =>
    _darkPalette ? const Color(0xFF090E19) : const Color(0xFFF3F6FA);
Color get surface => _darkPalette ? const Color(0xFF131D2D) : Colors.white;
Color get line =>
    _darkPalette ? const Color(0xFF35465C) : const Color(0xFFDDE5EF);
Color get mintSoft =>
    _darkPalette ? const Color(0xFF1D342E) : const Color(0xFFE8F4EE);
Color get leaf =>
    _darkPalette ? const Color(0xFF182923) : const Color(0xFFEAF4EF);
Color get greenAccent => sage;

ThemeData _dwellTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final accent = isDark ? const Color(0xFF86D7B5) : const Color(0xFF2C9B76);
  final page = isDark ? const Color(0xFF090E19) : const Color(0xFFF3F6FA);
  final card = isDark ? const Color(0xFF131D2D) : Colors.white;
  final foreground = isDark ? const Color(0xFFF1F5FA) : const Color(0xFF172235);
  final secondary = isDark ? const Color(0xFFB6C3D4) : const Color(0xFF56657B);
  final outline = isDark ? const Color(0xFF35465C) : const Color(0xFFDDE5EF);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF2C9B76),
        brightness: brightness,
      ).copyWith(
        primary: accent,
        onPrimary: isDark ? const Color(0xFF092117) : Colors.white,
        surface: card,
        onSurface: foreground,
        onSurfaceVariant: secondary,
        outline: outline,
        outlineVariant: outline,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    dividerTheme: DividerThemeData(color: outline),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: accent.withValues(alpha: isDark ? .22 : .14),
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconTheme: IconThemeData(color: secondary),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: outline),
      ),
    ),
  );
}

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DwellStore();
  if (Uri.base.queryParameters['demo'] == '1') {
    await store.loadDarkMode();
    store.startDemo();
  } else {
    await store.initialize();
  }
  runApp(DwellApp(store: store));
}

class DwellApp extends StatelessWidget {
  const DwellApp({super.key, required this.store});
  final DwellStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      _darkPalette = store.darkMode;
      return MaterialApp(
        title: 'Dwell · A happier home',
        debugShowCheckedModeBanner: false,
        theme: _dwellTheme(Brightness.light),
        darkTheme: _dwellTheme(Brightness.dark),
        themeMode: ThemeMode.values.firstWhere(
          (mode) => mode.name == store.colorMode,
          orElse: () => ThemeMode.system,
        ),
        home: Builder(
          builder: (context) {
            _darkPalette = Theme.of(context).brightness == Brightness.dark;
            if (!store.ready) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return store.user == null
                ? AuthPage(store: store)
                : HomePage(store: store);
          },
        ),
      );
    },
  );
}

class HomeMark extends StatelessWidget {
  const HomeMark({super.key, this.size = 36, this.light = false});
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: light ? Colors.white.withValues(alpha: .16) : sage,
      borderRadius: BorderRadius.circular(size * 8 / 48),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.home_rounded, color: Colors.white, size: size * .62),
      ],
    ),
  );
}

class DwellLogo extends StatelessWidget {
  const DwellLogo({super.key, this.light = false, this.size = 23});
  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const HomeMark(),
      const SizedBox(width: 10),
      Text.rich(
        TextSpan(
          text: 'dwell',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            color: light || Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
          children: [
            TextSpan(
              text: '.',
              style: TextStyle(color: sage),
            ),
          ],
        ),
      ),
    ],
  );
}

Text heading(String text, {double size = 28, Color? color}) => Text(
  text,
  style: TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: -.8,
    height: 1.18,
    color: color ?? ink,
  ),
);
Text caption(String text, {Color? color}) => Text(
  text,
  style: TextStyle(color: color ?? muted, fontSize: 13, height: 1.5),
);

Widget pageIntro(
  String eyebrow,
  String title,
  String subtitle, {
  IconData? trailing,
  VoidCallback? onEyebrowTap,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 29),
  child: LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onEyebrowTap,
          borderRadius: BorderRadius.circular(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: sage,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  eyebrow.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: muted,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onEyebrowTap != null) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.keyboard_arrow_down, size: 15, color: muted),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: title,
                  style: TextStyle(
                    fontSize: constraints.maxWidth < 600 ? 32 : 40,
                    height: 1.17,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                  children: title.endsWith('.')
                      ? const []
                      : [
                          TextSpan(
                            text: '.',
                            style: TextStyle(color: sage),
                          ),
                        ],
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Icon(
                trailing,
                color: greenAccent,
                size: constraints.maxWidth < 600 ? 28 : 34,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: muted, height: 1.7),
        ),
      ],
    ),
  ),
);

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
          Text(error!, style: TextStyle(color: Colors.red)),
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

  Future<void> startOffline() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.startOffline();
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
                        const DwellLogo(size: 23),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Server connection',
                          onPressed: () => serverSheet(context, widget.store),
                          icon: Icon(Icons.dns_outlined, color: sage),
                        ),
                      ],
                    ),
                    gap(38),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: sage,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'A LITTLE TEAMWORK',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.6,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    gap(18),
                    Text.rich(
                      TextSpan(
                        text: 'Make room for\nthe good stuff',
                        style: TextStyle(
                          fontSize: 39,
                          height: 1.17,
                          letterSpacing: -1.5,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                        children: [
                          TextSpan(
                            text: '.',
                            style: TextStyle(color: sage),
                          ),
                        ],
                      ),
                    ),
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
                        style: TextStyle(color: Color(0xFFB45237)),
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
                        icon: Icon(Icons.explore_outlined, size: 18),
                        label: const Text('Explore a demo home'),
                      ),
                    ),
                    Center(
                      child: TextButton.icon(
                        onPressed: busy ? null : startOffline,
                        icon: Icon(Icons.offline_bolt_outlined, size: 18),
                        label: const Text('Use offline mode'),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => serverSheet(context, widget.store),
                        child: Text(
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
                width: 230,
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(right: BorderSide(color: line)),
                ),
                padding: const EdgeInsets.fromLTRB(22, 32, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DwellLogo(size: 23),
                    const SizedBox(height: 10),
                    caption('A LITTLE TEAMWORK. A HAPPIER HOME.', color: muted),
                    const SizedBox(height: 54),
                    Text(
                      'YOUR HOME',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Material(
                          color: page == i
                              ? sage.withValues(alpha: _darkPalette ? .18 : .12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => page = i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    [
                                      Icons.space_dashboard_outlined,
                                      Icons.checklist_outlined,
                                      Icons.people_outline,
                                    ][i],
                                    size: 19,
                                    color: page == i ? sage : muted,
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Text(
                                      ['Overview', 'Chores', 'Household'][i],
                                      style: TextStyle(
                                        color: page == i ? ink : muted,
                                        fontSize: 13,
                                        fontWeight: page == i
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (page == i)
                                    Icon(Icons.circle, size: 5, color: sage),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    const SizedBox(height: 18),
                    Text(
                      '●  A little teamwork. A happier home.',
                      style: TextStyle(color: muted, fontSize: 8),
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
                  if (store.demo || store.offline)
                    Container(
                      width: double.infinity,
                      color: mintSoft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            store.offline
                                ? Icons.offline_bolt_outlined
                                : Icons.science_outlined,
                            size: 15,
                            color: sage,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              store.offline
                                  ? 'Offline mode · chores are saved on this device'
                                  : 'Demo home · changes reset when you leave',
                              style: TextStyle(fontSize: 11, color: sage),
                            ),
                          ),
                          InkWell(
                            onTap: () => run(store.signOut),
                            child: Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                store.offline
                                    ? 'Exit offline mode'
                                    : 'Exit demo',
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
              backgroundColor: surface,
              indicatorColor: sage.withValues(alpha: _darkPalette ? .22 : .14),
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checklist_outlined),
                  label: 'Chores',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: Icon(Icons.add_rounded),
              label: const Text('Add chore'),
            ),
    );
  }

  Widget header(bool wide) => Container(
    height: 68,
    padding: EdgeInsets.symmetric(horizontal: wide ? 34 : 20),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (wide) ...[
          Text(
            'YOUR HOME',
            style: TextStyle(
              fontSize: 9,
              color: muted,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Text('/', style: TextStyle(color: muted)),
          ),
          Text(
            ['Overview', 'Chores', 'Household'][page],
            style: TextStyle(
              fontSize: 11,
              color: ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: sage, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'A little teamwork',
            style: TextStyle(fontSize: 10, color: muted),
          ),
          const SizedBox(width: 20),
        ] else ...[
          const DwellLogo(size: 23),
          const Spacer(),
        ],
        IconButton(
          tooltip: 'Open settings',
          onPressed: settings,
          icon: const Icon(TemplateIcons.settings, size: 21),
        ),
        if (!wide) ...[
          IconButton(
            tooltip: 'Refresh household',
            onPressed: busy ? null : () => run(store.refresh),
            icon: Icon(Icons.refresh_outlined, size: 18, color: muted),
          ),
        ] else ...[
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Refresh household',
            onPressed: busy ? null : () => run(store.refresh),
            icon: Icon(Icons.refresh_outlined, size: 18, color: muted),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 17,
            backgroundColor: sage.withValues(alpha: _darkPalette ? .18 : .12),
            child: Text(
              store.firstName.substring(0, 1).toLowerCase(),
              style: TextStyle(
                color: sage,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
        pageIntro(
          store.offline ? 'YOUR OFFLINE HOME' : 'YOUR SHARED SPACE',
          'Hey ${store.firstName},\nlet’s make home happy',
          '${store.household?['name'] ?? 'Your home'} · ${weekdays[DateTime.now().weekday - 1]}, ${DateTime.now().day} ${months[DateTime.now().month - 1]}',
          trailing: Icons.wb_sunny_outlined,
          onEyebrowTap: store.households.isEmpty || store.offline
              ? null
              : switchHousehold,
        ),
        gap(18),
        _DwellFutureCard(
          title: todayChores.isEmpty
              ? 'A little room to breathe.'
              : done == todayChores.length
              ? 'Look at you go!'
              : 'Small chores. Big difference.',
          subtitle: todayChores.isEmpty
              ? 'Your home is all caught up today.'
              : '$done chores completed today',
          progress: progress,
          onOpenChores: () => setState(() => page = 1),
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
                style: TextStyle(
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
                  color: mintSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      color: greenAccent,
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
                  color: active ? sage : surface,
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
                                  ? const Color(0xFFB9D9C0)
                                  : greenAccent
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
        pageIntro(
          'YOUR HOME',
          'A place for every chore',
          'Share the load. Keep the good energy.',
          trailing: Icons.checklist_outlined,
          onEyebrowTap: store.households.length > 1 && !store.offline
              ? switchHousehold
              : null,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['All chores', 'Assigned to me', 'Completed']
              .map(
                (label) => ChoiceChip(
                  label: Text(label, style: TextStyle(fontSize: 12)),
                  selected: filter == label,
                  onSelected: (_) => setState(() => filter = label),
                  selectedColor: leaf,
                  backgroundColor: surface,
                  side: BorderSide(
                    color: filter == label ? sage.withValues(alpha: .3) : line,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
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
        ? mintSoft
        : leaf;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: chore.done ? mintSoft : surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: busy ? null : () => editChore(chore: chore),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 8, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: line),
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(roomIcon(chore.room), size: 23, color: sage),
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
                            style: TextStyle(fontSize: 10, color: muted),
                          ),
                          Text('·', style: TextStyle(color: muted)),
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
                            Icon(Icons.repeat_rounded, size: 12, color: muted),
                        ],
                      ),
                      gap(7),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: chore.assigneeId == store.userId
                                ? leaf
                                : mintSoft,
                            child: Text(
                              chore.assigneeId == null
                                  ? '?'
                                  : store
                                        .memberName(chore.assigneeId)
                                        .substring(0, 1),
                              style: TextStyle(
                                fontSize: 8,
                                color: sage,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            store.memberName(chore.assigneeId),
                            style: TextStyle(fontSize: 10, color: muted),
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
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: heading('The home team', size: 20)),
              const SizedBox(width: 8),
              Icon(Icons.people_outline, color: sage),
            ],
          ),
          gap(7),
          caption(
            '${store.members.length} ${store.members.length == 1 ? 'person' : 'people'}, one happy home.',
          ),
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
                        : mintSoft,
                    radius: 19,
                    child: Text(
                      (member['name'] as String).substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 14, color: sage),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      store.memberName(member['id'] as String),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '$count to do',
                    style: TextStyle(fontSize: 11, color: muted),
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

  Widget householdPage() {
    if (store.offline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pageIntro(
            'YOUR OFFLINE HOME',
            'Your home, close at hand',
            'Your chores stay saved on this device.',
            trailing: Icons.offline_bolt_outlined,
          ),
          householdSummary(),
          gap(20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: leaf,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.offline_bolt_outlined, color: sage),
                gap(16),
                heading('Just for this device.', size: 23),
                gap(10),
                caption(
                  'Your chores are stored locally. Connect to a Dwell server to share a home with other people.',
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pageIntro(
          'YOUR SHARED SPACE',
          'Better under one roof',
          'Your people. Your space. Your shared rhythm.',
          trailing: Icons.people_outline,
          onEyebrowTap: store.households.length > 1 ? switchHousehold : null,
        ),
        householdSummary(),
        gap(20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: leaf,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mail_outline_rounded, color: sage),
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
                      style: TextStyle(
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
                    icon: Icon(Icons.copy_outlined, color: sage),
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
                icon: Icon(Icons.add_home_outlined, size: 18),
                label: const Text('Create home'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => groupDialog(true),
                icon: Icon(Icons.login_rounded, size: 18),
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
  }

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
          icon: Icon(Icons.add_home_outlined),
          label: const Text('Create a household'),
        ),
      ),
      gap(12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => groupDialog(true),
          icon: Icon(Icons.key_outlined),
          label: const Text('Join with an invite code'),
        ),
      ),
    ],
  );

  Widget empty(String title, String subtitle, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
    decoration: BoxDecoration(
      color: surface,
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
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        gap(7),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12, height: 1.6),
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
                  leading: Icon(Icons.home_outlined, color: sage),
                  title: Text(g['name'] as String),
                  trailing: g['id'] == store.household?['id']
                      ? Icon(Icons.check_rounded, color: sage)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    run(() => store.selectHousehold(g));
                  },
                ),
              ),
              if (!store.offline) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.add_rounded),
                  title: const Text('Create or join another home'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => page = 2);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> settings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final sheetTheme = _dwellTheme(
            _darkPalette ? Brightness.dark : Brightness.light,
          );
          final scheme = sheetTheme.colorScheme;
          final bottomInset = MediaQuery.viewPaddingOf(sheetContext).bottom;
          Widget colorModeSelector() => SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Tooltip(
                  message: 'Follow device appearance',
                  child: Icon(TemplateIcons.systemAppearance),
                ),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Tooltip(
                  message: 'Use light appearance',
                  child: Icon(TemplateIcons.lightAppearance),
                ),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Tooltip(
                  message: 'Use dark appearance',
                  child: Icon(TemplateIcons.darkAppearance),
                ),
              ),
            ],
            selected: {
              ThemeMode.values.firstWhere(
                (mode) => mode.name == store.colorMode,
                orElse: () => ThemeMode.system,
              ),
            },
            onSelectionChanged: (selection) async {
              await store.setColorMode(selection.first.name);
              setSheetState(() {});
            },
          );

          Widget section(String title, Widget child, {String? subtitle}) =>
              Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    child,
                  ],
                ),
              );
          Widget infoRow(String label, String value) => Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

          return Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
            child: Theme(
              data: sheetTheme,
              child: Material(
                color: scheme.surface,
                surfaceTintColor: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                    bottom: Radius.circular(28),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        (MediaQuery.sizeOf(sheetContext).height - bottomInset) *
                        .9,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 14, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Settings',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.6,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Tune the look and feel of your app.',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close settings',
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(TemplateIcons.close),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  section(
                                    'Color mode',
                                    colorModeSelector(),
                                    subtitle:
                                        'Follow the device or choose a theme.',
                                  ),
                                  section(
                                    'App identity',
                                    Column(
                                      children: [
                                        infoRow('Display name', 'Dwell'),
                                        const SizedBox(height: 8),
                                        infoRow(
                                          'Package ID',
                                          'com.dwell.dwell',
                                        ),
                                        const SizedBox(height: 8),
                                        infoRow('Version', appVersion),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () async {
                                                  final uri = Uri.parse(
                                                    'https://jan-lederer.github.io/Household/',
                                                  );
                                                  await launchUrl(
                                                    uri,
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                },
                                                icon: const Icon(
                                                  TemplateIcons.privacy,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Privacy policy',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              tooltip: 'Open-source licenses',
                                              onPressed: () => showLicensePage(
                                                context: sheetContext,
                                                applicationName: 'Dwell',
                                                applicationVersion: appVersion,
                                                applicationLegalese:
                                                    'Material Icons by Google. CC BY 4.0: '
                                                    'https://creativecommons.org/licenses/by/4.0/',
                                              ),
                                              icon: const Icon(
                                                TemplateIcons.licenses,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    subtitle: 'App details and links.',
                                  ),
                                  section(
                                    'Account',
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          store.user!['name'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          store.user!['email'] as String,
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: 'Your household profile.',
                                  ),
                                  section(
                                    'Household connection',
                                    Material(
                                      color: Colors.transparent,
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.dns_outlined,
                                          color: scheme.primary,
                                        ),
                                        title: const Text('Server connection'),
                                        subtitle: Text(
                                          store.offline
                                              ? 'Offline · saved on this device'
                                              : store.demo
                                              ? 'Demo preview'
                                              : store.server,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: Icon(
                                          Icons.chevron_right_rounded,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        onTap: () {
                                          Navigator.pop(sheetContext);
                                          Future<void>.delayed(
                                            const Duration(milliseconds: 180),
                                            () {
                                              if (!mounted) return;
                                              serverSheet(context, store);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    leading: Icon(
                                      Icons.logout_rounded,
                                      color: scheme.primary,
                                    ),
                                    title: Text(
                                      store.offline
                                          ? 'Exit offline mode'
                                          : store.demo
                                          ? 'Leave demo home'
                                          : 'Sign out',
                                    ),
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      run(store.signOut);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
        if (error != null) Text(error!, style: TextStyle(color: Colors.red)),
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
                    icon: Icon(TemplateIcons.close),
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
                  backgroundColor: surface,
                  padding: const EdgeInsets.all(17),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 19),
                    const SizedBox(width: 12),
                    Text('Due ${dateLabel(dayKey(due))}'),
                    const Spacer(),
                    Icon(Icons.expand_more_rounded, size: 19),
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
                Text(error!, style: TextStyle(color: Colors.red)),
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
                    icon: Icon(Icons.delete_outline, size: 18),
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

class _DwellFutureCard extends StatelessWidget {
  const _DwellFutureCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.onOpenChores,
  });

  final String title;
  final String subtitle;
  final double progress;
  final VoidCallback onOpenChores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = scheme.surfaceContainerLow;
    final glow = Color.lerp(base, scheme.primary, 0.2)!;
    final orbit = Color.lerp(base, scheme.tertiary, 0.14)!;
    final percentage = (progress * 100).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [glow, base, orbit],
            stops: const [0, 0.58, 1],
          ),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.32)),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -44,
              top: -55,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: -13,
              top: -24,
              child: Container(
                width: 136,
                height: 136,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.tertiary.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'FUTURE-READY HOME KIT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.65,
                                height: 1.12,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: onOpenChores,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 19,
                              ),
                              label: const Text('Open chores'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 66,
                        height: 66,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 5,
                                backgroundColor: scheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                color: scheme.primary,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text(
                              '$percentage%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
