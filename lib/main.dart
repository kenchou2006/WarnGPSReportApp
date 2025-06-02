import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Speedometer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'GPS Speedometer'),
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
  double _speed = 0.0; // in m/s
  double? _latitude;
  double? _longitude;
  String? _alertMessage;
  Timer? _alertTimer;
  late DateTime _appLaunchTime;
  static const String _lastMenuKey = 'last_menu_selection';
  static const String _customSpeedKey = 'custom_display_speed';
  double? _customDisplaySpeed;

  @override
  void initState() {
    super.initState();
    _appLaunchTime = DateTime.now();
    _requestSystemLocationPermission();
    _loadLastMenuSelection();
    _loadCustomDisplaySpeed();
  }

  Future<void> _loadLastMenuSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMenu = prefs.getString(_lastMenuKey);
    if (lastMenu == 'receive') {
      _showAlertAfter15Seconds(
          '座標：Lat: 37.421998, Lng: -122.084000 車牌：AWE-1234 之車速異常，請小心駕駛'
      );
    } else if (lastMenu == 'send') {
      _showAlertAfter15Seconds('已發送異常警報');
    }
  }

  Future<void> _saveLastMenuSelection(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastMenuKey, value);
  }

  Future<void> _loadCustomDisplaySpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final speed = prefs.getDouble(_customSpeedKey);
    if (speed != null) {
      setState(() {
        _customDisplaySpeed = speed;
      });
    }
  }

  Future<void> _saveCustomDisplaySpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_customSpeedKey, speed);
    setState(() {
      _customDisplaySpeed = speed;
    });
  }

  Future<void> _showCustomSpeedDialog() async {
    final controller = TextEditingController(
        text: _customDisplaySpeed?.toStringAsFixed(1) ?? '');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Custom Display Speed (km/h)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Enter speed in km/h'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                Navigator.of(context).pop(value);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null) {
      await _saveCustomDisplaySpeed(result);
      await _saveLastMenuSelection('custom');
    }
  }

  Future<void> _requestSystemLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog(
        'Location Service Disabled',
        'Please enable location services (GPS) on your device.',
        openSettings: true,
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationDialog(
          'Location Permission Needed',
          'Please allow this app to access your location.',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationDialog(
        'Location Permission Permanently Denied',
        'Please enable location permission in system settings.',
        openSettings: true,
      );
      return;
    }

    _initLocation();
  }

  Future<void> _initLocation() async {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      setState(() {
        _speed = position.speed;
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    });
  }

  void _showLocationDialog(String title, String content, {bool openSettings = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          if (openSettings)
            TextButton(
              onPressed: () {
                Geolocator.openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (!openSettings) {
                _requestSystemLocationPermission();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAlertAfter15Seconds(String message) {
    _alertTimer?.cancel();
    final elapsed = DateTime.now().difference(_appLaunchTime).inSeconds;
    final delay = Duration(seconds: (15 - elapsed).clamp(0, 15));
    _alertTimer = Timer(delay, () {
      setState(() {
        _alertMessage = message;
      });
    });
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double speedKmh = (_speed * 3.6);
    final displaySpeed = _customDisplaySpeed ?? speedKmh;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'receive') {
                await _saveLastMenuSelection(value);
                _showAlertAfter15Seconds(
                    '座標：Lat: 37.421998, Lng: -122.084000 車牌：AWE-1234 之車速異常，請小心駕駛'
                );
              } else if (value == 'send') {
                await _saveLastMenuSelection(value);
                _showAlertAfter15Seconds('已發送異常警報');
              } else if (value == 'custom') {
                await _showCustomSpeedDialog();
              } else if (value == 'clean') {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_lastMenuKey, value);
                await prefs.remove(_customSpeedKey);
                setState(() {
                  _customDisplaySpeed = null;
                  _alertMessage = null;
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'receive',
                child: Text('模擬接收警示'),
              ),
              const PopupMenuItem(
                value: 'send',
                child: Text('模擬發送警示'),
              ),
              const PopupMenuItem(
                value: 'custom',
                child: Text('自訂顯示時速'),
              ),
              const PopupMenuItem(
                value: 'clean',
                child: Text('清除模擬警示'),
              ),
            ],
          ),
        ],
      ),
      body: Align(
        alignment: const Alignment(0, -0.7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Current Speed',
              style: TextStyle(fontSize: 28),
            ),
            Text(
              displaySpeed.toStringAsFixed(1),
              style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
            ),
            const Text(
              'km/h',
              style: TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 40),
            const Text(
              'Current Position',
              style: TextStyle(fontSize: 24),
            ),
            Text(
              _latitude != null && _longitude != null
                  ? 'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}'
                  : 'Locating...',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 40),
            if (_alertMessage != null)
              Text(
                _alertMessage!,
                style: const TextStyle(fontSize: 18, color: Colors.red),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}