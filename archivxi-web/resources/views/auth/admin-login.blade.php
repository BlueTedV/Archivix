@extends('layouts.site')
@section('title', 'Admin Login')

@section('styles')
<style>
    .auth-page {
        min-height: calc(100vh - 58px - 56px);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 40px 20px;
    }

    .auth-box { width: 100%; max-width: 420px; }

    .auth-header { margin-bottom: 24px; }
    .auth-header h2 { font-size: 22px; font-weight: 800; margin-bottom: 6px; }
    .auth-header p { font-size: 13.5px; color: #6b7280; line-height: 1.65; }

    .helper-text {
        font-size: 12px;
        color: #9ca3af;
        margin-top: -10px;
        margin-bottom: 18px;
        line-height: 1.6;
    }

    .alert {
        border-radius: 8px;
        padding: 12px 14px;
        margin-bottom: 18px;
        font-size: 13px;
        line-height: 1.5;
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
</style>
@endsection

@section('content')
<div class="auth-page">
    <div class="auth-box">
        <div class="auth-header">
            <h2>Masuk ke Panel Admin</h2>
            <p>Masuk dengan akun Supabase yang sudah diberi role admin supaya dashboard web tetap jadi area kerja khusus moderator dan reviewer.</p>
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

            <form action="{{ route('admin.login.submit') }}" method="POST">
                @csrf
                <label class="form-label">Alamat Email</label>
                <input
                    type="email"
                    name="email"
                    class="form-input"
                    placeholder="admin@email.com"
                    value="{{ old('email') }}"
                    required
                    autofocus
                >

                <label class="form-label">Password</label>
                <input
                    type="password"
                    name="password"
                    class="form-input"
                    placeholder="Masukkan password admin"
                    required
                >

                <p class="helper-text">Laravel akan login ke Supabase lalu mengecek apakah akun ini punya <code>app_metadata.role = admin</code>.</p>

                <button type="submit" class="btn btn-primary btn-full">
                    Masuk ke Admin Panel
                </button>
            </form>
        </div>
    </div>
</div>
@endsection
