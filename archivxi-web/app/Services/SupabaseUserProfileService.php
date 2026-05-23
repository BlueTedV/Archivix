<?php

namespace App\Services;

use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

class SupabaseUserProfileService
{
    /**
     * @return array<string, mixed>
     */
    public function getProfile(
        string $userId,
        string $fallbackName = '',
        string $fallbackEmail = '',
    ): array {
        $rows = $this->getRows('profiles', [
            'id' => 'eq.'.$userId,
            'select' => 'id,username,full_name,bio,avatar_path,is_verified_professor,professor_institution,professor_position,professor_department,updated_at,created_at',
            'limit' => '1',
        ]);

        $profile = $rows[0] ?? [];
        $fullName = trim((string) ($profile['full_name'] ?? ''));
        $username = trim((string) ($profile['username'] ?? ''));
        $avatarPath = trim((string) ($profile['avatar_path'] ?? ''));

        return [
            'id' => $userId,
            'username' => $username,
            'full_name' => $fullName,
            'bio' => trim((string) ($profile['bio'] ?? '')),
            'avatar_path' => $avatarPath,
            'avatar_url' => $this->publicStorageUrl('profile-avatars', $avatarPath),
            'is_verified_professor' => (bool) ($profile['is_verified_professor'] ?? false),
            'professor_institution' => trim((string) ($profile['professor_institution'] ?? '')),
            'professor_position' => trim((string) ($profile['professor_position'] ?? '')),
            'professor_department' => trim((string) ($profile['professor_department'] ?? '')),
            'updated_at' => (string) ($profile['updated_at'] ?? ''),
            'created_at' => (string) ($profile['created_at'] ?? ''),
            'display_name' => $fullName !== ''
                ? $fullName
                : ($username !== '' ? '@'.$username : ($fallbackName !== '' ? $fallbackName : $fallbackEmail)),
        ];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    public function updateProfile(string $userId, array $payload): array
    {
        $current = $this->getProfile($userId);
        $nextAvatarPath = $current['avatar_path'] ?? '';
        $shouldRemoveAvatar = (bool) ($payload['remove_avatar'] ?? false);
        /** @var UploadedFile|null $avatar */
        $avatar = $payload['avatar'] ?? null;

        if ($shouldRemoveAvatar && $nextAvatarPath !== '') {
            $this->deleteStorageObject('profile-avatars', $nextAvatarPath);
            $nextAvatarPath = '';
        }

        if ($avatar instanceof UploadedFile) {
            $extension = strtolower((string) $avatar->getClientOriginalExtension());
            $storageName = 'avatar_'.now()->timestamp.'_'.Str::random(8)
                .($extension !== '' ? '.'.$extension : '.jpg');
            $storagePath = $userId.'/'.$storageName;

            $this->uploadStorageObject('profile-avatars', $storagePath, $avatar);

            $previousAvatarPath = trim((string) ($current['avatar_path'] ?? ''));
            if ($previousAvatarPath !== '' && $previousAvatarPath !== $storagePath) {
                $this->deleteStorageObject('profile-avatars', $previousAvatarPath);
            }

            $nextAvatarPath = $storagePath;
        }

        $body = [
            'id' => $userId,
            'username' => $this->nullableTrimmedString($payload['username'] ?? null),
            'full_name' => $this->nullableTrimmedString($payload['full_name'] ?? null),
            'bio' => $this->nullableTrimmedString($payload['bio'] ?? null),
            'avatar_path' => $nextAvatarPath !== '' ? $nextAvatarPath : null,
        ];

        $response = $this->rest()
            ->asJson()
            ->withHeaders([
                'Prefer' => 'resolution=merge-duplicates,return=representation',
            ])
            ->post('/rest/v1/profiles', $body);

        if ($response->failed()) {
            throw new RuntimeException($this->profileErrorMessage($response));
        }

        $savedRows = $response->json();
        $savedProfile = is_array($savedRows) && isset($savedRows[0]) && is_array($savedRows[0])
            ? $savedRows[0]
            : $body;

        return $this->getProfile(
            $userId,
            (string) ($savedProfile['full_name'] ?? ''),
        );
    }

    /**
     * @param  array<string, string>  $params
     * @return array<int, array<string, mixed>>
     */
    private function getRows(string $table, array $params): array
    {
        $response = $this->rest()->get('/rest/v1/'.$table, $params);

        if ($response->failed()) {
            throw new RuntimeException('Supabase failed to load '.$table.'.');
        }

        $json = $response->json();

        if (! is_array($json)) {
            return [];
        }

        /** @var array<int, array<string, mixed>> $rows */
        $rows = array_values(array_filter($json, 'is_array'));

        return $rows;
    }

    private function rest(): PendingRequest
    {
        $supabaseUrl = rtrim((string) config('services.supabase.url'), '/');
        $serviceRoleKey = (string) config('services.supabase.service_role_key');

        if ($supabaseUrl === '' || $serviceRoleKey === '') {
            throw new RuntimeException(
                'Supabase service role credentials are missing on the Laravel server.',
            );
        }

        return Http::baseUrl($supabaseUrl)
            ->acceptJson()
            ->timeout(30)
            ->withHeaders([
                'apikey' => $serviceRoleKey,
                'Authorization' => 'Bearer '.$serviceRoleKey,
            ]);
    }

    private function uploadStorageObject(
        string $bucket,
        string $path,
        UploadedFile $file,
    ): void {
        $mimeType = $file->getMimeType() ?: 'application/octet-stream';
        $contents = file_get_contents($file->getRealPath());

        if ($contents === false) {
            throw new RuntimeException('Laravel could not read the uploaded avatar file.');
        }

        $response = $this->rest()
            ->withHeaders([
                'Content-Type' => $mimeType,
                'x-upsert' => 'false',
            ])
            ->withBody($contents, $mimeType)
            ->post('/storage/v1/object/'.$bucket.'/'.$path);

        if ($response->failed()) {
            throw new RuntimeException('Supabase Storage failed to upload the profile image.');
        }
    }

    private function deleteStorageObject(string $bucket, string $path): void
    {
        if ($path === '') {
            return;
        }

        $response = $this->rest()
            ->asJson()
            ->delete('/storage/v1/object/'.$bucket.'/'.$path);

        if ($response->status() === 404) {
            return;
        }

        if ($response->failed()) {
            throw new RuntimeException('Supabase Storage failed to remove the previous profile image.');
        }
    }

    private function nullableTrimmedString(mixed $value): ?string
    {
        $normalized = trim((string) ($value ?? ''));

        return $normalized !== '' ? $normalized : null;
    }

    private function publicStorageUrl(string $bucket, string $path): string
    {
        if ($path === '') {
            return '';
        }

        $supabaseUrl = rtrim((string) config('services.supabase.url'), '/');
        $encodedPath = str_replace('%2F', '/', rawurlencode($path));

        return $supabaseUrl.'/storage/v1/object/public/'.$bucket.'/'.$encodedPath;
    }

    private function profileErrorMessage(Response $response): string
    {
        $message = strtolower((string) (
            $response->json('message')
            ?? $response->json('error_description')
            ?? $response->json('error')
            ?? ''
        ));

        if (str_contains($message, 'duplicate key') || str_contains($message, 'username')) {
            return 'That username is already taken. Try another one.';
        }

        return 'Supabase could not save this profile right now.';
    }
}
