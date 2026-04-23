<?php

use App\Http\Controllers\AdminContentController;
use App\Http\Controllers\AuthController;
use Illuminate\Support\Facades\Route;

// ── HOME ──────────────────────────────────────────
// Home publik (user)
Route::get('/', function () {
    return view('landing');
});

// Home admin (setelah login)
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
        Route::post('/paper/{contentId}/publish', [AdminContentController::class, 'publish'])->name('publish');
        Route::delete('/{contentType}/{contentId}', [AdminContentController::class, 'destroy'])->name('destroy');
    });

// ── AUTH ──────────────────────────────────────────
// Halaman login
Route::get('/login', [AuthController::class, 'create'])->name('login');

// Proses form login → redirect ke verify
Route::post('/login', [AuthController::class, 'store']);

// Halaman verifikasi OTP
Route::get('/verify', function () {
    return redirect('/login');
});

// Proses OTP → set session admin → redirect ke home admin
Route::post('/verify', function () {
    return redirect('/login');
});

// Logout → hapus session → balik ke home user
Route::post('/logout', [AuthController::class, 'destroy'])->name('logout');

// ── ADMIN ─────────────────────────────────────────
// Panel admin (form upload)
Route::get('/admin', function () {
    return redirect('/dashboard');
})->middleware('admin.session');

// ── DOWNLOAD ──────────────────────────────────────
Route::get('/download', function () {
    return view('donwload');
});

// ── TEST SUPABASE (hapus nanti setelah koneksi berhasil) ──
