import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controller.dart';
import 'home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeController(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pickit2 Programmer',
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
