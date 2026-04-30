<?php

use App\Http\Controllers\AdminContentController;
use App\Http\Controllers\UserAuthController;
use App\Http\Controllers\UserDashboardController;
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

Route::get('/admin/login', function () {
    return redirect()->route('login');
});

Route::post('/admin/login', function () {
    return redirect()->route('login');
});

Route::post('/admin/logout', [UserAuthController::class, 'logout']);

Route::get('/home-admin', function () {
    return redirect('/dashboard');
});

Route::get('/dashboard', function () {
    return view('dashboard', [
        'user' => (object) session('admin_user', []),
    ]);
})->middleware('admin.session')->name('dashboard');

Route::prefix('dashboard/posts')
    ->middleware('admin.session')
    ->name('dashboard.posts.')
    ->group(function () {
        Route::get('/', [AdminContentController::class, 'index'])->name('index');
        Route::get('/{contentType}/{contentId}/edit', [AdminContentController::class, 'edit'])->name('edit');
        Route::put('/{contentType}/{contentId}', [AdminContentController::class, 'update'])->name('update');
        Route::post('/paper/{contentId}/under-review', [AdminContentController::class, 'markUnderReview'])->name('under-review');
        Route::post('/paper/{contentId}/publish', [AdminContentController::class, 'publish'])->name('publish');
        Route::post('/paper/{contentId}/reject', [AdminContentController::class, 'reject'])->name('reject');
        Route::delete('/{contentType}/{contentId}', [AdminContentController::class, 'destroy'])->name('destroy');
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
