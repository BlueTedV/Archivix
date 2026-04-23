@extends('layouts.app')
@section('title', 'Verifikasi OTP')

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

    .otp-note {
        text-align: center;
        margin-top: 16px;
        font-size: 12.5px;
        color: #9ca3af;
    }

    .otp-note a { color: #3b5bdb; text-decoration: none; font-weight: 500; }
    .otp-note a:hover { text-decoration: underline; }

    .info-box {
        background: #eff6ff;
        border: 1px solid #bfdbfe;
        border-radius: 8px;
        padding: 12px 14px;
        font-size: 12.5px;
        color: #1d4ed8;
        margin-bottom: 20px;
        line-height: 1.5;
    }
</style>
@endsection

@section('content')
<div class="auth-page">
    <div class="auth-box">
        <div class="auth-header">
            <h2>Cek email kamu</h2>
            <p>Masukkan kode yang sudah dikirim</p>
        </div>

        <div class="card">
            <div class="info-box">
                📨 Kode verifikasi telah dikirim ke email kamu. Periksa folder <strong>Inbox</strong> atau <strong>Spam</strong>.
            </div>

            <form action="/verify" method="POST">
                @csrf
                <label class="form-label">Kode OTP</label>
                <input
                    type="text"
                    name="otp"
                    class="form-input"
                    placeholder="Masukkan 6 digit kode"
                    maxlength="6"
                    autocomplete="one-time-code"
                    required
                    autofocus
                >
                <button type="submit" class="btn btn-primary btn-full">
                    Verifikasi & Masuk →
                </button>
            </form>

            <p class="otp-note">
                Tidak menerima kode? <a href="/login">Kirim ulang</a>
            </p>
        </div>
    </div>
</div>
@endsection