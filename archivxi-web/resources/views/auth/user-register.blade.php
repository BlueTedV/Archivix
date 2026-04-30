@extends('layouts.site')
@section('title', 'Register')

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
</style>
@endsection

@section('content')
<div class="auth-page">
    <div class="auth-box">
        <div class="auth-header">
            <h2>Buat akun Archivix</h2>
            <p>Halaman ini membuat akun Archivix langsung di Supabase. Setelah daftar, kamu bisa masuk lewat halaman login yang sama seperti akun lainnya.</p>
        </div>

        <div class="card">
            @if ($errors->any())
                <div class="alert alert-error">
                    {{ $errors->first() }}
                </div>
            @endif

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
        </div>
    </div>
</div>
@endsection
