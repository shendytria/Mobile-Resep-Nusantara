import 'package:flutter/material.dart';
import 'package:uts1/services/auth_service.dart';

class LogoutDialog extends StatelessWidget {
  final Function()? onLogoutConfirmed;

  const LogoutDialog({Key? key, this.onLogoutConfirmed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Logout"),
      content: const Text("Apa kamu yakin ingin logout?"),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
          },
          child: const Text("Batal"),
        ),
        TextButton(
          onPressed: () async {
            try {
              // Jalankan logout
              await AuthService.logout();
              // Tutup dialog setelah logout berhasil
              Navigator.of(context).pop();
              // Navigasi ke halaman login
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            } catch (e) {
              // Tampilkan error jika logout gagal
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal logout: $e'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.of(context).pop(); // Tutup dialog jika gagal
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text("Logout"),
        ),
      ],
    );
  }
}