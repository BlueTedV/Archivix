@extends('layouts.site')
@section('title', 'Reset Password')

@section('styles')
<style>
    .reset-page {
        min-height: calc(100vh - 58px - 56px);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 40px 20px;
    }

    .reset-box {
        width: 100%;
        max-width: 520px;
    }

    .reset-header {
        margin-bottom: 24px;
    }

    .reset-header h2 {
        font-size: 24px;
        font-weight: 800;
        margin-bottom: 8px;
    }

    .reset-header p {
        font-size: 14px;
        line-height: 1.7;
        color: #6b7280;
    }

    .reset-status {
        border-radius: 4px;
        padding: 12px 14px;
        margin-bottom: 18px;
        font-size: 13px;
        line-height: 1.6;
        border: 1px solid #d6deea;
        background: #f8fbff;
        color: #3f4857;
    }

    .reset-status.is-success {
        background: #ecfdf5;
        border-color: #a7f3d0;
        color: #047857;
    }

    .reset-status.is-error {
        background: #fef2f2;
        border-color: #fecaca;
        color: #b91c1c;
    }

    .reset-help {
        margin-top: 18px;
        font-size: 13px;
        line-height: 1.7;
        color: #6b7280;
    }

    .reset-help a {
        color: #1d72da;
        font-weight: 800;
        text-decoration: none;
    }
</style>
@endsection

@section('content')
<div class="reset-page">
    <div class="reset-box">
        <div class="reset-header">
            <h2>Reset password akunmu</h2>
            <p>
                Buka halaman ini dari link email reset password. Setelah token recovery terdeteksi,
                kamu bisa langsung menyimpan password baru untuk akun Archivix.
            </p>
        </div>

        <div class="card">
            @if ($errors->any())
                <div class="reset-status is-error">
                    {{ $errors->first() }}
                </div>
            @endif

            <div
                id="reset-link-status"
                class="reset-status {{ old('access_token') ? 'is-success' : '' }}"
            >
                {{ old('access_token')
                    ? 'Link reset terdeteksi. Silakan masukkan password baru kamu.'
                    : 'Sedang memeriksa link reset password dari email kamu...' }}
            </div>

            <form id="reset-password-form" action="{{ route('password.reset.submit') }}" method="POST">
                @csrf

                <input
                    id="access_token"
                    type="hidden"
                    name="access_token"
                    value="{{ old('access_token', '') }}"
                >

                <label class="form-label">Password Baru</label>
                <input
                    type="password"
                    name="password"
                    class="form-input"
                    placeholder="Minimal 6 karakter"
                    required
                    {{ old('access_token') ? '' : 'disabled' }}
                >

                <label class="form-label">Konfirmasi Password Baru</label>
                <input
                    type="password"
                    name="password_confirmation"
                    class="form-input"
                    placeholder="Ulangi password baru"
                    required
                    {{ old('access_token') ? '' : 'disabled' }}
                >

                <button
                    id="reset-submit"
                    type="submit"
                    class="btn btn-primary btn-full"
                    {{ old('access_token') ? '' : 'disabled' }}
                >
                    Simpan Password Baru
                </button>
            </form>

            <div class="reset-help">
                Link expired atau terbuka tanpa token? <a href="{{ route('login') }}">Kembali ke halaman login</a>
                lalu minta email reset password baru dari flow auth yang kamu pakai.
            </div>
        </div>
    </div>
</div>
@endsection

@section('scripts')
<script>
    document.addEventListener('DOMContentLoaded', function () {
        const form = document.getElementById('reset-password-form');
        const statusBox = document.getElementById('reset-link-status');
        const tokenInput = document.getElementById('access_token');
        const submitButton = document.getElementById('reset-submit');
        const passwordInputs = form.querySelectorAll('input[type="password"]');

        const setInteractiveState = function (enabled) {
            submitButton.disabled = !enabled;

            passwordInputs.forEach(function (input) {
                input.disabled = !enabled;
            });
        };

        const setStatus = function (message, type) {
            statusBox.textContent = message;
            statusBox.classList.remove('is-success', 'is-error');

            if (type) {
                statusBox.classList.add(type);
            }
        };

        if (tokenInput.value) {
            setInteractiveState(true);
            return;
        }

        const currentUrl = new URL(window.location.href);
        const hashParams = new URLSearchParams(currentUrl.hash.startsWith('#') ? currentUrl.hash.slice(1) : '');
        const queryParams = currentUrl.searchParams;

        const accessToken = hashParams.get('access_token') || queryParams.get('access_token') || '';
        const recoveryType = hashParams.get('type') || queryParams.get('type') || '';
        const errorMessage = hashParams.get('error_description') || queryParams.get('error_description') || '';

        if (errorMessage) {
            setInteractiveState(false);
            setStatus(errorMessage, 'is-error');
            return;
        }

        if (accessToken && (recoveryType === '' || recoveryType === 'recovery')) {
            tokenInput.value = accessToken;
            setInteractiveState(true);
            setStatus('Link reset terdeteksi. Silakan masukkan password baru kamu.', 'is-success');
            window.history.replaceState({}, document.title, currentUrl.pathname);
            return;
        }

        setInteractiveState(false);
        setStatus('Link reset password tidak valid atau sudah kedaluwarsa.', 'is-error');
    });
</script>
@endsection
