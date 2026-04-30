@extends('layouts.site')
@section('title', 'Login')

@section('styles')
<style>
    .auth-page {
        min-height: calc(100vh - 58px - 56px);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 40px 20px;
    }

    .auth-box { width: 100%; max-width: 440px; }

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
</style>
@endsection

@section('content')
<div class="auth-page">
    <div class="auth-box">
        <div class="auth-header">
            <h2>Masuk ke Archivix</h2>
            <p>Gunakan akun Supabase kamu untuk masuk ke Archivix. Setelah login, dashboard akan menyesuaikan otomatis dengan role akunmu.</p>
        </div>

        <div class="card">
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
                </div>

                <button type="submit" class="btn btn-primary btn-full">
                    Masuk
                </button>
            </form>

            <div class="auth-footer">
                Belum punya akun? <a href="{{ route('register') }}">Buat akun baru</a>
            </div>
        </div>
    </div>
</div>
@endsection
