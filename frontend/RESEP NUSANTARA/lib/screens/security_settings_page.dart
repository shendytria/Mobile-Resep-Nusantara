import 'package:flutter/material.dart';
import 'package:uts1/screens/profile/two_factor_auth_page.dart';

class SecuritySettingsPage extends StatelessWidget {
  final int userId = 1; // Replace with actual user ID from your authentication system

  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            onTap: () {
              // Navigate to change password page
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Two-Factor Authentication'),
            subtitle: const Text('Add an extra layer of security'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TwoFactorAuthPage(userId: userId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Manage Devices'),
            onTap: () {
              // Navigate to manage devices page
            },
          ),
        ],
      ),
    );
  }
}