<?php

use App\Http\Controllers\Api\AuthApiController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthApiController::class, 'register']);
    Route::post('/verify-email', [AuthApiController::class, 'verifyEmail']);
    Route::post('/resend-verification', [AuthApiController::class, 'resendVerification']);
    Route::post('/login', [AuthApiController::class, 'login']);
    Route::post('/forgot-password', [AuthApiController::class, 'forgotPassword']);

    Route::middleware('api.token')->group(function () {
        Route::get('/me', [AuthApiController::class, 'me']);
        Route::post('/logout', [AuthApiController::class, 'logout']);
        Route::post('/change-password', [AuthApiController::class, 'changePassword']);
    });
});
