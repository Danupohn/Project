import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
class GyroWithRatingPage extends StatefulWidget {
 final String position;
 const GyroWithRatingPage({super.key, required this.position});
 @override
 State<GyroWithRatingPage> createState() => _GyroWithRatingPageState();
}
class _GyroWithRatingPageState extends State<GyroWithRatingPage>
   with TickerProviderStateMixin {
 bool isLoading = false;
 late AnimationController _controller;
 late Animation<double> _animation;
 late StreamSubscription<GyroscopeEvent> _gyroSub;
 double gyroMagnitude = 0.0;
 List<Map<String, dynamic>> gyroHistory = [];
 @override
 void initState() {
   super.initState();
   _controller = AnimationController(
     vsync: this,
     duration: const Duration(seconds: 4),
   )..repeat();
   _animation = Tween<double>(
     begin: -100,
     end: 300,
   ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
   _gyroSub = gyroscopeEvents.listen((GyroscopeEvent event) {
     final timestamp = DateTime.now().millisecondsSinceEpoch;
     final abs = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
     gyroMagnitude = abs;
     gyroHistory.add({
       'timestamp': timestamp,
       'x': event.x,
       'y': event.y,
       'z': event.z,
       'magnitude': abs,
     });
     gyroHistory.removeWhere((entry) =>
         timestamp - (entry['timestamp'] as int) > 5000); // เก็บย้อนหลัง 5 วิ
   });
 }
 @override
 void dispose() {
   _gyroSub.cancel();
   _controller.dispose();
   super.dispose();
 }
 Future<Position?> _getCurrentLocation() async {
  try {
    Position? lastPosition = await Geolocator.getLastKnownPosition();
    if (lastPosition != null) return lastPosition;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเปิด GPS')),
      );
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่ได้รับอนุญาตให้เข้าถึง GPS')),
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่ได้รับอนุญาตถาวรให้เข้าถึง GPS')),
      );
      return null;
    }

    // ใช้ Low accuracy เพื่อเร็วขึ้น
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 3),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ไม่สามารถดึง GPS ได้: $e')),
    );
    return null;
  }
}
 Future<void> saveRating(String rating) async {
  setState(() => isLoading = true); // <-- เริ่มแสดงโหลดเร็วขึ้น

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กรุณาล็อกอินก่อนบันทึก')),
    );
    return;
  }

  final position = await _getCurrentLocation();
  if (position == null) {
    setState(() => isLoading = false);
    return;
  }

  final timestampNow = DateTime.now().millisecondsSinceEpoch;

  final gyro5Sec = gyroHistory.where((entry) =>
      timestampNow - (entry['timestamp'] as int) <= 5000).toList();

  double maxMagnitude = 0.0;
  Map<String, dynamic>? maxEntry;

  if (gyro5Sec.isNotEmpty) {
    maxEntry = gyro5Sec.reduce((curr, next) {
      final currMag = curr['magnitude'] ?? 0.0;
      final nextMag = next['magnitude'] ?? 0.0;
      return (currMag > nextMag) ? curr : next;
    });
    maxMagnitude = maxEntry['magnitude'] ?? 0.0;
  }

  try {
    await FirebaseFirestore.instance.collection('MANUAL MODE Test').add({
      'user_email': user.email,
      'rating': rating,
      'gyro_max_5_seconds': maxMagnitude,
      'gyro_max_entry': maxEntry != null
          ? {
              'x': maxEntry['x'],
              'y': maxEntry['y'],
              'z': maxEntry['z'],
              'magnitude': maxEntry['magnitude'],
              'timestamp': maxEntry['timestamp'],
            }
          : null,
      'timestamp': FieldValue.serverTimestamp(),
      'train_position': widget.position,
      'gps': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('บันทึกความพึงพอใจ: $rating')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
    );
  }

  setState(() => isLoading = false); // <-- ปิดโหลดเมื่อเสร็จ
}

 Future<void> endJourneyWithComment(String comment) async {
   final user = FirebaseAuth.instance.currentUser;
   if (user == null) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('กรุณาล็อกอินก่อนบันทึก')),
     );
     return;
   }
   setState(() => isLoading = true);
   final position = await _getCurrentLocation();
   if (position == null) {
     setState(() => isLoading = false);
     return;
   }
   try {
     await FirebaseFirestore.instance.collection('MANUAL COMMENT').add({
       'user_email': user.email,
       'rating': 'สิ้นสุดการเดินทาง',
       'comment': comment,
       'timestamp': FieldValue.serverTimestamp(),
       'train_position': widget.position,
       'gyro_Absolute': gyroMagnitude,
     });
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('บันทึกการเดินทางเรียบร้อย')),
     );
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
     );
   }
   setState(() => isLoading = false);
 }
 void showEndJourneyDialog() {
   final TextEditingController commentController = TextEditingController();
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: const Text('สิ้นสุดการเดินทาง'),
       content: TextField(
         controller: commentController,
         maxLines: 3,
         decoration: const InputDecoration(
           hintText: 'แสดงความคิดเห็นเพิ่มเติม...',
           border: OutlineInputBorder(),
         ),
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context),
           child: const Text('ยกเลิก'),
         ),
         ElevatedButton(
           onPressed: () {
             Navigator.pop(context);
             endJourneyWithComment(commentController.text.trim());
           },
           child: const Text('บันทึก'),
         ),
       ],
     ),
   );
 }
 @override
 Widget build(BuildContext context) {
   return Scaffold(
     backgroundColor: Colors.pink[50],
     appBar: AppBar(
       title: const Text('ความพึงพอใจในการเดินทาง'),
       backgroundColor: Colors.pinkAccent,
       foregroundColor: Colors.white,
       centerTitle: true,
     ),
     body: LayoutBuilder(
       builder: (context, constraints) {
         return SingleChildScrollView(
           padding: const EdgeInsets.all(16),
           child: ConstrainedBox(
             constraints: BoxConstraints(minHeight: constraints.maxHeight),
             child: IntrinsicHeight(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   SizedBox(
                     height: 80,
                     child: AnimatedBuilder(
                       animation: _animation,
                       builder: (context, child) {
                         return Transform.translate(
                           offset: Offset(_animation.value, 0),
                           child: const Icon(
                             Icons.train,
                             size: 48,
                             color: Colors.pink,
                           ),
                         );
                       },
                     ),
                   ),
                   const SizedBox(height: 12),
                   Text(
                     'ตำแหน่งขบวน: ${widget.position}',
                     style: GoogleFonts.sarabun(
                       fontSize: 16,
                       color: Colors.pink[700],
                     ),
                   ),
                   const Divider(height: 32, color: Colors.pinkAccent),
                   Text(
                     'ความพึงพอใจของคุณ:',
                     style: GoogleFonts.sarabun(fontSize: 18),
                   ),
                   const SizedBox(height: 12),
                   Wrap(
                     alignment: WrapAlignment.center,
                     spacing: 12,
                     runSpacing: 12,
                     children: [
                       _buildRatingButton('😊', 'พอใจมาก', Colors.green[400]!),
                       _buildRatingButton('😐', 'เฉยๆ', Colors.orange[400]!),
                       _buildRatingButton('😞', 'ไม่พอใจ', Colors.red[400]!),
                     ],
                   ),
                   const Spacer(),
                   const SizedBox(height: 24),
                   isLoading
                       ? const Center(child: CircularProgressIndicator())
                       : ElevatedButton.icon(
                           onPressed: showEndJourneyDialog,
                           icon: const Icon(Icons.flag),
                           label: const Text('สิ้นสุดการเดินทาง'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.pinkAccent,
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(
                               horizontal: 24,
                               vertical: 16,
                             ),
                             textStyle: const TextStyle(fontSize: 18),
                           ),
                         ),
                   const SizedBox(height: 20),
                 ],
               ),
             ),
           ),
         );
       },
     ),
   );
 }
 Widget _buildRatingButton(String emoji, String label, Color color) {
   return ElevatedButton.icon(
     onPressed: () => saveRating(label),
     icon: Text(emoji, style: const TextStyle(fontSize: 20)),
     label: Text(label),
     style: ElevatedButton.styleFrom(
       backgroundColor: color,
       foregroundColor: Colors.white,
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
       textStyle: const TextStyle(fontSize: 16),
     ),
   );
 }
}