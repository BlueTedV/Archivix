<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\AdminContentController;
use App\Http\Controllers\UserAuthController;
use App\Http\Controllers\UserDashboardController;
use App\Services\SupabaseAdminContentService;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('landing');
});

Route::get('/login', [UserAuthController::class, 'showLogin'])->name('login');
Route::post('/login', [UserAuthController::class, 'login'])->name('user.login.submit');
Route::get('/register', [UserAuthController::class, 'showRegister'])->name('register');
Route::post('/register', [UserAuthController::class, 'register'])->name('user.register.submit');

Route::middleware('web-user.session')->group(function () {
    Route::get('/home', [UserDashboardController::class, 'index'])->name('user.dashboard');
});

Route::post('/logout', [UserAuthController::class, 'logout'])->name('logout');

Route::get('/admin/login', [AuthController::class, 'create'])->name('admin.login');
Route::post('/admin/login', [AuthController::class, 'store'])->name('admin.login.submit');
Route::post('/admin/logout', [AuthController::class, 'destroy'])->name('admin.logout');

Route::get('/home-admin', function () {
    return redirect('/dashboard');
});

Route::get('/dashboard', function (SupabaseAdminContentService $contentService) {
    $recentUploads = [];
    $loadError = null;

    try {
        $recentUploads = array_slice(
            $contentService->listContent(
                'all',
                (string) data_get(session('admin_user'), 'id', ''),
            )['items'],
            0,
            6,
        );
    } catch (\RuntimeException $exception) {
        $loadError = $exception->getMessage();
    }

    return view('dashboard', [
        'user' => (object) session('admin_user', []),
        'recentUploads' => $recentUploads,
        'loadError' => $loadError,
    ]);
})->middleware('admin.session')->name('dashboard');

Route::prefix('dashboard/posts')
    ->middleware('admin.session')
    ->name('dashboard.posts.')
    ->group(function () {
        Route::get('/', [AdminContentController::class, 'index'])->name('index');
        Route::get('/{contentType}/{contentId}/edit', [AdminContentController::class, 'edit'])->name('edit');
        Route::get('/{contentType}/{contentId}', [AdminContentController::class, 'show'])->name('show');
        Route::post('/{contentType}/{contentId}/react', [AdminContentController::class, 'react'])->name('react');
        Route::post('/{contentType}/{contentId}/comment', [AdminContentController::class, 'comment'])->name('comment');
        Route::put('/{contentType}/{contentId}', [AdminContentController::class, 'update'])->name('update');
        Route::post('/paper/{contentId}/under-review', [AdminContentController::class, 'markUnderReview'])->name('under-review');
        Route::post('/paper/{contentId}/publish', [AdminContentController::class, 'publish'])->name('publish');
        Route::post('/paper/{contentId}/reject', [AdminContentController::class, 'reject'])->name('reject');
        Route::delete('/{contentType}/{contentId}', [AdminContentController::class, 'destroy'])->name('destroy');
    });

Route::prefix('content')
    ->middleware('web-user.session')
    ->name('content.')
    ->group(function () {
        Route::get('/{contentType}/{contentId}', [AdminContentController::class, 'show'])->name('show');
        Route::post('/{contentType}/{contentId}/react', [AdminContentController::class, 'react'])->name('react');
        Route::post('/{contentType}/{contentId}/comment', [AdminContentController::class, 'comment'])->name('comment');
    });

Route::get('/admin', function () {
    return redirect('/dashboard');
})->middleware('admin.session');

Route::get('/verify', function () {
    return redirect()->route('login');
});

Route::post('/verify', function () {
    return redirect()->route('login');
});

Route::get('/download', function () {
    return view('donwload');
});
