import 'dart:async';
import 'dart:math';
import 'dart:io';
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
      home: const UwbRadarScreen(),
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

      // 水平角度の変動
      currentAzimuth += (random.nextDouble() * 4 - 2);
      if (currentAzimuth > 180) currentAzimuth -= 360;
      if (currentAzimuth < -180) currentAzimuth += 360;

      // 垂直角度（上下）の変動：-90度（真下）〜 90度（真上）
      currentElevation += (random.nextDouble() * 2 - 1);
      if (currentElevation > 90) currentElevation = 90;
      if (currentElevation < -90) currentElevation = -90;

      // 【重要】アンテナの指向性シミュレーション
      // デバイスが視界（正面の左右60度以内）から外れると、方向(角度)を見失う(nullになる)
      bool isDirectionAvailable = currentAzimuth.abs() <= 60;

      yield UwbData(
        deviceId: mockDeviceId,
        distance: currentDistance,
        // 方向を見失った場合は null を返す
        azimuth: isDirectionAvailable ? currentAzimuth : null,
        elevation: isDirectionAvailable ? currentElevation : null,
      );
    }
  }
}

// 3. UI画面
class UwbRadarScreen extends StatefulWidget {
  const UwbRadarScreen({super.key});

  @override
  State<UwbRadarScreen> createState() => _UwbRadarScreenState();
}

class _UwbRadarScreenState extends State<UwbRadarScreen> {
  final MockUwbService _uwbService = MockUwbService();
  StreamSubscription<UwbData>? _streamSubscription;
  UwbData? _currentData; // 画面表示用の最新データ

  // --- 記録用の状態管理変数 ---
  bool _isRecording = false;
  List<String> _csvRows = []; // メモリ上でCSVデータを蓄積するリスト
  List<File> _csvFiles = [];  // 保存済みのCSVファイルリスト

  @override
  void initState() {
    super.initState();
    _loadHistory(); // 起動時に過去のCSVファイルを探す

    // StreamBuilderの代わりに手動でStreamを監視し、表示更新とデータ記録を同時に行う
    _streamSubscription = _uwbService.uwbStream.listen((data) {
      setState(() {
        _currentData = data;
      });

      // 記録中なら、CSVの行としてデータを追加
      if (_isRecording) {
        final timestamp = DateTime.now().millisecondsSinceEpoch; // Unixタイムスタンプ
        // 欠損値(null)の場合は空文字として記録
        _csvRows.add('$timestamp,${data.deviceId},${data.distance},${data.azimuth ?? ""},${data.elevation ?? ""}');
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  // アプリ内ディレクトリから既存のCSVを探すメソッド
  Future<void> _loadHistory() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.csv'))
        .toList();
    setState(() {
      _csvFiles = files;
    });
  }

  // --- 記録開始ボタンの処理 ---
  void _startRecording() {
    setState(() {
      _isRecording = true;
      _csvRows.clear();
      // 1行目にヘッダーを追加
      _csvRows.add('timestamp,device_id,distance,azimuth,elevation');
    });
  }

  // --- 記録終了ボタンの処理 ---
  Future<void> _stopRecording() async {
    setState(() {
      _isRecording = false;
    });

    if (_csvRows.isEmpty) return;

    // ファイルの保存処理
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/uwb_log_$timestamp.csv');

    // リストに溜めた文字列を改行で繋いで一気に書き込む
    await file.writeAsString(_csvRows.join('\n'));

    setState(() {
      _csvFiles.add(file); // 履歴リストに追加
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSVを保存しました\n${file.path.split('/').last}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Interaction Mock'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      // データが来るまではローディング表示
      body: Center(
        child: _currentData == null 
          ? const CircularProgressIndicator()
          : _buildBody(_currentData!),
      ),
    );
  }

  // 画面のメイン要素
  Widget _buildBody(UwbData data) {
    final formattedDistance = data.distance.toStringAsFixed(2);
    final hasDirection = data.azimuth != null && data.elevation != null;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // --- デバイス情報 ---
          Text('Target: ${data.deviceId}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          // --- 視覚的フィードバックエリア ---
          SizedBox(
            height: 200,
            child: hasDirection 
              ? _buildDirectionalUI(data.azimuth!, data.elevation!, data.distance)
              : _buildLostDirectionUI(), 
          ),
          const SizedBox(height: 30),

          // --- 数値データの詳細表示 ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                const Text('距離 (Distance)', style: TextStyle(color: Colors.grey)),
                Text('$formattedDistance m', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAngleText('水平 (左右)', data.azimuth),
                    _buildAngleText('垂直 (上下)', data.elevation),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // ==========================================
          // ここからが追加したボタンの出し分けUI
          // ==========================================
          
          if (_isRecording)
            ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop),
              label: const Text('記録終了して保存'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('記録開始'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),

          const SizedBox(height: 15),

          // 記録中ではなく、かつ保存済みのCSVファイルが存在する場合のみ表示
          if (!_isRecording && _csvFiles.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                // TODO: 履歴一覧・プレビュー画面への遷移処理
                // 今回は簡易的に件数をスナックバーで表示
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('保存済みのCSVファイル: ${_csvFiles.length}件')),
                );
              },
              icon: const Icon(Icons.folder),
              label: const Text('記録履歴確認'),
            ),
        ],
      ),
    );
  }

  // --- 既存のUIウィジェットメソッド ---
  Widget _buildDirectionalUI(double azimuth, double elevation, double distance) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          elevation > 10 ? Icons.arrow_drop_up : (elevation < -10 ? Icons.arrow_drop_down : Icons.horizontal_rule),
          color: Colors.orange,
          size: 40,
        ),
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