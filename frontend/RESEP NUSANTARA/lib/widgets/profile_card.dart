import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String? profilePictureUrl;
  final VoidCallback onEditPressed;

  const ProfileCard({
    Key? key,
    required this.name,
    required this.email,
    this.profilePictureUrl,
    required this.onEditPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              backgroundImage: profilePictureUrl != null
                  ? NetworkImage(profilePictureUrl!)
                  : null,
              child: profilePictureUrl == null
                  ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D5C46),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onEditPressed,
              icon: const Icon(Icons.edit, color: Color(0xFF0D5C46)),
              label: const Text(
                "Edit Profil",
                style: TextStyle(color: Color(0xFF0D5C46)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0D5C46)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}