<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequireAdminSession
{
    public function handle(Request $request, Closure $next): Response
    {
        $adminUser = $request->session()->get('admin_user');

        if (! is_array($adminUser) || ($adminUser['role'] ?? null) !== 'admin') {
            $request->session()->forget(['admin_user', 'is_admin']);

            return redirect()
                ->route('admin.login')
                ->withErrors([
                    'email' => 'Masuk dengan akun Supabase yang punya role admin terlebih dahulu.',
                ]);
        }

        return $next($request);
    }
}
