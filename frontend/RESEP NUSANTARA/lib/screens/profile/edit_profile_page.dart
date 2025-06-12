import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool isLoading = true;
  bool isSaving = false;
  bool _showPasswordFields = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? profilePictureUrl;
  XFile? _pickedImage;
  int? userId;
  String? authToken;

  final String baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserToken();
  }

  Future<void> _loadUserToken() async {
    try {
      print('Attempting to load auth token...');
      final token = await AuthService.getToken();

      if (token == null) {
        print('No token found in AuthService');
        _showError('No authentication token found. Please login again.');
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      setState(() {
        authToken = token;
      });

      print('Token loaded: $authToken');
      await fetchUserData();
    } catch (e) {
      print('Error in _loadUserToken: $e');
      _showError('Authentication error: ${e.toString()}');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      print('Fetch user data response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final userData = data['data']['user'];

          await AuthService.setUserData(userData);

          setState(() {
            userId = userData['user_id'];
            emailController.text = userData['email'] ?? '';
            usernameController.text = userData['username'] ?? '';
            profilePictureUrl = userData['profile_picture'] ?? 'images/default_profile.jpg';
            isLoading = false;
          });
        } else {
          throw Exception('Failed to load user data: ${data['message'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 401) {
        _showError('Your session has expired. Please login again.');
        await AuthService.clearAuthData();
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        throw Exception('Failed to load user data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        isLoading = false;
      });
      _showError('Error: ${e.toString()}');
    }
  }

  bool _validatePasswordFields() {
    if (!_showPasswordFields) return true;

    if (oldPasswordController.text.isEmpty) {
      _showError('Password lama harus diisi');
      return false;
    }

    if (newPasswordController.text.isEmpty) {
      _showError('Password baru harus diisi');
      return false;
    }

    if (newPasswordController.text.length < 8) {
      _showError('Password baru minimal 8 karakter');
      return false;
    }

    if (newPasswordController.text != confirmPasswordController.text) {
      _showError('Konfirmasi password tidak cocok');
      return false;
    }

    return true;
  }

  Future<void> updateProfile() async {
    if (!_validatePasswordFields()) return;

    setState(() {
      isSaving = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/user/$userId?_method=PUT'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      });

      // Tambahkan field teks
      request.fields['email'] = emailController.text;
      request.fields['username'] = usernameController.text;

      if (_showPasswordFields && newPasswordController.text.isNotEmpty) {
        request.fields['old_password'] = oldPasswordController.text;
        request.fields['password'] = newPasswordController.text;
        request.fields['password_confirmation'] = confirmPasswordController.text;
        print('Sending password fields: old_password=${oldPasswordController.text}, password=${newPasswordController.text}, password_confirmation=${confirmPasswordController.text}');
      } else {
        print('No password fields sent');
      }

      // Tambahkan file gambar jika ada
      if (_pickedImage != null && !kIsWeb) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_picture',
          _pickedImage!.path,
        ));
        print('Adding profile picture file: ${_pickedImage!.path}');
      } else if (_pickedImage != null && kIsWeb) {
        final bytes = await _pickedImage!.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'profile_picture',
          bytes,
          filename: _pickedImage!.name,
        ));
        print('Adding profile picture file (web): ${_pickedImage!.name}');
      }

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      print('Update profile response: ${response.statusCode} - ${responseBody.body}');

      setState(() {
        isSaving = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(responseBody.body);

        if (data['success'] == true) {
          final userData = await AuthService.getUserData() ?? {};
          userData['email'] = emailController.text;
          userData['username'] = usernameController.text;
          if (data['data']['user']['profile_picture'] != null) {
            userData['profile_picture'] = data['data']['user']['profile_picture'];
            setState(() {
              profilePictureUrl = data['data']['user']['profile_picture'];
            });
          }
          await AuthService.setUserData(userData);

          _showSuccess('Profile berhasil diperbarui');

          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pop(context, true);
          });
        } else {
          throw Exception('Failed to update profile: ${data['message'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 401) {
        _showError('Your session has expired. Please login again.');
        await AuthService.clearAuthData();
        Navigator.of(context).pushReplacementNamed('/login');
      } else if (response.statusCode == 422) {
        final data = json.decode(responseBody.body);
        final errorMessage = data['message'] ?? 'Validation error';
        final errors = data['errors'] ?? {};
        print('Validation errors: $errors');
        _showError(errorMessage);
      } else if (response.statusCode == 403) {
        _showError('Tidak diizinkan untuk memperbarui profil ini');
      } else {
        throw Exception('Failed to update profile. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating profile: $e');
      setState(() {
        isSaving = false;
      });
      _showError('Error: ${e.toString()}');
    }
  }

  Future<void> selectProfilePicture() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _pickedImage = image;
          profilePictureUrl = kIsWeb ? null : image.path; // Tampilkan pratinjau di mobile
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showError('Gagal memilih gambar: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool? showSuffixIcon,
    VoidCallback? onSuffixPressed,
    String? hintText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF0D5C46)),
          suffixIcon: showSuffixIcon == true
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey[600],
                  ),
                  onPressed: onSuffixPressed,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0D5C46), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF0D5C46),
        ),
        title: const Text(
          "Edit Profil",
          style: TextStyle(
            color: Color(0xFF0D5C46),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D5C46)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture Section
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[200],
                            child: _pickedImage != null && !kIsWeb
                                ? ClipOval(
                                    child: Image.file(
                                      File(_pickedImage!.path),
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: profilePictureUrl ?? 'images/default_profile.jpg',
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const CircularProgressIndicator(),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.person,
                                      size:60,
                                      color: Colors.grey[600],
                                    ),
                                    imageBuilder: (context, imageProvider) => Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D5C46),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: selectProfilePicture,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Profile Information Section
                  const Text(
                    'Informasi Profil',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D5C46),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: emailController,
                    labelText: 'Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  _buildTextField(
                    controller: usernameController,
                    labelText: 'Username',
                    prefixIcon: Icons.person_outline,
                  ),

                  const SizedBox(height: 24),

                  // Password Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ubah Password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D5C46),
                        ),
                      ),
                      Switch(
                        value: _showPasswordFields,
                        onChanged: (value) {
                          setState(() {
                            _showPasswordFields = value;
                            if (!value) {
                              oldPasswordController.clear();
                              newPasswordController.clear();
                              confirmPasswordController.clear();
                            }
                          });
                        },
                        activeColor: const Color(0xFF0D5C46),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_showPasswordFields) ...[
                    _buildTextField(
                      controller: oldPasswordController,
                      labelText: 'Password Lama',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscureOldPassword,
                      showSuffixIcon: true,
                      onSuffixPressed: () {
                        setState(() {
                          _obscureOldPassword = !_obscureOldPassword;
                        });
                      },
                    ),

                    _buildTextField(
                      controller: newPasswordController,
                      labelText: 'Password Baru',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscureNewPassword,
                      showSuffixIcon: true,
                      onSuffixPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                      hintText: 'Minimal 8 karakter',
                    ),

                    _buildTextField(
                      controller: confirmPasswordController,
                      labelText: 'Konfirmasi Password Baru',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscureConfirmPassword,
                      showSuffixIcon: true,
                      onSuffixPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D5C46),
                        disabledBackgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: isSaving
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.0,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Menyimpan...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Perbarui Profil',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}