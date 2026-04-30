<?php

namespace App\Services;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class SupabaseUserAuthException extends RuntimeException {}

class SupabaseUserAuthService
{
    /**
     * @return array<string, string|bool|array<string, string|null>>
     */
    public function registerUser(string $name, string $email, string $password): array
    {
        [$supabaseUrl, $anonKey] = $this->credentials();

        try {
            $response = Http::baseUrl($supabaseUrl)
                ->acceptJson()
                ->withHeaders([
                    'apikey' => $anonKey,
                ])
                ->post('/auth/v1/signup', [
                    'email' => $email,
                    'password' => $password,
                    'data' => [
                        'full_name' => $name,
                        'name' => $name,
                    ],
                ]);
        } catch (\Throwable $exception) {
            throw new SupabaseUserAuthException(
                'Laravel tidak bisa menghubungi Supabase Auth. Cek SUPABASE_URL dan koneksi server.',
            );
        }

        if ($response->failed()) {
            throw new SupabaseUserAuthException(
                $this->messageFromResponse(
                    $response,
                    'Supabase menolak permintaan pendaftaran user.',
                ),
            );
        }

        $responseUser = $response->json('user');

        if (! is_array($responseUser)) {
            throw new SupabaseUserAuthException(
                'Supabase tidak mengembalikan data user setelah pendaftaran.',
            );
        }

        $accessToken = (string) ($response->json('access_token') ?? '');

        $user = $accessToken !== ''
            ? $this->fetchUser($supabaseUrl, $anonKey, $accessToken) ?? $responseUser
            : $responseUser;

        return [
            'user' => $this->formatSessionUser($user, $email, $name),
            'has_session' => $accessToken !== '',
        ];
    }

    /**
     * @return array<string, string|null>
     */
    public function authenticateUser(string $email, string $password): array
    {
        [$supabaseUrl, $anonKey] = $this->credentials();

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
            throw new SupabaseUserAuthException(
                'Laravel tidak bisa menghubungi Supabase Auth. Cek SUPABASE_URL dan koneksi server.',
            );
        }

        if ($tokenResponse->status() === 400 || $tokenResponse->status() === 401) {
            throw new SupabaseUserAuthException(
                $this->messageFromResponse($tokenResponse, 'Email atau password tidak cocok.'),
            );
        }

        if ($tokenResponse->failed()) {
            throw new SupabaseUserAuthException(
                $this->messageFromResponse(
                    $tokenResponse,
                    'Supabase menolak permintaan login user.',
                ),
            );
        }

        $accessToken = (string) ($tokenResponse->json('access_token') ?? '');

        if ($accessToken === '') {
            throw new SupabaseUserAuthException(
                'Supabase login berhasil tetapi access token tidak tersedia.',
            );
        }

        $user = $this->fetchUser($supabaseUrl, $anonKey, $accessToken);

        if (! is_array($user)) {
            throw new SupabaseUserAuthException(
                'Laravel gagal mengambil profil user dari Supabase.',
            );
        }

        return $this->formatSessionUser($user, $email);
    }

    /**
     * @return array{0: string, 1: string}
     */
    private function credentials(): array
    {
        $supabaseUrl = rtrim((string) config('services.supabase.url'), '/');
        $anonKey = (string) config('services.supabase.anon_key');

        if ($supabaseUrl === '' || $anonKey === '') {
            throw new SupabaseUserAuthException(
                'Supabase auth belum dikonfigurasi di server Laravel.',
            );
        }

        return [$supabaseUrl, $anonKey];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function fetchUser(
        string $supabaseUrl,
        string $anonKey,
        string $accessToken,
    ): ?array {
        try {
            $userResponse = Http::baseUrl($supabaseUrl)
                ->acceptJson()
                ->withHeaders([
                    'apikey' => $anonKey,
                    'Authorization' => 'Bearer '.$accessToken,
                ])
                ->get('/auth/v1/user');
        } catch (\Throwable $exception) {
            throw new SupabaseUserAuthException(
                'Login berhasil, tetapi Laravel gagal mengambil profil user dari Supabase.',
            );
        }

        if ($userResponse->failed()) {
            throw new SupabaseUserAuthException(
                $this->messageFromResponse(
                    $userResponse,
                    'Laravel gagal memverifikasi akun user ke Supabase.',
                ),
            );
        }

        $user = $userResponse->json();

        return is_array($user) ? $user : null;
    }

    private function messageFromResponse(Response $response, string $default): string
    {
        $message = (string) (
            $response->json('msg')
            ?? $response->json('message')
            ?? $response->json('error_description')
            ?? $response->json('error')
            ?? ''
        );

        if ($message === '') {
            return $default;
        }

        $normalized = strtolower($message);

        if (str_contains($normalized, 'invalid login credentials')) {
            return 'Email atau password tidak cocok.';
        }

        if (str_contains($normalized, 'email not confirmed')) {
            return 'Email ini belum terverifikasi di Supabase. Silakan cek inbox email kamu.';
        }

        if (str_contains($normalized, 'user already registered')) {
            return 'Email ini sudah terdaftar. Silakan login dengan akun Supabase yang sama.';
        }

        return $message;
    }

    /**
     * @param  array<string, mixed>  $user
     * @return array<string, string|null>
     */
    private function formatSessionUser(
        array $user,
        string $fallbackEmail = '',
        string $fallbackName = '',
    ): array {
        return [
            'id' => (string) ($user['id'] ?? ''),
            'email' => (string) ($user['email'] ?? $fallbackEmail),
            'name' => (string) (
                data_get($user, 'user_metadata.full_name')
                ?? data_get($user, 'user_metadata.name')
                ?? $fallbackName
                ?? $user['email']
                ?? 'User'
            ),
            'role' => (string) (data_get($user, 'app_metadata.role') ?? 'user'),
            'email_verified_at' => (string) (
                $user['email_confirmed_at']
                ?? $user['confirmed_at']
                ?? ''
            ),
            'last_sign_in_at' => (string) ($user['last_sign_in_at'] ?? ''),
            'created_at' => (string) ($user['created_at'] ?? ''),
        ];
    }
}
