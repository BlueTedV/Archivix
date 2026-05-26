@extends('layouts.site')
@section('title', 'Beranda')

@section('styles')
<style>
    .landing-wrap {
        max-width: 1180px;
        margin: 0 auto;
        padding: 34px 20px 56px;
    }

    .hero {
        display: grid;
        grid-template-columns: 1.15fr 0.85fr;
        gap: 24px;
        align-items: stretch;
        margin-bottom: 24px;
    }

    .hero-copy {
        padding: 38px;
        border-radius: 32px;
        background:
            radial-gradient(circle at top right, rgba(124, 194, 255, 0.22), transparent 30%),
            linear-gradient(135deg, #132238 0%, #1c3553 58%, #21476f 100%);
        color: #f7fbff;
        box-shadow: 0 24px 48px rgba(19, 34, 56, 0.20);
    }

    .eyebrow {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 8px 14px;
        border-radius: 999px;
        background: rgba(255, 255, 255, 0.10);
        color: #cfe6ff;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.1em;
        text-transform: uppercase;
        margin-bottom: 18px;
    }

    .hero-copy h1 {
        font-size: clamp(34px, 5vw, 56px);
        line-height: 1.02;
        letter-spacing: -0.04em;
        margin-bottom: 18px;
    }

    .hero-copy p {
        max-width: 620px;
        font-size: 16px;
        line-height: 1.75;
        color: rgba(247, 251, 255, 0.82);
        margin-bottom: 26px;
    }

    .hero-actions {
        display: flex;
        gap: 14px;
        flex-wrap: wrap;
        margin-bottom: 22px;
    }

    .hero-metrics {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 12px;
    }

    .hero-metric {
        padding: 16px;
        border-radius: 20px;
        background: rgba(255, 255, 255, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.10);
    }

    .hero-metric strong {
        display: block;
        font-size: 24px;
        margin-bottom: 4px;
    }

    .hero-metric span {
        font-size: 12px;
        color: rgba(247, 251, 255, 0.68);
    }

    .hero-panel {
        display: flex;
        flex-direction: column;
        gap: 16px;
    }

    .app-preview-card {
        height: 100%;
        min-height: 536px;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        gap: 20px;
        border-radius: 32px;
        padding: 26px;
        background: rgba(255, 255, 255, 0.90);
        border: 1px solid rgba(214, 222, 234, 0.95);
        box-shadow: 0 24px 48px rgba(14, 30, 56, 0.10);
        overflow: hidden;
    }

    .app-preview-copy span {
        display: inline-block;
        margin-bottom: 8px;
        color: #1d72da;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }

    .app-preview-copy h2 {
        font-size: 24px;
        line-height: 1.2;
        margin-bottom: 8px;
        color: #132238;
    }

    .app-preview-copy p {
        color: #5f7187;
        font-size: 14px;
        line-height: 1.7;
    }

    .phone-preview {
        flex: 1;
        min-height: 360px;
        display: grid;
        place-items: center;
        border-radius: 28px;
        padding: 18px;
        background:
            linear-gradient(180deg, rgba(19, 34, 56, 0.06), rgba(55, 147, 255, 0.08)),
            #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .phone-preview img {
        width: min(100%, 300px);
        max-height: 430px;
        object-fit: contain;
        filter: drop-shadow(0 24px 34px rgba(14, 30, 56, 0.20));
    }

    .preview-placeholder {
        width: min(100%, 260px);
        aspect-ratio: 9 / 18;
        display: grid;
        place-items: center;
        border-radius: 34px;
        padding: 18px;
        background: #132238;
        color: #cfe6ff;
        text-align: center;
        box-shadow: inset 0 0 0 10px #203955, 0 22px 36px rgba(14, 30, 56, 0.20);
    }

    .preview-placeholder strong {
        display: block;
        color: #ffffff;
        font-size: 18px;
        margin-bottom: 8px;
    }

    .preview-placeholder span {
        font-size: 12px;
        line-height: 1.6;
    }

    .phone-preview img[hidden],
    .phone-preview .preview-placeholder[hidden] {
        display: none !important;
    }

    .section {
        margin-top: 26px;
    }

    .download-strip {
        display: grid;
        grid-template-columns: 1fr auto;
        align-items: center;
        gap: 18px;
        margin-top: 26px;
        padding: 26px;
        border-radius: 28px;
        background: #132238;
        color: #f7fbff;
        box-shadow: 0 20px 40px rgba(19, 34, 56, 0.18);
    }

    .download-strip span {
        display: inline-block;
        margin-bottom: 8px;
        color: #7cc2ff;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }

    .download-strip h2 {
        font-size: 24px;
        margin-bottom: 6px;
    }

    .download-strip p {
        max-width: 680px;
        color: rgba(247, 251, 255, 0.76);
        line-height: 1.7;
    }

    .section-head {
        max-width: 620px;
        margin-bottom: 18px;
    }

    .section-head span {
        display: inline-block;
        margin-bottom: 8px;
        color: #1d72da;
        font-size: 12px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }

    .section-head h2 {
        font-size: 28px;
        margin-bottom: 8px;
    }

    .section-head p {
        color: #66788f;
        line-height: 1.7;
    }

    .feature-grid {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 16px;
    }

    .feature-card {
        padding: 24px;
        border-radius: 24px;
        background: rgba(255, 255, 255, 0.94);
        border: 1px solid rgba(214, 222, 234, 0.95);
        box-shadow: 0 18px 36px rgba(14, 30, 56, 0.06);
    }

    .feature-icon {
        width: 46px;
        height: 46px;
        display: grid;
        place-items: center;
        border-radius: 16px;
        margin-bottom: 16px;
        background: linear-gradient(135deg, #e7f2ff 0%, #cfe6ff 100%);
        color: #1d72da;
        font-weight: 800;
    }

    .feature-card h3 {
        font-size: 18px;
        margin-bottom: 8px;
    }

    .feature-card p {
        color: #66788f;
        font-size: 14px;
        line-height: 1.75;
    }

    .cta-band {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 18px;
        margin-top: 28px;
        padding: 24px 26px;
        border-radius: 28px;
        background: linear-gradient(135deg, #eff7ff 0%, #dfeeff 100%);
        border: 1px solid #cfe0f3;
    }

    .cta-band h3 {
        font-size: 22px;
        margin-bottom: 6px;
    }

    .cta-band p {
        color: #5f7187;
        line-height: 1.7;
    }

    @media (max-width: 980px) {
        .hero,
        .feature-grid,
        .download-strip {
            grid-template-columns: 1fr;
        }

        .app-preview-card {
            min-height: auto;
        }

        .phone-preview {
            min-height: 320px;
        }
    }

    @media (max-width: 720px) {
        .landing-wrap {
            padding: 24px 16px 44px;
        }

        .hero-copy {
            padding: 28px 24px;
        }

        .hero-metrics {
            grid-template-columns: 1fr;
        }

        .cta-band {
            flex-direction: column;
            align-items: flex-start;
        }

        .download-strip {
            padding: 22px;
        }
    }
</style>
@endsection

@section('content')
<div class="landing-wrap">
    <section class="hero">
        <div class="hero-copy">
            <div class="eyebrow">Archivix Web Platform</div>
            <h1>Tempat berbagi, menyimpan, dan menemukan konten pembelajaran dalam satu ruang.</h1>
            <p>
                Archivix membantu komunitas belajar mengelola dokumen, referensi, dan unggahan akademik dengan alur yang lebih rapi.
                Masuk untuk membuka dashboard, memantau progres dokumen, dan melanjutkan aktivitas dari akun Archivix kamu.
            </p>

            <div class="hero-actions">
                @if (session()->has('admin_user'))
                    <a href="{{ route('dashboard') }}" class="btn btn-primary">Buka Dashboard</a>
                @elseif (session()->has('web_user'))
                    <a href="{{ route('user.dashboard') }}" class="btn btn-primary">Buka Dashboard</a>
                @else
                    <a href="{{ route('login') }}" class="btn btn-primary">Masuk / Daftar</a>
                @endif
                <a href="{{ route('browse.index') }}" class="btn btn-secondary">Browse Archive</a>
                <a href="/download" class="btn btn-secondary">Lihat Download</a>
            </div>

            <div class="hero-metrics">
                <div class="hero-metric">
                    <strong>1</strong>
                    <span>Pintu masuk untuk komunitas Archivix</span>
                </div>
                <div class="hero-metric">
                    <strong>1</strong>
                    <span>Dashboard pribadi setelah login</span>
                </div>
                <div class="hero-metric">
                    <strong>Aman</strong>
                    <span>Akses akun terhubung dengan alur autentikasi Archivix</span>
                </div>
            </div>
        </div>

        <div class="hero-panel">
            <div class="app-preview-card">
                <div class="app-preview-copy">
                    <span>Mobile App Preview</span>
                    <h2>Archivix di genggaman pengguna.</h2>
                    <p>Lihat tampilan aplikasi mobile untuk mencari, mengunggah, dan memantau konten pembelajaran dari mana saja.</p>
                </div>

                <div class="phone-preview">
                    <img
                        src="{{ asset('images/mobile-app-preview.png') }}"
                        alt="Preview tampilan aplikasi mobile Archivix"
                        onerror="this.hidden = true; this.nextElementSibling.hidden = false;"
                    >
                    <div class="preview-placeholder" hidden>
                        <div>
                            <strong>Mobile Preview</strong>
                            <span>Letakkan mock-up kamu di public/images/mobile-app-preview.png</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section class="download-strip">
        <div>
            <span>Download Mobile App</span>
            <h2>Gunakan Archivix lewat aplikasi mobile.</h2>
            <p>Unduh aplikasi untuk akses yang lebih cepat saat membaca, mencari referensi, atau melanjutkan aktivitas pembelajaran.</p>
        </div>
        <a href="/download" class="btn btn-primary">Ke Halaman Download</a>
    </section>

    <section class="section">
        <div class="section-head">
            <span>Kenapa Archivix</span>
            <h2>Dirancang untuk alur belajar dan pengelolaan arsip yang lebih jelas.</h2>
            <p>Archivix menyatukan pengelolaan dokumen, pertanyaan, dan status review agar pengguna lebih mudah mengikuti perkembangan konten mereka.</p>
        </div>

        <div class="feature-grid">
            <article class="feature-card">
                <div class="feature-icon">01</div>
                <h3>Akses yang jelas</h3>
                <p>Pengguna baru dan pengguna lama masuk melalui alur autentikasi yang ringkas.</p>
            </article>

            <article class="feature-card">
                <div class="feature-icon">02</div>
                <h3>Dashboard setelah login</h3>
                <p>Setelah berhasil masuk, pengguna diarahkan ke dashboard sesuai peran dan akses akun.</p>
            </article>

            <article class="feature-card">
                <div class="feature-icon">03</div>
                <h3>Alur konten rapi</h3>
                <p>Status dokumen, feedback, dan aktivitas terbaru tersusun agar mudah dipantau.</p>
            </article>
        </div>
    </section>

    <section class="cta-band">
        <div>
            <h3>Siap lanjut ke dashboard?</h3>
            <p>Masuk atau daftar untuk membuka dashboard Archivix dan melanjutkan aktivitasmu.</p>
        </div>

        @if (session()->has('admin_user'))
            <a href="{{ route('dashboard') }}" class="btn btn-primary">Ke Dashboard</a>
        @elseif (session()->has('web_user'))
            <a href="{{ route('user.dashboard') }}" class="btn btn-primary">Ke Dashboard</a>
        @else
            <a href="{{ route('login') }}" class="btn btn-primary">Masuk / Daftar</a>
        @endif
    </section>
</div>
@endsection
