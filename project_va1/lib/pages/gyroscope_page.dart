import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class GyroscopePage extends StatefulWidget {
  final String position; // หัว/กลาง/ท้าย

  const GyroscopePage({super.key, required this.position});

  @override
  State<GyroscopePage> createState() => _GyroscopePageState();
}

class _GyroscopePageState extends State<GyroscopePage>
    with SingleTickerProviderStateMixin {
  String _gyroscopeData = 'กำลังรอข้อมูล...';
  bool _dialogShown = false;
  bool _isWaiting = false;
  double _maxDuringWait = 0.0;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  late AnimationController _trainController;
  late Animation<double> _trainAnimation;

  @override
  void initState() {
    super.initState();
    _trainController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _trainAnimation = Tween<double>(begin: -30, end: 30).animate(
      CurvedAnimation(parent: _trainController, curve: Curves.easeInOut),
    );

    _requestPermissionAndListen();
  }

  Future<void> _requestPermissionAndListen() async {
    if (Platform.isAndroid) {
      var status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        status = await Permission.activityRecognition.request();
      }
      if (!status.isGranted) {
        setState(() {
          _gyroscopeData = 'ไม่ได้รับอนุญาตให้ใช้เซนเซอร์';
        });
        return;
      }
    }

    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      final double x = event.x;
      final double y = event.y;
      final double z = event.z;
      final double absolute = sqrt(x * x + y * y + z * z);

      setState(() {
        _gyroscopeData =
            'X: ${x.toStringAsFixed(2)}\n'
            'Y: ${y.toStringAsFixed(2)}\n'
            'Z: ${z.toStringAsFixed(2)}\n'
            'Absolute: ${absolute.toStringAsFixed(2)}\n'
            'ตำแหน่งที่เลือก: ${widget.position}';
      });

      if (absolute > 3 && !_isWaiting && !_dialogShown) {
        _isWaiting = true;
        _maxDuringWait = absolute;
        Future.delayed(const Duration(seconds: 3), () {
          final int level = getComfortLevel(_maxDuringWait);
          if (level >= 3 && mounted) {
            _dialogShown = true;
            _showRatingDialog(level, _maxDuringWait);
          }
          _isWaiting = false;
          _maxDuringWait = 0.0;
        });
      }

      if (_isWaiting && absolute > _maxDuringWait) {
        _maxDuringWait = absolute;
      }
    });
  }

  int getComfortLevel(double n) {
    if (n < 1) return 1;
    if (n < 2) return 2;
    if (n < 4) return 3;
    if (n < 5) return 4;
    return 5;
  }

  void _showRatingDialog(int level, double absolute) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ให้คะแนนความรุนแรง (ระดับ $level)'),
          content: Text(
            'การเคลื่อนไหวเกินระดับปกติ!\n'
            'Absolute: ${absolute.toStringAsFixed(2)}\n'
            'ตำแหน่งที่เลือก: ${widget.position}\n'
            'กรุณาให้คะแนน:',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _dialogShown = false;
                _saveRating('น้อย', level, absolute);
                _showSnackBar('คุณให้คะแนน: น้อย');
              },
              child: const Text('น้อย'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _dialogShown = false;
                _saveRating('กลาง', level, absolute);
                _showSnackBar('คุณให้คะแนน: กลาง');
              },
              child: const Text('กลาง'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _dialogShown = false;
                _saveRating('มาก', level, absolute);
                _showSnackBar('คุณให้คะแนน: มาก');
              },
              child: const Text('มาก'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveRating(
    String levelText,
    int comfortLevel,
    double absolute, {
    String? comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        _showSnackBar('กรุณาเปิด GPS ก่อนใช้งาน');
      }

      Position? position;
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      if (levelText == 'สิ้นสุดการเดินทาง') {
        await FirebaseFirestore.instance.collection('AI COMMENT').add({
          'comment': comment ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'user_email': user?.email ?? 'anonymous',
          'location':
              position != null
                  ? {
                    'latitude': position.latitude,
                    'longitude': position.longitude,
                  }
                  : null,
          'train_position': widget.position,
        });
      } else {
        await FirebaseFirestore.instance.collection('AI MODE').add({
          'rating': levelText,
          'comfort_level': comfortLevel,
          'absolute_value': absolute,
          'timestamp': FieldValue.serverTimestamp(),
          'user_email': user?.email ?? 'anonymous',
          'location':
              position != null
                  ? {
                    'latitude': position.latitude,
                    'longitude': position.longitude,
                  }
                  : null,
          'train_position': widget.position,
        });
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}');
    }
  }

  void _showEndTripDialog() {
    TextEditingController _commentController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('สิ้นสุดการเดินทาง'),
            content: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'แสดงความคิดเห็นเกี่ยวกับการเดินทาง...',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveRating(
                    'สิ้นสุดการเดินทาง',
                    0,
                    0.0,
                    comment: _commentController.text,
                  );
                  _showSnackBar('บันทึกความคิดเห็นเรียบร้อย');
                },
                child: const Text('ส่ง'),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _trainController.dispose();
    _gyroscopeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เซนเซอร์ความเคลื่อนไหว'),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _trainAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_trainAnimation.value, 0),
                  child: const Icon(
                    Icons.train,
                    size: 64,
                    color: Colors.indigo,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _gyroscopeData,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showEndTripDialog,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('สิ้นสุดการเดินทาง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
