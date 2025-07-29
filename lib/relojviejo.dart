
 /*
import 'package:flutter/material.dart';
import 'package:one_clock/one_clock.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  home: const MyHomePage(title: 'Flutter Demo Home Page'),
  title: 'Flutter Demo',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  ),
);

  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      ),
      body: Center(
        child: AnalogClock(
          decoration: BoxDecoration(
            border: Border.all(width: 2.0, color: Colors.black),
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          width: 150.0,
          isLive: true,
          hourHandColor: Colors.black,
          minuteHandColor: Colors.black,
          showSecondHand: true,
          numberColor: Colors.black87,
          showNumbers: true,
          showAllNumbers: false,
          textScaleFactor: 1.4,
          showTicks: false,
          showDigitalClock: false,
        ),
      ),
    );
  }
}
*/