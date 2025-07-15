import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_va1/pages/login_screen.dart';
import 'package:project_va1/pages/gyroscope_page.dart';
import 'package:project_va1/pages/gyro_with_rating_page.dart';
import 'package:google_fonts/google_fonts.dart';

class TrainSplashScreen extends StatelessWidget {
  const TrainSplashScreen({super.key});

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void showPositionDialog(BuildContext context, Function(String) onSelected) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('เลือกตำแหน่งในขบวน'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('หัวขบวน'),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected('หัวขบวน');
                  },
                ),
                ListTile(
                  title: const Text('กลางขบวน'),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected('กลางขบวน');
                  },
                ),
                ListTile(
                  title: const Text('ท้ายขบวน'),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected('ท้ายขบวน');
                  },
                ),
              ],
            ),
          ),
    );
  }

  void goToGyroscopePage(BuildContext context) {
    showPositionDialog(context, (position) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GyroscopePage(position: position),
        ),
      );
    });
  }

  void goToGyroWithRatingPage(BuildContext context) {
    showPositionDialog(context, (position) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GyroWithRatingPage(position: position),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPink = Color(0xFFEC407A);
    const Color secondaryPink = Color(0xFFF48FB1);
    const Color bgPink = Color(0xFFFFF0F5);

    return Scaffold(
      backgroundColor: bgPink,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_subway_filled_rounded,
              size: 100,
              color: primaryPink,
            ),
            const SizedBox(height: 30),
            Text(
              'รถไฟฟ้าสายสีชมพู',
              style: GoogleFonts.sarabun(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryPink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'BTS Pink Line',
              style: GoogleFonts.sarabun(fontSize: 18, color: secondaryPink),
            ),
            const SizedBox(height: 40),

            // AI MODE button
            ElevatedButton.icon(
              onPressed: () => goToGyroscopePage(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.smart_toy, color: Colors.white),
              label: Text(
                'AI MODE',
                style: GoogleFonts.sarabun(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 15),

            // MANUAL MODE button
            ElevatedButton.icon(
              onPressed: () => goToGyroWithRatingPage(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryPink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.edit_note, color: Colors.white),
              label: Text(
                'MANUAL MODE',
                style: GoogleFonts.sarabun(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 25),

            TextButton(
              onPressed: () => logout(context),
              child: Text(
                'ออกจากระบบ',
                style: GoogleFonts.sarabun(
                  fontSize: 16,
                  color: Colors.red.shade400,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
