<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\EmailVerificationToken;
use App\Models\PasswordResetToken;
use App\Models\TwoFactorAuth;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Carbon\Carbon;
use PragmaRX\Google2FA\Google2FA;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class AuthController extends Controller
{
    /**
     * Register a new user
     */
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'username' => 'required|string|min:4|max:50|unique:users',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        // Create user
        $user = User::create([
            'username' => $request->username,
            'email' => $request->email,
            'password_hash' => Hash::make($request->password),
            'email_verified' => 0
        ]);

        // Create email verification token
        $token = Str::random(60);
        EmailVerificationToken::create([
            'user_id' => $user->user_id,
            'token' => $token,
            'expires_at' => Carbon::now()->addHours(24)
        ]);

        // TODO: Send verification email

        // Create token for API access
        $accessToken = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'User registered successfully',
            'data' => [
                'user' => $user,
                'access_token' => $accessToken,
                'token_type' => 'Bearer',
            ]
        ], 201);
    }

    /**
     * Login user and create token
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string|email|max:255',
            'password' => 'required|string|min:8',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        // Check email
        $user = User::where('email', $request->email)->first();

        // Check password
        if (!$user || !Hash::check($request->password, $user->password_hash)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid login credentials'
            ], 401);
        }

        // Check if 2FA is enabled
        $tfa = $user->twoFactorAuth;
        if ($tfa && $tfa->is_enabled) {
            // Return need for 2FA verification
            return response()->json([
                'success' => true,
                'message' => '2FA verification required',
                'data' => [
                    'user_id' => $user->user_id,
                    'tfa_method' => $tfa->method,
                    'requires_2fa' => true
                ]
            ], 200);
        }

        // Create token
        $accessToken = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data' => [
                'user' => [
                    'user_id' => $user->user_id,
                    'username' => $user->username,
                    'email' => $user->email,
                ],
                'access_token' => $accessToken,
                'token_type' => 'Bearer',
            ]
        ], 200);
    }

    /**
     * Verify 2FA code
     */
    // public function verify2FA(Request $request)
    // {
    //     $validator = Validator::make($request->all(), [
    //         'user_id' => 'required|integer',
    //     ]);

    //     if ($validator->fails()) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'Validation error',
    //             'errors' => $validator->errors()
    //         ], 422);
    //     }

    //     $user = User::find($request->user_id);
    //     if (!$user) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'User not found'
    //         ], 404);
    //     }

    //     // 1. Generate secret key
    //     $google2fa = new Google2FA();
    //     $secret = $google2fa->generateSecretKey();

    //     // 2. Buat QR Code URL otpauth://
    //     $qrUrl = $google2fa->getQRCodeUrl(
    //         'ResepNusantara',          // Issuer name
    //         $user->email,              // Account name
    //         $secret                    // Secret key
    //     );

    //     // 3. Buat URL QR image (pakai Google Chart API)
    //     $qrImageUrl = 'https://chart.googleapis.com/chart?chs=200x200&cht=qr&chl=' . urlencode($qrUrl);

    //     // 4. Simpan atau update 2FA di DB
    //     $twoFA = $user->twoFactorAuth()->updateOrCreate(
    //         ['user_id' => $user->id],
    //         [
    //             'secret' => $secret,
    //             'is_enabled' => true,
    //             'method' => 'authenticator',
    //         ]
    //     );

    //     // 5. Return ke frontend Flutter
    //     return response()->json([
    //         'success' => true,
    //         'message' => '2FA enabled successfully',
    //         'qr_image_url' => $qrImageUrl,
    //         'secret' => $secret,
    //         'data' => $twoFA
    //     ], 200);
    // }

    /**
     * Logout user (revoke token)
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully'
        ], 200);
    }

    /**
     * Get user details
     */
    public function user(Request $request)
    {
        return response()->json([
            'success' => true,
            'data' => [
                'user' => $request->user()
            ]
        ], 200);
    }

    public function update(Request $request, $id)
    {
        Log::info('Update profile attempt', [
            'user_id' => $id,
            'data' => $request->all(),
            'files' => $request->hasFile('profile_picture') ? 'File present' : 'No file'
        ]);

        // Pastikan pengguna yang login adalah pengguna yang diperbarui
        if ($request->user()->user_id != $id) {
            Log::warning('Unauthorized profile update attempt', [
                'user_id' => $request->user()->user_id,
                'requested_id' => $id
            ]);
            return response()->json([
                'success' => false,
                'message' => 'Tidak diizinkan untuk memperbarui profil pengguna lain'
            ], 403);
        }

        // Validasi input
        $validator = Validator::make($request->all(), [
            'email' => 'required|email|unique:users,email,' . $id . ',user_id',
            'username' => 'required|string|min:3|unique:users,username,' . $id . ',user_id',
            'old_password' => 'nullable|string|min:8', // Sesuaikan dengan min:8 dari register
            'password' => 'nullable|string|min:8|confirmed',
            'profile_picture' => 'nullable|image|mimes:jpeg,png,jpg|max:2048', // Maks 2MB
        ]);

        if ($validator->fails()) {
            Log::error('Validation failed', ['errors' => $validator->errors()]);
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = User::findOrFail($id);

        // Validasi password lama jika password baru diisi
        if ($request->filled('password')) {
            if (!$request->filled('old_password')) {
                Log::warning('Old password not provided when new password is set');
                return response()->json([
                    'success' => false,
                    'message' => 'Password lama harus diisi untuk mengubah password'
                ], 422);
            }

            Log::info('Checking old password', [
                'input_old_password' => $request->old_password,
                'stored_password_hash' => $user->password_hash
            ]);

            if (!Hash::check($request->old_password, $user->password_hash)) {
                Log::error('Old password does not match', [
                    'input' => $request->old_password,
                    'hash' => $user->password_hash
                ]);
                return response()->json([
                    'success' => false,
                    'message' => 'Password lama salah'
                ], 422);
            }
        }

        // Siapkan data untuk update
        $data = $request->only(['email', 'username']);

        // Update password jika ada
        if ($request->filled('password')) {
            $data['password_hash'] = Hash::make($request->password);
            Log::info('New password will be updated', ['new_password' => $request->password]);
        }

        // Tangani unggah profile picture
        if ($request->hasFile('profile_picture')) {
            // Hapus gambar lama jika ada
            if ($user->profile_picture && Storage::exists('public/' . $user->profile_picture)) {
                Storage::delete('public/' . $user->profile_picture);
            }
            // Simpan gambar baru
            $path = $request->file('profile_picture')->store('profile_pictures', 'public');
            $data['profile_picture'] = $path;
            Log::info('Profile picture updated', ['path' => $path]);
        }

        // Update user
        $user->update($data);

        // Kembalikan URL lengkap untuk profile_picture
        $profilePictureUrl = $user->profile_picture
            ? url('storage/' . $user->profile_picture)
            : url('images/default_profile.jpg');

        Log::info('Profile updated successfully', ['user_id' => $user->user_id]);

        return response()->json([
            'success' => true,
            'message' => 'Profile updated successfully',
            'data' => [
                'user' => [
                    'user_id' => $user->user_id,
                    'email' => $user->email,
                    'username' => $user->username,
                    'profile_picture' => $profilePictureUrl,
                ]
            ]
        ], 200);
    }

    /**
     * Verify email
     */
    // public function verifyEmail(Request $request)
    // {
    //     $validator = Validator::make($request->all(), [
    //         'token' => 'required|string',
    //     ]);

    //     if ($validator->fails()) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'Validation error',
    //             'errors' => $validator->errors()
    //         ], 422);
    //     }

    //     $verification = EmailVerificationToken::where('token', $request->token)
    //         ->where('expires_at', '>', Carbon::now())
    //         ->first();

    //     if (!$verification) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'Invalid or expired token'
    //         ], 400);
    //     }

    //     $user = User::find($verification->user_id);
    //     if (!$user) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'User not found'
    //         ], 404);
    //     }

    //     $user->email_verified = true;
    //     $user->save();

    //     $verification->delete();

    //     return response()->json([
    //         'success' => true,
    //         'message' => 'Email verified successfully'
    //     ], 200);
    // }

    /**
     * Request password reset
     */
    public function forgotPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string|email|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found with this email'
            ], 404);
        }

        // Delete any existing token
        PasswordResetToken::where('user_id', $user->user_id)->delete();

        // Create new token
        $token = Str::random(60);
        PasswordResetToken::create([
            'user_id' => $user->user_id,
            'token' => $token,
            'expires_at' => Carbon::now()->addHours(1)
        ]);

        // TODO: Send password reset email

        return response()->json([
            'success' => true,
            'message' => 'Password reset link sent to your email'
        ], 200);
    }

    /**
     * Reset password
     */
    // public function resetPassword(Request $request)
    // {
    //     $validator = Validator::make($request->all(), [
    //         'token' => 'required|string',
    //         'password' => 'required|string|min:8|confirmed',
    //     ]);

    //     if ($validator->fails()) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'Validation error',
    //             'errors' => $validator->errors()
    //         ], 422);
    //     }

    //     $resetToken = PasswordResetToken::where('token', $request->token)
    //         ->where('expires_at', '>', Carbon::now())
    //         ->first();

    //     if (!$resetToken) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'Invalid or expired token'
    //         ], 400);
    //     }

    //     $user = User::find($resetToken->user_id);
    //     if (!$user) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'User not found'
    //         ], 404);
    //     }

    //     $user->password_hash = Hash::make($request->password);
    //     $user->save();

    //     $resetToken->delete();

    //     return response()->json([
    //         'success' => true,
    //         'message' => 'Password reset successfully'
    //     ], 200);
    // }

    /**
     * Setup 2FA
     */
    // public function setup2FA(Request $request)
    // {
    //     $validator = Validator::make($request->all(), [
    //         'method' => 'required|string|in:email,authenticator',
    //     ]);

    //     if ($validator->fails()) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'Validation error',
    //             'errors' => $validator->errors()
    //         ], 422);
    //     }

    //     $user = $request->user();
    //     $tfa = $user->twoFactorAuth;

    //     if (!$tfa) {
    //         $tfa = new TwoFactorAuth();
    //         $tfa->user_id = $user->user_id;
    //     }

    //     $tfa->method = $request->method;

    //     // If using authenticator app, generate secret
    //     if ($request->method === 'authenticator') {
    //         // In a real app, you would use a proper 2FA library
    //         $tfa->secret = Str::random(32);
    //     }

    //     $tfa->save();

    //     return response()->json([
    //         'success' => true,
    //         'message' => '2FA setup initialized',
    //         'data' => [
    //             'method' => $tfa->method,
    //             'secret' => $tfa->secret,
    //             'qr_code' => $tfa->method === 'authenticator' ? 'QR code URL would go here' : null
    //         ]
    //     ], 200);
    // }

    /**
     * Enable 2FA
     */
    // public function enable2FA(Request $request)
    // {
    //     $validator = Validator::make($request->all(), [
    //         'code' => 'required|string',
    //     ]);

    //     if ($validator->fails()) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'Validation error',
    //             'errors' => $validator->errors()
    //         ], 422);
    //     }

    //     $user = $request->user();
    //     $tfa = $user->twoFactorAuth;

    //     if (!$tfa) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => '2FA not set up yet'
    //         ], 400);
    //     }

    //     // TODO: Verify code based on method
    //     // This is a placeholder. In a real application, you would verify
    //     // the code based on the method (email or authenticator app)
    //     $isVerified = true; // Replace with actual verification

    //     if (!$isVerified) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => 'Invalid verification code'
    //         ], 401);
    //     }

    //     $tfa->is_enabled = true;
    //     $tfa->save();

    //     return response()->json([
    //         'success' => true,
    //         'message' => '2FA enabled successfully'
    //     ], 200);
    // }

    /**
     * Disable 2FA
     */
    // public function disable2FA(Request $request)
    // {
    //     $user = $request->user();
    //     $tfa = $user->twoFactorAuth;

    //     if (!$tfa || !$tfa->is_enabled) {
    //         return response()->json([
    //             'success' => false,
    //             'message' => '2FA is not enabled'
    //         ], 400);
    //     }

    //     $tfa->is_enabled = false;
    //     $tfa->save();

    //     return response()->json([
    //         'success' => true,
    //         'message' => '2FA disabled successfully'
    //     ], 200);
    // }
}
