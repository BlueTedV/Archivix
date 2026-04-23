<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ApiToken;
use App\Models\EmailVerificationCode;
use App\Models\User;
use App\Notifications\EmailVerificationCodeNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password as PasswordRule;

class AuthApiController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['nullable', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', PasswordRule::min(6)],
        ]);

        $user = User::create([
            'name' => $data['name'] ?? Str::headline(str((string) Str::before($data['email'], '@'))->replace(['.', '_', '-'], ' ')->value()),
            'email' => $data['email'],
            'password' => $data['password'],
        ]);

        $this->issueVerificationCode($user);

        return response()->json([
            'message' => 'Registration successful. Please verify your email.',
            'user' => $this->userPayload($user),
        ], 201);
    }

    public function verifyEmail(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'digits:6'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user) {
            return response()->json([
                'message' => 'User not found.',
            ], 404);
        }

        $verification = EmailVerificationCode::where('user_id', $user->id)
            ->where('code', $data['code'])
            ->whereNull('used_at')
            ->latest('created_at')
            ->first();

        if (! $verification || $verification->expires_at->isPast()) {
            return response()->json([
                'message' => 'Verification code is invalid or expired.',
            ], 422);
        }

        $verification->forceFill([
            'used_at' => now(),
        ])->save();

        $user->forceFill([
            'email_verified_at' => now(),
        ])->save();

        return response()->json([
            'message' => 'Email verified successfully.',
            'user' => $this->userPayload($user->fresh()),
        ]);
    }

    public function resendVerification(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user) {
            return response()->json([
                'message' => 'User not found.',
            ], 404);
        }

        if ($user->email_verified_at) {
            return response()->json([
                'message' => 'Email is already verified.',
            ], 422);
        }

        $this->issueVerificationCode($user);

        return response()->json([
            'message' => 'Verification code sent.',
        ]);
    }

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $user = User::where('email', $credentials['email'])->first();

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            return response()->json([
                'message' => 'Invalid credentials.',
            ], 422);
        }

        if (! $user->email_verified_at) {
            return response()->json([
                'message' => 'Please verify your email before logging in.',
                'code' => 'email_not_verified',
            ], 403);
        }

        $plainToken = Str::random(80);

        $token = $user->apiTokens()->create([
            'name' => $credentials['device_name'] ?? 'mobile',
            'token_hash' => hash('sha256', $plainToken),
            'last_used_at' => now(),
            'expires_at' => now()->addDays(30),
        ]);

        return response()->json([
            'message' => 'Login successful.',
            'token' => $plainToken,
            'token_type' => 'Bearer',
            'expires_at' => optional($token->expires_at)?->toIso8601String(),
            'user' => $this->userPayload($user),
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $this->userPayload($request->user()),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $token = $request->attributes->get('apiToken');

        if ($token instanceof ApiToken) {
            $token->delete();
        }

        return response()->json([
            'message' => 'Logged out successfully.',
        ]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'confirmed', PasswordRule::min(6)],
        ]);

        /** @var User $user */
        $user = $request->user();

        if (! Hash::check($data['current_password'], $user->password)) {
            return response()->json([
                'message' => 'Current password is incorrect.',
            ], 422);
        }

        $user->forceFill([
            'password' => $data['password'],
        ])->save();

        return response()->json([
            'message' => 'Password changed successfully.',
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $status = Password::sendResetLink([
            'email' => $data['email'],
        ]);

        if ($status !== Password::RESET_LINK_SENT) {
            return response()->json([
                'message' => __($status),
            ], 422);
        }

        return response()->json([
            'message' => __($status),
        ]);
    }

    private function issueVerificationCode(User $user): void
    {
        EmailVerificationCode::where('user_id', $user->id)
            ->whereNull('used_at')
            ->delete();

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        EmailVerificationCode::create([
            'user_id' => $user->id,
            'code' => $code,
            'expires_at' => now()->addMinutes(15),
        ]);

        $user->notify(new EmailVerificationCodeNotification($code));
    }

    private function userPayload(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'email_verified_at' => optional($user->email_verified_at)?->toIso8601String(),
            'created_at' => optional($user->created_at)?->toIso8601String(),
        ];
    }
}
