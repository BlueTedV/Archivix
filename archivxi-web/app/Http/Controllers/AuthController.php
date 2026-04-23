<?php

namespace App\Http\Controllers;

use App\Services\SupabaseAdminAuthException;
use App\Services\SupabaseAdminAuthService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AuthController extends Controller
{
    public function create(Request $request): View|RedirectResponse
    {
        if ($request->session()->has('admin_user')) {
            return redirect('/dashboard');
        }

        return view('login');
    }

    public function store(
        Request $request,
        SupabaseAdminAuthService $supabaseAdminAuth,
    ): RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        try {
            $adminUser = $supabaseAdminAuth->authenticateAdmin(
                $credentials['email'],
                $credentials['password'],
            );
        } catch (SupabaseAdminAuthException $exception) {
            return back()
                ->withInput($request->only('email'))
                ->withErrors([
                    'email' => $exception->getMessage(),
                ]);
        }

        $request->session()->regenerate();
        $request->session()->put('admin_user', $adminUser);
        $request->session()->put('is_admin', true);

        return redirect('/dashboard')->with('success', 'Login admin berhasil.');
    }

    public function destroy(Request $request): RedirectResponse
    {
        $request->session()->forget(['admin_user', 'is_admin']);
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect('/login')->with('success', 'Sesi admin sudah ditutup.');
    }
}
