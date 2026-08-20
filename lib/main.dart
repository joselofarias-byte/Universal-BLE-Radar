import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

import 'features/radar/domain/radar_guidance.dart';
import 'features/radar/domain/radar_signal_model.dart';
import 'features/radar/domain/target_presence_tracker.dart';

const Color kBgColor = Color(0xFF000000);
const Color kCardColor = Color(0xFF1C1C1E);
const Color kPrimaryGreen = Color(0xFF32D74B);
const Color kCriticalRed = Color(0xFFFF453A);
const Color kNeutralGrey = Color(0xFF8E8E93);
const Color kTextPrimary = Colors.white;
const Color kTextSecondary = Color(0xFF8E8E93);

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SignalRadarApp());
}

class SignalRadarApp extends StatelessWidget {
  const SignalRadarApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: kBgColor,
          primaryColor: kPrimaryGreen,
          cardColor: kCardColor,
        ),
        home: const RadarScreen(),
      );
}

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  ScanResult? _targetDevice;
  double? _heading = 0;
  double _smoothedRssi = -100;
  Timer? _feedbackTimer;
  double _lastRssi = -100;
  IconData _directionIcon = Icons.accessibility_new;
  Color _directionColor = kNeutralGrey;
  String _directionText = 'Muévete para comparar la señal';
  double _motionIntensity = 0;
  RadarGuidance? _guidance;
  SectorRssiAccumulator _sectorAccumulator = SectorRssiAccumulator();
  TargetPresenceTracker _presenceTracker = TargetPresenceTracker();

  final Map<int, String> _vendorMap = {
    76: 'Apple Inc.',
    117: 'Samsung',
    6: 'Microsoft',
    224: 'Google',
    89: 'Nordic',
  };

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  Future<void> _initSensors() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (Platform.isAndroid &&
        await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      await FlutterBluePlus.turnOn();
    }
    _toggleScan(forceStart: true);
    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() => _scanResults = results);
      if (_targetDevice != null) {
        try {
          _updateTracking(results.firstWhere(
            (r) => r.device.remoteId == _targetDevice?.device.remoteId,
          ));
        } catch (_) {}
      }
    });
    userAccelerometerEventStream().listen((event) {
      if (mounted) {
        setState(() =>
            _motionIntensity = event.x.abs() + event.y.abs() + event.z.abs());
      }
    });
    FlutterCompass.events?.listen((event) {
      if (mounted) setState(() => _heading = event.heading);
    });
  }

  void _updateTracking(ScanResult result) {
    final now = DateTime.now();
    final currentRssi = result.rssi;
    _presenceTracker.markSeen(now);

    if (_smoothedRssi == -100) _smoothedRssi = currentRssi.toDouble();
    _smoothedRssi = RadarMath.ema(_smoothedRssi, currentRssi.toDouble());

    final heading = _heading;
    if (heading != null && heading.isFinite) {
      _sectorAccumulator.add(headingDegrees: heading, rssi: currentRssi);
      _guidance = RadarGuidance.evaluate(
        estimate: _sectorAccumulator.strongestEstimate(),
        presence: _presenceTracker.stateAt(now),
        currentHeadingDegrees: heading,
      );
    } else {
      _guidance = null;
    }

    final guidance = _guidance;
    if (guidance?.isActionable == true) {
      switch (guidance!.direction) {
        case RadarTurnDirection.aligned:
          _directionIcon = Icons.arrow_upward;
          _directionColor = kPrimaryGreen;
          _directionText = 'RUMBO CON MEJOR SEÑAL';
          _triggerHaptic(80);
        case RadarTurnDirection.left:
          _directionIcon = Icons.turn_left;
          _directionColor = kPrimaryGreen;
          _directionText = 'GIRA A LA IZQUIERDA';
        case RadarTurnDirection.right:
          _directionIcon = Icons.turn_right;
          _directionColor = kPrimaryGreen;
          _directionText = 'GIRA A LA DERECHA';
        case RadarTurnDirection.unknown:
          break;
      }
      return;
    }

    if (_smoothedRssi > -45) {
      _directionIcon = Icons.check_circle;
      _directionColor = kPrimaryGreen;
      _directionText = 'SEÑAL MUY FUERTE';
      _triggerHaptic(50);
      return;
    }
    if (_motionIntensity < 1.2) {
      _directionIcon = Icons.directions_walk;
      _directionColor = kNeutralGrey;
      _directionText = 'Muévete y gira para comparar sectores';
      return;
    }
    if (_smoothedRssi > _lastRssi + 1.5) {
      _directionIcon = Icons.arrow_upward;
      _directionColor = kPrimaryGreen;
      _directionText = 'SEÑAL MEJORANDO';
      _triggerHaptic(100);
    } else if (_smoothedRssi < _lastRssi - 1.5) {
      _directionIcon = Icons.arrow_downward;
      _directionColor = kCriticalRed;
      _directionText = 'SEÑAL EMPEORANDO';
      _triggerHaptic(300);
    }
    _lastRssi = _smoothedRssi;
  }

  String _proximityLabel(double rssi) {
    if (rssi >= -50) return 'SEÑAL MUY FUERTE';
    if (rssi >= -65) return 'SEÑAL FUERTE';
    if (rssi >= -78) return 'SEÑAL MEDIA';
    return 'SEÑAL DÉBIL';
  }

  String _confidenceLabel() {
    final confidence = _guidance?.confidence ?? 0;
    return '${(confidence * 100).round()}%';
  }

  void _triggerHaptic(int duration) async {
    if (_feedbackTimer?.isActive == true) return;
    _feedbackTimer = Timer(const Duration(milliseconds: 600), () async {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: duration);
      }
    });
  }

  String _getName(ScanResult r) {
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    final mData = r.advertisementData.manufacturerData;
    if (mData.isNotEmpty && _vendorMap.containsKey(mData.keys.first)) {
      return '${_vendorMap[mData.keys.first]}';
    }
    return 'Dispositivo desconocido';
  }

  Future<void> _toggleScan({bool forceStart = false}) async {
    try {
      if (_isScanning && !forceStart) {
        await FlutterBluePlus.stopScan();
        if (mounted) setState(() => _isScanning = false);
      } else {
        await FlutterBluePlus.startScan(
          timeout: const Duration(minutes: 15),
          continuousUpdates: true,
        );
        if (mounted) setState(() => _isScanning = true);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final closeDevices = _scanResults.where((r) => r.rssi > -65).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    final farDevices = _scanResults.where((r) => r.rssi <= -65).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SignalRadar',
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: kTextPrimary)),
                      _isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: kPrimaryGreen))
                          : IconButton(
                              icon: const Icon(Icons.refresh,
                                  color: kPrimaryGreen),
                              onPressed: () => _toggleScan(forceStart: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                if (closeDevices.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('SEÑAL FUERTE',
                        style: TextStyle(
                            color: kPrimaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: closeDevices.length,
                      itemBuilder: (c, i) => _buildCircleItem(closeDevices[i]),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('OTRAS SEÑALES',
                      style: TextStyle(
                          color: kTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: farDevices.length,
                    itemBuilder: (c, i) => _buildListItem(farDevices[i]),
                  ),
                ),
              ],
            ),
          ),
          if (_targetDevice != null) _buildFinderScreen(),
        ],
      ),
    );
  }

  Widget _buildCircleItem(ScanResult r) => GestureDetector(
        onTap: () => _startTracking(r),
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(right: 15),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kPrimaryGreen, width: 3),
                    color: kCardColor),
                child: const Icon(Icons.radar, color: kPrimaryGreen),
              ),
              const SizedBox(height: 8),
              Text(_getName(r),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: kTextPrimary)),
            ],
          ),
        ),
      );

  Widget _buildListItem(ScanResult r) => ListTile(
        onTap: () => _startTracking(r),
        leading: const Icon(Icons.bluetooth, color: Colors.grey),
        title: Text(_getName(r), style: const TextStyle(color: Colors.white)),
        subtitle: Text(r.device.remoteId.str,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        trailing: Text('${r.rssi} dBm',
            style: const TextStyle(color: Colors.grey)),
      );

  void _startTracking(ScanResult r) {
    FlutterBluePlus.stopScan()
        .then((_) => FlutterBluePlus.startScan(continuousUpdates: true));
    setState(() {
      _targetDevice = r;
      _smoothedRssi = -100;
      _lastRssi = -100;
      _guidance = null;
      _sectorAccumulator = SectorRssiAccumulator();
      _presenceTracker = TargetPresenceTracker();
      _directionText = 'Muévete y gira para comparar sectores';
      _directionColor = kNeutralGrey;
      _directionIcon = Icons.directions_walk;
    });
  }

  Widget _buildFinderScreen() {
    final currentMatch = _scanResults.firstWhere(
      (r) => r.device.remoteId == _targetDevice?.device.remoteId,
      orElse: () => _targetDevice!,
    );
    final headingText =
        _heading == null ? 'N/A' : '${_heading!.toStringAsFixed(1)}°';
    final uuids = currentMatch.advertisementData.serviceUuids.isEmpty
        ? 'Ninguno'
        : currentMatch.advertisementData.serviceUuids.join(', ');
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () {
                      _feedbackTimer?.cancel();
                      setState(() => _targetDevice = null);
                    },
                  ),
                  Column(
                    children: [
                      const Text('OBJETIVO',
                          style: TextStyle(
                              color: kTextSecondary,
                              fontSize: 10,
                              letterSpacing: 2)),
                      Text(_getName(currentMatch),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ],
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _directionColor.withValues(alpha: .1),
                border: Border.all(color: _directionColor, width: 2),
              ),
              padding: const EdgeInsets.all(40),
              child: Icon(_directionIcon, size: 120, color: _directionColor),
            ),
            const SizedBox(height: 30),
            Text(_proximityLabel(_smoothedRssi),
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _directionColor)),
            const SizedBox(height: 8),
            Text('${_smoothedRssi.toStringAsFixed(1)} dBm',
                style: const TextStyle(fontSize: 20, color: kTextSecondary)),
            const SizedBox(height: 6),
            Text('Confianza direccional: ${_confidenceLabel()}',
                style: const TextStyle(fontSize: 13, color: kTextSecondary)),
            const SizedBox(height: 10),
            Text(_directionText,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    color: _directionColor,
                    fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              child: Text(
                'La guía compara RSSI por sectores de rumbo; no representa una distancia física exacta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: kTextSecondary),
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DATOS DE SEÑAL',
                      style: TextStyle(
                          color: kPrimaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white10),
                  _buildRow('MAC', currentMatch.device.remoteId.str),
                  _buildRow('RSSI', '${currentMatch.rssi} dBm'),
                  _buildRow('RUMBO', headingText),
                  _buildRow('CONFIANZA', _confidenceLabel()),
                  _buildRow('UUIDs', uuids),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: kTextSecondary, fontSize: 12)),
            Expanded(
              child: Text(val,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }
}
