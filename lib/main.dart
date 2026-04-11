import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UWB App Mock',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: UwbRadarScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 1. UWBの取得データを格納するクラス
class UwbData {
  final String deviceId;     // デバイスの識別子
  final double distance;     // 距離（メートル）
  final double? azimuth;     // 水平角度（左右）※nullになる可能性あり
  final double? elevation;   // 垂直角度（上下）※nullになる可能性あり

  UwbData({
    required this.deviceId,
    required this.distance,
    this.azimuth,
    this.elevation,
  });
}

// 2. 本番環境をシミュレートしたモックサービス
class MockUwbService {
  Stream<UwbData> get uwbStream async* {
    final random = Random();
    const mockDeviceId = 'UWB-TAG-test'; // ダミーの識別子
    
    double currentDistance = 2.0;
    double currentAzimuth = 0.0;
    double currentElevation = 0.0;

    while (true) {
      await Future.delayed(const Duration(milliseconds: 100)); 
      
      // 距離の変動
      double randomNoise = (random.nextDouble() * 0.1 - 0.05);
      double springForce = (1.5 - currentDistance) * 0.01;
      currentDistance += (randomNoise + springForce);
      if (currentDistance < 0) currentDistance = 0.0;
      if (currentDistance > 3.0) currentDistance = 3.0;

      // 水平角度（左右）の変動：-180度（真後ろ）〜 180度まで大きく動かす
      currentAzimuth += (random.nextDouble() * 4 - 2);
      if (currentAzimuth > 180) currentAzimuth -= 360;
      if (currentAzimuth < -180) currentAzimuth += 360;

      // 垂直角度（上下）の変動：-90度（真下）〜 90度（真上）
      currentElevation += (random.nextDouble() * 2 - 1);
      if (currentElevation > 90) currentElevation = 90;
      if (currentElevation < -90) currentElevation = -90;

      yield UwbData(
        deviceId: mockDeviceId,
        distance: currentDistance,
        azimuth: currentAzimuth,
        elevation: currentElevation,
      );
    }
  }
}

// 3. 全データを視覚化するUI
class UwbRadarScreen extends StatefulWidget {
  // final MockUwbService _uwbService = MockUwbService();

  const UwbRadarScreen({super.key});

  @override
  State<UwbRadarScreen> createState() => _UwbRadarScreenState();
}

class _UwbRadarScreenState extends State<UwbRadarScreen> {
  final MockUwbService _uwbService = MockUwbService();

  StreamSubscription<UwbData>? _streamSubscription;
  UwbData? _currentData;

  bool _isRecording = false;
  DateTime? _startTime;
  final List<String> _recordedRows = [];

  @override
  void initState() {
    super.initState();
    _streamSubscription = _uwbService.uwbStream.listen((data) {
      setState(() {
        _currentData = data;
      });

      if (_isRecording && _startTime != null) {
        final now = DateTime.now();
        final relativeTimestamp = now.difference(_startTime!).inMilliseconds;
        final row = '$relativeTimestamp, ${data.deviceId}, ${data.distance}, ${data.azimuth ?? ''}, ${data.elevation ?? ''}';
        _recordedRows.add(row);
      }
    });
  }

  void _startRecording() {
    setState(() {
      _recordedRows.clear();
      _startTime = DateTime.now();
      _isRecording = true;
    });
  }

  Future<void> _stopAndSaveRecording() async {
    if(_recordedRows.isEmpty) return;

    setState(() {
      _isRecording = false;
    });

    final header = 'relative_timestamp_ms,device_id,distance_m,azimuth_deg,elevation_deg';
    final csvContent = [header, ..._recordedRows].join('\n');
    final directory = await getApplicationDocumentsDirectory();
    final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'uwb_record_$timestamp.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvContent);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recording saved: $fileName')),
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _currentData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Interaction Mock'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () {
            // ここに履歴画面へのナビゲーションを追加
          },),
        ],
      ),
      body: data == null 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Target: ${data.deviceId}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),

                // 視覚的UI
                SizedBox(
                  height: 180,
                  child: data.azimuth != null 
                    ? _buildDirectionalUI(data.azimuth!, data.elevation!, data.distance)
                    : _buildLostDirectionUI(),
                ),
                
                const SizedBox(height: 30),

                // 数値データエリア
                _buildDataCard(data),

                const SizedBox(height: 40),

                // 記録用操作ボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isRecording)
                      ElevatedButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('記録開始'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _stopAndSaveRecording,
                        icon: const Icon(Icons.stop, color: Colors.white),
                        label: const Text('記録停止・保存'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                      ),
                  ],
                ),
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('記録中: ${_recordedRows.length} 件', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildDataCard(UwbData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text('距離 (Distance)', style: TextStyle(color: Colors.grey)),
          Text('${data.distance.toStringAsFixed(2)} m', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAngleText('水平', data.azimuth),
              _buildAngleText('垂直', data.elevation),
            ],
          ),
        ],
      ),
    );
  }

  // 方向が見えている時のUI（矢印と上下のアイコン）
  Widget _buildDirectionalUI(double azimuth, double elevation, double distance) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 垂直（上下）のインジケーター
        Icon(
          elevation > 10 ? Icons.arrow_drop_up : (elevation < -10 ? Icons.arrow_drop_down : Icons.horizontal_rule),
          color: Colors.orange,
          size: 40,
        ),
        // 水平（左右）の回転矢印
        Transform.rotate(
          angle: azimuth * (pi / 180),
          child: Icon(
            Icons.navigation,
            size: 100, 
            color: distance < 1.5 ? Colors.red : Colors.blueAccent,
          ),
        ),
      ],
    );
  }

  // 方向を見失った時のUI
  Widget _buildLostDirectionUI() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.screen_rotation, size: 80, color: Colors.grey),
        SizedBox(height: 10),
        Text(
          '方向を見失いました\niPhoneを左右に振って探してください',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // 角度をテキスト表示する補助メソッド
  Widget _buildAngleText(String label, double? angle) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          angle != null ? '${angle.toStringAsFixed(1)}°' : '---',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: angle != null ? Colors.black : Colors.grey),
        ),
      ],
    );
  }
}