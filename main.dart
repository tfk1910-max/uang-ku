import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'common.dart';
import 'screens/assets.dart';
import 'screens/budget.dart';
import 'screens/dashboard.dart';
import 'screens/more.dart';
import 'screens/settings.dart';
import 'screens/transactions.dart';
import 'screens/txn_editor.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(const UangkuApp());
}

class UangkuApp extends StatefulWidget {
  const UangkuApp({super.key});
  @override
  State<UangkuApp> createState() => _UangkuAppState();
}

class _UangkuAppState extends State<UangkuApp> with WidgetsBindingObserver {
  bool locked = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && store.hasPin) setState(() => locked = true);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Uangku',
        debugShowCheckedModeBanner: false,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: brand),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xfff5f7f6),
        ),
        builder: (context, child) => ListenableBuilder(
          listenable: store,
          builder: (ctx, _) => Stack(children: [
            child ?? const SizedBox.shrink(),
            if (store.loaded && store.hasPin && locked)
              Positioned.fill(child: LockScreen(onUnlock: () => setState(() => locked = false))),
          ]),
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => Observe((context) {
        if (!store.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return Scaffold(
          body: SafeArea(
            child: IndexedStack(index: tab, children: [
              DashboardPage(onSeeAll: () => setState(() => tab = 1)),
              const TransactionsPage(),
              const BudgetPage(),
              const AssetsPage(),
              const MorePage(),
            ]),
          ),
          floatingActionButton: tab <= 1
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxnEditorPage())),
                  icon: const Icon(Icons.add),
                  label: const Text('Transaksi'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Beranda'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transaksi'),
              NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Anggaran'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Aset'),
              NavigationDestination(icon: Icon(Icons.menu), label: 'Lainnya'),
            ],
          ),
        );
      });
}
