@extends('layouts.site')
@section('title', 'Masuk / Daftar')

@section('styles')
<style>
    .auth-page {
        min-height: calc(100vh - 58px - 56px);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 40px 20px;
    }

    .auth-box { width: 100%; max-width: 480px; }

    .auth-header { margin-bottom: 24px; }
    .auth-header h2 { font-size: 24px; font-weight: 800; margin-bottom: 6px; }
    .auth-header p { font-size: 14px; color: #6b7280; line-height: 1.7; }

    .auth-footer {
        margin-top: 18px;
        font-size: 13px;
        color: #6b7280;
        text-align: center;
    }

    .auth-footer a {
        color: #1d72da;
        font-weight: 800;
        text-decoration: none;
    }

    .auth-switch {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 8px;
        padding: 6px;
        margin-bottom: 20px;
        border-radius: 16px;
        background: #eef4fb;
        border: 1px solid #d6deea;
    }

    .auth-switch a {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-height: 42px;
        border-radius: 12px;
        color: #64748b;
        font-size: 13px;
        font-weight: 800;
        text-decoration: none;
        transition: 0.15s ease;
    }

    .auth-switch a.active {
        background: #ffffff;
        color: #132238;
        box-shadow: 0 8px 18px rgba(14, 30, 56, 0.08);
    }

    .alert {
        border-radius: 10px;
        padding: 12px 14px;
        margin-bottom: 18px;
        font-size: 13px;
        line-height: 1.55;
    }

    .alert-error {
        background: #fef2f2;
        border: 1px solid #fecaca;
        color: #b91c1c;
    }

    .alert-success {
        background: #ecfdf5;
        border: 1px solid #a7f3d0;
        color: #047857;
    }

    .remember-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
        margin-bottom: 18px;
        font-size: 13px;
        color: #64748b;
    }

    .remember-row label {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        cursor: pointer;
    }

    .remember-row a {
        color: #1d72da;
        font-weight: 800;
        text-decoration: none;
    }
</style>
@endsection

@section('content')
@php
    $authMode = $authMode ?? 'login';
    $isRegister = $authMode === 'register';
@endphp

<div class="auth-page">
    <div class="auth-box">
        <div class="auth-header">
            <h2>{{ $isRegister ? 'Buat akun Archivix' : 'Masuk ke Archivix' }}</h2>
            <p>
                {{ $isRegister
                    ? 'Daftar untuk mengakses ruang kerja Archivix dan melanjutkan aktivitas dari akun yang sama.'
                    : 'Masuk untuk membuka dashboard Archivix sesuai akses akunmu.' }}
            </p>
        </div>

        <div class="card">
            <div class="auth-switch" aria-label="Pilih mode autentikasi">
                <a href="{{ route('login') }}" class="{{ $isRegister ? '' : 'active' }}">Masuk</a>
                <a href="{{ route('register') }}" class="{{ $isRegister ? 'active' : '' }}">Daftar</a>
            </div>

            @if (session('success'))
                <div class="alert alert-success">
                    {{ session('success') }}
                </div>
            @endif

            @if ($errors->any())
                <div class="alert alert-error">
                    {{ $errors->first() }}
                </div>
            @endif

            @if ($isRegister)
                <form action="{{ route('user.register.submit') }}" method="POST">
                    @csrf

                    <label class="form-label">Nama</label>
                    <input
                        type="text"
                        name="name"
                        class="form-input"
                        placeholder="Nama lengkap"
                        value="{{ old('name') }}"
                        required
                        autofocus
                    >

                    <label class="form-label">Alamat Email</label>
                    <input
                        type="email"
                        name="email"
                        class="form-input"
                        placeholder="nama@email.com"
                        value="{{ old('email') }}"
                        required
                    >

                    <label class="form-label">Password</label>
                    <input
                        type="password"
                        name="password"
                        class="form-input"
                        placeholder="Minimal 6 karakter"
                        required
                    >

                    <label class="form-label">Konfirmasi Password</label>
                    <input
                        type="password"
                        name="password_confirmation"
                        class="form-input"
                        placeholder="Ulangi password"
                        required
                    >

                    <button type="submit" class="btn btn-primary btn-full">
                        Buat Akun
                    </button>
                </form>

                <div class="auth-footer">
                    Sudah punya akun? <a href="{{ route('login') }}">Masuk sekarang</a>
                </div>
            @else
                <form action="{{ route('user.login.submit') }}" method="POST">
                    @csrf

                    <label class="form-label">Alamat Email</label>
                    <input
                        type="email"
                        name="email"
                        class="form-input"
                        placeholder="nama@email.com"
                        value="{{ old('email') }}"
                        required
                        autofocus
                    >

                    <label class="form-label">Password</label>
                    <input
                        type="password"
                        name="password"
                        class="form-input"
                        placeholder="Masukkan password"
                        required
                    >

                    <div class="remember-row">
                        <label>
                            <input type="checkbox" name="remember" value="1">
                            <span>Ingat saya</span>
                        </label>

                        <a href="{{ route('password.reset') }}">Punya link reset?</a>
                    </div>

                    <button type="submit" class="btn btn-primary btn-full">
                        Masuk
                    </button>
                </form>

                <div class="auth-footer">
                    Belum punya akun? <a href="{{ route('register') }}">Daftar di sini</a>
                </div>
            @endif
        </div>
    </div>
</div>
@endsection
