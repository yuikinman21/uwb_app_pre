import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

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
      home: UwbDistanceScreen(),
      debugShowCheckedModeBanner: false, // 右上の「DEBUG」リボンを消す
    );
  }
}

class MockUwbService {
  Stream<double> get distanceStream async* {
    final random = Random();
    double currentDistance = 3.0; // 初期値3メートル

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500)); // 0.5秒ごとに更新
      
      // -0.5m 〜 +0.5m の範囲で距離がランダムに変動するダミーロジック
      double change = (random.nextDouble() - 0.5); 
      currentDistance += change;
      
      // 0m以下にならないように調整
      if (currentDistance < 0) currentDistance = 0.0;
      
      yield currentDistance; // 画面側に距離を通知
    }
  }
}

class UwbDistanceScreen extends StatelessWidget {
  final MockUwbService _uwbService = MockUwbService();

  UwbDistanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UWBレーダー（テスト版）'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: StreamBuilder<double>(
          stream: _uwbService.distanceStream, // ダミーの距離データを受信
          builder: (context, snapshot) {
            // データがまだ来ていない時のロード画面
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            // 受信した距離データ（小数点2桁まで丸める）
            final distance = snapshot.data!;
            final formattedDistance = distance.toStringAsFixed(2);
            
            // 1.5m以内かどうかを判定
            final isClose = distance < 1.5;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.radar, 
                  size: 100, 
                  color: isClose ? Colors.red : Colors.blueGrey,
                ),
                const SizedBox(height: 20),
                const Text(
                  'デバイスまでの距離', 
                  style: TextStyle(fontSize: 24, color: Colors.grey)
                ),
                const SizedBox(height: 10),
                Text(
                  '$formattedDistance m',
                  style: TextStyle(
                    fontSize: 72, 
                    fontWeight: FontWeight.bold,
                    // 1.5m以内なら文字を赤く、それ以外は黒にする
                    color: isClose ? Colors.red : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isClose ? '⚠️ 接近しています！' : '安全な距離です',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isClose ? Colors.red : Colors.transparent, // 遠い時は見えなくする
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}