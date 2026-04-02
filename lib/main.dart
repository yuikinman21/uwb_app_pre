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
      home: UwbRadarScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 1. 距離と角度をまとめたデータ用の「箱（クラス）」
class UwbData {
  final double distance; // メートル
  final double angle;    // 角度（度: -90が左、0が真正面、90が右）

  UwbData({required this.distance, required this.angle});
}

// 2. 距離と角度の「両方」を発行するダミークラス
class MockUwbService {
  Stream<UwbData> get uwbStream async* {
    final random = Random();
    double currentDistance = 3.0; // 初期値: 真正面に3m
    double currentAngle = 0.0;

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500)); 
      
      // 距離の変動（±0.5m）
      currentDistance += (random.nextDouble() - 0.5);
      if (currentDistance < 0) currentDistance = 0.0;

      // 角度の変動（±15度ずつフラフラ動く）
      currentAngle += (random.nextDouble() * 30 - 15);
      // スマホの前方180度（-90度 〜 90度）の範囲に収める
      if (currentAngle > 90) currentAngle = 90;
      if (currentAngle < -90) currentAngle = -90;
      
      // 距離と角度をセットにして画面へ通知
      yield UwbData(distance: currentDistance, angle: currentAngle);
    }
  }
}

// 3. UI（レーダーと数値の表示）
class UwbRadarScreen extends StatelessWidget {
  final MockUwbService _uwbService = MockUwbService();

  UwbRadarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UWB 空間レーダー'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: StreamBuilder<UwbData>(
          stream: _uwbService.uwbStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            // データの取り出し
            final data = snapshot.data!;
            final distance = data.distance;
            final angle = data.angle;
            
            final formattedDistance = distance.toStringAsFixed(2);
            final formattedAngle = angle.toStringAsFixed(0);
            final isClose = distance < 1.5;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- 視覚的フィードバック（ナビゲーションアイコン） ---
                Transform.rotate(
                  // Flutterの回転は「ラジアン」を使うため、度数を変換 (角度 * π / 180)
                  angle: angle * (pi / 180),
                  child: Icon(
                    Icons.navigation, // アイコン
                    size: 120, 
                    color: isClose ? Colors.red : Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 40),

                // --- 数値データの表示 ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      const Text('デバイスの位置', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Text(
                        '$formattedDistance m',
                        style: TextStyle(
                          fontSize: 60, 
                          fontWeight: FontWeight.bold,
                          color: isClose ? Colors.red : Colors.black87,
                        ),
                      ),
                      Text(
                        // 角度がマイナスなら「左」、プラスなら「右」と表示
                        angle < 0 
                          ? '左に ${angle.abs().toStringAsFixed(0)}°' 
                          : '右に $formattedAngle°',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                Text(
                  isClose ? '⚠️ 接近しています！' : '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}