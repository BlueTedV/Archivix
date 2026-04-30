<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequireWebUserSession
{
    public function handle(Request $request, Closure $next): Response
    {
        $webUser = $request->session()->get('web_user');

        if (! is_array($webUser) || ($webUser['id'] ?? null) === null || ($webUser['email'] ?? null) === null) {
            $request->session()->forget('web_user');

            return redirect()
                ->route('login')
                ->withErrors([
                    'email' => 'Masuk dengan akun Supabase terlebih dahulu.',
                ]);
        }

        return $next($request);
    }
}
