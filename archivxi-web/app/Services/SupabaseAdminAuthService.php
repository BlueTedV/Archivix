<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class SupabaseAdminAuthException extends RuntimeException {}

class SupabaseAdminAuthService
{
    /**
     * @return array<string, string|null>
     */
    public function authenticateAdmin(string $email, string $password): array
    {
        $supabaseUrl = rtrim((string) config('services.supabase.url'), '/');
        $anonKey = (string) config('services.supabase.anon_key');

        if ($supabaseUrl === '' || $anonKey === '') {
            throw new SupabaseAdminAuthException(
                'Supabase auth belum dikonfigurasi di server Laravel.',
            );
        }

        try {
            $tokenResponse = Http::baseUrl($supabaseUrl)
                ->acceptJson()
                ->withHeaders([
                    'apikey' => $anonKey,
                ])
                ->post('/auth/v1/token?grant_type=password', [
                    'email' => $email,
                    'password' => $password,
                ]);
        } catch (\Throwable $exception) {
            throw new SupabaseAdminAuthException(
                'Laravel tidak bisa menghubungi Supabase Auth. Cek SUPABASE_URL dan koneksi server.',
            );
        }

        if ($tokenResponse->status() === 400 || $tokenResponse->status() === 401) {
            throw new SupabaseAdminAuthException('Email atau password admin tidak valid.');
        }

        if ($tokenResponse->failed()) {
            throw new SupabaseAdminAuthException(
                'Supabase menolak permintaan login admin.',
            );
        }

        $accessToken = (string) ($tokenResponse->json('access_token') ?? '');

        if ($accessToken === '') {
            throw new SupabaseAdminAuthException(
                'Supabase login berhasil tetapi access token tidak tersedia.',
            );
        }

        try {
            $userResponse = Http::baseUrl($supabaseUrl)
                ->acceptJson()
                ->withHeaders([
                    'apikey' => $anonKey,
                    'Authorization' => 'Bearer '.$accessToken,
                ])
                ->get('/auth/v1/user');
        } catch (\Throwable $exception) {
            throw new SupabaseAdminAuthException(
                'Login berhasil, tetapi Laravel gagal mengambil profil admin dari Supabase.',
            );
        }

        if ($userResponse->failed()) {
            throw new SupabaseAdminAuthException(
                'Laravel gagal memverifikasi akun admin ke Supabase.',
            );
        }

        /** @var array<string, mixed> $user */
        $user = $userResponse->json();
        $role = (string) data_get($user, 'app_metadata.role', '');

        if ($role !== 'admin') {
            throw new SupabaseAdminAuthException(
                'Akun ini tidak punya akses admin Laravel.',
            );
        }

        if ((string) ($user['email_confirmed_at'] ?? '') === '') {
            throw new SupabaseAdminAuthException(
                'Email admin ini belum terverifikasi di Supabase.',
            );
        }

        return [
            'id' => (string) ($user['id'] ?? ''),
            'email' => (string) ($user['email'] ?? $email),
            'name' => (string) (
                data_get($user, 'user_metadata.full_name')
                ?? data_get($user, 'user_metadata.name')
                ?? $user['email']
                ?? 'Admin'
            ),
            'role' => $role,
            'email_verified_at' => (string) ($user['email_confirmed_at'] ?? ''),
            'last_sign_in_at' => (string) ($user['last_sign_in_at'] ?? ''),
        ];
    }
}
