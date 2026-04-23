@extends('layouts.site')
@section('title', 'Masuk')

@section('styles')
<style>
    .auth-page {
        min-height: calc(100vh - 58px - 56px);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 40px 20px;
    }

    .auth-box { width: 100%; max-width: 400px; }

    .auth-header { margin-bottom: 24px; }
    .auth-header h2 { font-size: 20px; font-weight: 700; margin-bottom: 4px; }
    .auth-header p { font-size: 13.5px; color: #6b7280; }

    .divider {
        display: flex;
        align-items: center;
        gap: 12px;
        margin: 18px 0;
        color: #9ca3af;
        font-size: 12px;
    }

    .divider::before, .divider::after {
        content: '';
        flex: 1;
        height: 1px;
        background: #e5e7eb;
    }

    .helper-text {
        font-size: 12px;
        color: #9ca3af;
        margin-top: -10px;
        margin-bottom: 18px;
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
            <h2>Masuk ke ArchivXI</h2>
            <p>Masuk dengan akun Supabase yang sudah diberi role admin</p>
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

            <form action="/login" method="POST">
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
                <p class="helper-text">Laravel akan login ke Supabase lalu mengecek apakah akun ini punya <code>app_metadata.role = admin</code>.</p>
                <button type="submit" class="btn btn-primary btn-full">
                    Kirim Kode Verifikasi →
                </button>
            </form>
        </div>
    </div>
</div>
@endsection
