<?php

namespace App\Http\Controllers;

use App\Services\SupabaseUserDashboardService;
use Illuminate\Support\Carbon;
use Illuminate\Http\Request;
use Illuminate\View\View;
use RuntimeException;

class UserDashboardController extends Controller
{
    public function index(
        Request $request,
        SupabaseUserDashboardService $dashboardService,
    ): View
    {
        /** @var array<string, string|null> $sessionUser */
        $sessionUser = $request->session()->get('web_user', []);

        $user = (object) [
            'id' => $sessionUser['id'] ?? null,
            'name' => $sessionUser['name'] ?? 'User',
            'email' => $sessionUser['email'] ?? null,
            'role' => $sessionUser['role'] ?? 'user',
            'email_verified_at' => filled($sessionUser['email_verified_at'] ?? null)
                ? Carbon::parse((string) $sessionUser['email_verified_at'])
                : null,
            'created_at' => filled($sessionUser['created_at'] ?? null)
                ? Carbon::parse((string) $sessionUser['created_at'])
                : null,
            'last_sign_in_at' => filled($sessionUser['last_sign_in_at'] ?? null)
                ? Carbon::parse((string) $sessionUser['last_sign_in_at'])
                : null,
        ];

        $dashboardData = [
            'stats' => [
                'papers' => 0,
                'posts' => 0,
                'draft_papers' => 0,
                'submitted_papers' => 0,
                'under_review_papers' => 0,
                'published_papers' => 0,
                'rejected_papers' => 0,
                'total_views' => 0,
            ],
            'papers' => [],
            'posts' => [],
            'recent_items' => [],
            'alerts' => [],
            'latest_feedback' => [],
        ];
        $loadError = null;

        if (filled($user->id)) {
            try {
                $dashboardData = $dashboardService->dashboardData((string) $user->id);
            } catch (RuntimeException $exception) {
                $loadError = $exception->getMessage();
            }
        }

        return view('user.dashboard', [
            'user' => $user,
            'dashboard' => $dashboardData,
            'loadError' => $loadError,
        ]);
    }
}
