<?php

namespace App\Http\Controllers;

use App\Services\SupabaseUserAuthException;
use App\Services\SupabaseUserAuthService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Password as PasswordRule;
use Illuminate\View\View;

class UserAuthController extends Controller
{
    public function showLogin(Request $request): View|RedirectResponse
    {
        if ($request->session()->has('admin_user')) {
            return redirect()->route('dashboard');
        }

        if ($request->session()->has('web_user')) {
            return redirect()->route('user.dashboard');
        }

        return view('auth.user-login');
    }

    public function login(
        Request $request,
        SupabaseUserAuthService $supabaseUserAuth,
    ): RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        try {
            $user = $supabaseUserAuth->authenticateUser(
                $credentials['email'],
                $credentials['password'],
            );
        } catch (SupabaseUserAuthException $exception) {
            return back()
                ->withInput($request->only('email'))
                ->withErrors([
                    'email' => $exception->getMessage(),
                ]);
        }

        $request->session()->regenerate();

        if (($user['role'] ?? null) === 'admin') {
            $request->session()->forget('web_user');
            $request->session()->put('admin_user', $user);
            $request->session()->put('is_admin', true);

            return redirect()
                ->route('dashboard')
                ->with('success', 'Berhasil masuk ke dashboard Archivix.');
        }

        $request->session()->forget(['admin_user', 'is_admin']);
        $request->session()->put('web_user', $user);

        return redirect()
            ->route('user.dashboard')
            ->with('success', 'Berhasil masuk ke dashboard Archivix.');
    }

    public function showRegister(Request $request): View|RedirectResponse
    {
        if ($request->session()->has('admin_user')) {
            return redirect()->route('dashboard');
        }

        if ($request->session()->has('web_user')) {
            return redirect()->route('user.dashboard');
        }

        return view('auth.user-register');
    }

    public function register(
        Request $request,
        SupabaseUserAuthService $supabaseUserAuth,
    ): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255'],
            'password' => ['required', 'confirmed', PasswordRule::min(6)],
        ]);

        try {
            /** @var array{user: array<string, string|null>, has_session: bool} $registration */
            $registration = $supabaseUserAuth->registerUser(
                $data['name'],
                $data['email'],
                $data['password'],
            );
        } catch (SupabaseUserAuthException $exception) {
            return back()
                ->withInput($request->only('name', 'email'))
                ->withErrors([
                    'email' => $exception->getMessage(),
                ]);
        }

        if ($registration['has_session']) {
            $request->session()->regenerate();
            $request->session()->put('web_user', $registration['user']);

            return redirect()
                ->route('user.dashboard')
                ->with('success', 'Akun Supabase berhasil dibuat. Selamat datang di Archivix.');
        }

        return redirect()
            ->route('login')
            ->with('success', 'Akun Supabase berhasil dibuat. Silakan cek email untuk verifikasi sebelum login.');
    }

    public function logout(Request $request): RedirectResponse
    {
        $request->session()->forget(['web_user', 'admin_user', 'is_admin']);
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()
            ->route('login')
            ->with('success', 'Kamu sudah logout dari dashboard user.');
    }
}
