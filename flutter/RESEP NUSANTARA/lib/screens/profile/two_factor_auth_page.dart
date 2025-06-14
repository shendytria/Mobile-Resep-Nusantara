import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:uts1/services/two_factor_auth_service.dart';

class TwoFactorAuthPage extends StatefulWidget {
  final int userId;

  const TwoFactorAuthPage({
    super.key,
    required this.userId,
  });

  @override
  State<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends State<TwoFactorAuthPage> {
  final TwoFactorAuthService _authService = TwoFactorAuthService();
  final Color darkGreen = const Color(0xFF0D5C46);
  bool _isEnabled = false;
  String _qrCodeUrl = '';
  String _totpUri = '';
  String _secretKey = '';
  final List<TextEditingController> _controllers = List.generate(
    6,
        (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
        (index) => FocusNode(),
  );
  bool _isVerifying = false;
  bool _isVerified = false;
  int _remainingTime = 30;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _checkTwoFactorStatus();

    // Add listeners for focus and text changes
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _controllers[i].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[i].text.length,
          );
        }
      });

      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1 && i < 5) {
          _focusNodes[i].unfocus();
          FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
        }
      });
    }
  }

  Future<void> _checkTwoFactorStatus() async {
    try {
      // Add debug print to check userId
      print('Checking 2FA status for user ID: ${widget.userId}');

      final isEnabled = await _authService.is2FAEnabled(widget.userId);

      print('2FA status response: $isEnabled');

      setState(() {
        _isEnabled = isEnabled;
        _isVerified = isEnabled;
        _isLoading = false;
      });

      // If not enabled, generate secret and QR code
      if (!isEnabled) {
        _generateSecret();
      }
    } catch (e) {
      print('Error checking 2FA status: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check 2FA status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateSecret() async {
    try {
      final result = await _authService.generateSecret(widget.userId);
      if (result['success']) {
        setState(() {
          _secretKey = result['data']['secret'];
          _qrCodeUrl = result['data']['qr_code_url'] ?? '';
          _totpUri = result['data']['totp_uri'] ?? '';

          print('Secret key generated: $_secretKey');
          print('QR Code URL: $_qrCodeUrl');
          print('TOTP URI: $_totpUri');
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to generate secret'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error generating secret: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingTime = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _remainingTime = 30;
        }
      });
    });
  }

  Future<void> _toggleTwoFactorAuth() async {
    if (_isEnabled) {
      // Disable 2FA
      setState(() {
        _isVerifying = true;
      });

      try {
        final result = await _authService.disable2FA(widget.userId);

        setState(() {
          _isVerifying = false;
          if (result) {
            _isEnabled = false;
            _isVerified = false;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Two-Factor Authentication disabled successfully!'),
                backgroundColor: darkGreen,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to disable Two-Factor Authentication'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      } catch (e) {
        print('Error disabling 2FA: $e');
        setState(() {
          _isVerifying = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // For initial setup, we're just allowing the user to proceed with verification
      setState(() {
        _isEnabled = true;
      });

      // Generate new secret if not already done
      if (_secretKey.isEmpty) {
        _generateSecret();
      }
    }
  }

  void _verifyCode() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 6) {
      setState(() {
        _isVerifying = true;
      });

      print('Verifying code: $code for user: ${widget.userId}');

      // Call API to verify and enable 2FA
      _authService.verifyAndEnable2FA(widget.userId, _secretKey, code).then((result) {
        setState(() {
          _isVerifying = false;

          if (result['success']) {
            _isVerified = true;
            _isEnabled = true;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Two-Factor Authentication enabled successfully!'),
                backgroundColor: darkGreen,
              ),
            );

            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.pop(context);
              }
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to verify code'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }).catchError((error) {
        print('Error verifying 2FA code: $error');
        setState(() {
          _isVerifying = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan 6 digit angka yang benar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copySecretKey() {
    Clipboard.setData(ClipboardData(text: _secretKey));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kunci rahasia disalin ke clipboard'),
      ),
    );
  }

  Widget _buildQRCode() {
    // If we have a TOTP URI, generate QR locally (more reliable)
    if (_totpUri.isNotEmpty) {
      print('Generating QR code from TOTP URI: $_totpUri');
      return QrImageView(
        data: _totpUri,
        version: QrVersions.auto,
        size: 200.0,
        backgroundColor: Colors.white,
      );
    }
    // Try network image as fallback
    else if (_qrCodeUrl.isNotEmpty) {
      return Image.network(
        _qrCodeUrl,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading QR from URL: $error');
          // If we don't have TOTP URI but have secret, construct one
          if (_secretKey.isNotEmpty) {
            final String constructedUri = 'otpauth://totp/ResepNusantara:user${widget.userId}@example.com?secret=$_secretKey&issuer=ResepNusantara';
            return QrImageView(
              data: constructedUri,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            );
          }

          return const Center(
            child: Icon(Icons.qr_code_2, size: 120, color: Colors.grey),
          );
        },
      );
    }
    // Fallback if we have nothing
    else {
      return const Center(
        child: Icon(Icons.qr_code_2, size: 120, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Two-Factor Authentication", style: TextStyle(color: Color(0xFF0D5C46))),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: darkGreen),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: darkGreen),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Two-Factor Authentication", style: TextStyle(color: Color(0xFF0D5C46))),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text(
                'Enable Two-Factor Authentication',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Adds an extra layer of security to your account',
                style: TextStyle(fontSize: 14),
              ),
              value: _isEnabled,
              onChanged: (value) => _toggleTwoFactorAuth(),
              activeColor: darkGreen,
            ),
            const SizedBox(height: 24),
            if (!_isVerified && _isEnabled) ...[
              const Text(
                'Ikuti Instruksi di Bawah Ini untuk Mengaktifkan Two-Factor Authentication',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Unduh aplikasi authentication seperti Google Authentication atau Authy.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '2. Pindai kode QR di bawah ini atau masukkan kunci rahasia secara manual.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '3. Masukkan kode 6 digit dari aplikasi Authentication untuk memverifikasi.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),

              // QR Code Section
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                      ),
                      child: _buildQRCode(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Kode Rahasia: $_secretKey',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, size: 18),
                          onPressed: _copySecretKey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Code Entry Section
              Column(
                children: [
                  Text(
                    'Masukkan 6-digit Verifikasi Kode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Kode kadaluwarsa pada ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        '$_remainingTime seconds',
                        style: TextStyle(
                          color: _remainingTime < 10 ? Colors.red : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 40,
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          decoration: InputDecoration(
                            counterText: '',
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: darkGreen, width: 2),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Verify', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
            if (_isVerified && _isEnabled) ...[
              const Text(
                'Akun Anda terlindungi oleh two-factor authentication',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.security, color: darkGreen),
                title: const Text('Kode Pemulihan'),
                subtitle: const Text('Melihat atau membuat kode cadangan'),
                onTap: () {
                  // Navigate to recovery codes page
                },
              ),
              ListTile(
                leading: Icon(Icons.phone_android, color: darkGreen),
                title: const Text('Ubah aplikasi Authentication'),
                subtitle: const Text('Siapkan aplikasi Authentication yang berbeda'),
                onTap: () {
                  // Navigate to change app page
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: OutlinedButton(
                  onPressed: _toggleTwoFactorAuth,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Nonaktifkan Two-Factor Authentication'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}