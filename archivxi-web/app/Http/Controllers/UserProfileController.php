<?php

namespace App\Http\Controllers;

use App\Services\SupabaseUserProfileService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;
use RuntimeException;

class UserProfileController extends Controller
{
    public function edit(
        Request $request,
        SupabaseUserProfileService $profileService,
    ): View {
        /** @var array<string, string|null> $sessionUser */
        $sessionUser = $request->session()->get('web_user', []);
        $profile = [];
        $loadError = null;

        try {
            $profile = $profileService->getProfile(
                (string) ($sessionUser['id'] ?? ''),
                (string) ($sessionUser['name'] ?? ''),
                (string) ($sessionUser['email'] ?? ''),
            );
        } catch (RuntimeException $exception) {
            $loadError = $exception->getMessage();
        }

        return view('user.profile-edit', [
            'sessionUser' => $sessionUser,
            'profile' => $profile,
            'loadError' => $loadError,
        ]);
    }

    public function update(
        Request $request,
        SupabaseUserProfileService $profileService,
    ): RedirectResponse {
        /** @var array<string, string|null> $sessionUser */
        $sessionUser = $request->session()->get('web_user', []);
        $userId = (string) ($sessionUser['id'] ?? '');

        $data = $request->validate([
            'username' => ['nullable', 'regex:/^[A-Za-z0-9_]{3,24}$/'],
            'full_name' => ['nullable', 'string', 'max:80'],
            'bio' => ['nullable', 'string', 'max:240'],
            'avatar' => ['nullable', 'image', 'max:5120'],
            'remove_avatar' => ['nullable', 'boolean'],
        ]);

        try {
            $profile = $profileService->updateProfile($userId, [
                ...$data,
                'avatar' => $request->file('avatar'),
                'remove_avatar' => $request->boolean('remove_avatar'),
            ]);
        } catch (RuntimeException $exception) {
            return back()
                ->withInput($request->except('avatar'))
                ->withErrors(['profile' => $exception->getMessage()]);
        }

        $updatedSessionUser = [
            ...$sessionUser,
            'username' => $profile['username'] !== '' ? (string) $profile['username'] : null,
            'name' => (string) (
                ($profile['full_name'] ?? '')
                ?: ($profile['username'] !== '' ? '@'.$profile['username'] : ($sessionUser['name'] ?? 'User'))
            ),
        ];

        $request->session()->put('web_user', $updatedSessionUser);

        return redirect()
            ->route('user.profile.edit')
            ->with('success', 'Profile updated successfully.');
    }
}
