import 'package:flutter/material.dart';
import 'data/repositories/data_service.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/disclaimer_screen.dart';
import 'presentation/screens/feed_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the decentralized network connection
  await DataService.init();
  runApp(const InjusticeApp());
}

class InjusticeApp extends StatefulWidget {
  const InjusticeApp({super.key});

  @override
  State<InjusticeApp> createState() => _InjusticeAppState();
}

class _InjusticeAppState extends State<InjusticeApp> {
  bool _disclaimerAccepted = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Injustice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _disclaimerAccepted 
          ? const FeedScreen() 
          : DisclaimerScreen(onAccepted: () {
              setState(() {
                _disclaimerAccepted = true;
              });
            }),
    );
  }
}
