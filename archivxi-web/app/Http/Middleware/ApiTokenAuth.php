<?php

namespace App\Http\Middleware;

use App\Models\ApiToken;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class ApiTokenAuth
{
    public function handle(Request $request, Closure $next): Response
    {
        $plainToken = $request->bearerToken();

        if (! $plainToken) {
            return response()->json([
                'message' => 'Unauthenticated.',
            ], 401);
        }

        $token = ApiToken::with('user')
            ->where('token_hash', hash('sha256', $plainToken))
            ->first();

        if (! $token || ! $token->user) {
            return response()->json([
                'message' => 'Invalid token.',
            ], 401);
        }

        if ($token->expires_at && $token->expires_at->isPast()) {
            $token->delete();

            return response()->json([
                'message' => 'Token expired.',
            ], 401);
        }

        $token->forceFill([
            'last_used_at' => now(),
        ])->save();

        $request->attributes->set('apiToken', $token);
        Auth::setUser($token->user);

        return $next($request);
    }
}
