import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:make_me_code/models/language_enum.dart';
import 'package:make_me_code/models/realm_enum.dart';
import 'package:make_me_code/providers/engine_provider.dart';
import 'package:make_me_code/providers/theme_provider.dart';
import 'package:make_me_code/providers/upgrades_provider.dart';
import 'package:make_me_code/utils/lifecycle_event_handler.dart';
import 'package:make_me_code/utils/number_prettifier.dart';
import 'package:make_me_code/widgets/bottom_nav_bar.dart';
import 'package:make_me_code/widgets/upgrades_panel.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  final upgradesProvider = await UpgradesProvider.create();
  final themeProvider = await ThemeProvider.create();
  final engineProvider = await EngineProvider.create();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => themeProvider,
      ),
      ChangeNotifierProvider(
        create: (_) => upgradesProvider,
      ),
      ChangeNotifierProvider(
        create: (_) => engineProvider,
      ),
    ],
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Make me Code',
      theme: ThemeData(
        primaryColor: Colors.white,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      themeMode: context.watch<ThemeProvider>().themeMode,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Timer? _timer;
  int? _delay;

  Future<Timer> _setupTimer() async {
    if (_delay == null) {
      _delay = context.read<EngineProvider>().delay;
    }

    return Timer.periodic(new Duration(milliseconds: _delay!), (timer) async {
      if (_timer == null) _timer = timer;

      final delay = context.read<EngineProvider>().delay;

      await context.read<UpgradesProvider>().calculateEarnings(delay);
      await context.read<EngineProvider>().setLastIdleTime(DateTime.now());

      if (delay != _delay) {
        _delay = delay;
        _timer?.cancel();
        _timer = await _setupTimer();
      }
    });
  }

  Future<void> _calculateIdleEarnings() async {
    if (_timer == null) _timer = await _setupTimer();

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Idle earnings'),
            content: Text("While being away you've earned: "),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Great!')),
            ],
          );
        });
  }

  @override
  void initState() {
    super.initState();

    _calculateIdleEarnings();

    WidgetsBinding.instance!.addObserver(LifecycleEventHandler(
        onResume: _calculateIdleEarnings,
        onPause: () async {
          _timer?.cancel();
          _timer = null;
        }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 40,
            flexibleSpace: SafeArea(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(prettifyNumber(context
                            .watch<UpgradesProvider>()
                            .realmUpgrades
                            .realmUpgrades[
                                context.watch<EngineProvider>().selectedRealm]
                            ?.linesOfCode ??
                        0)),
                    Text(prettifyNumber(context
                                .watch<UpgradesProvider>()
                                .realmUpgrades
                                .realmUpgrades[context
                                    .watch<EngineProvider>()
                                    .selectedRealm]
                                ?.linesOfCodePerSecond ??
                            0) +
                        "/s"),
                    Text('prestige')
                  ],
                ),
              ),
            )),
        body: Column(
          children: [
            UpgradesPanel(),
          ],
        ),
        bottomNavigationBar: MyBottomNavBar());
  }
}
