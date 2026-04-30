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

    .glass-card {
        border-radius: 28px;
        padding: 24px;
        background: rgba(255, 255, 255, 0.84);
        border: 1px solid rgba(214, 222, 234, 0.95);
        box-shadow: 0 20px 44px rgba(14, 30, 56, 0.08);
    }

    .glass-card h3 {
        font-size: 18px;
        margin-bottom: 10px;
    }

    .glass-card p {
        font-size: 14px;
        line-height: 1.7;
        color: #5f7187;
    }

    .stack-list {
        display: grid;
        gap: 12px;
        margin-top: 18px;
    }

    .stack-item {
        padding: 14px 16px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .stack-item strong {
        display: block;
        font-size: 14px;
        margin-bottom: 4px;
    }

    .stack-item span {
        display: block;
        font-size: 13px;
        color: #6f8095;
        line-height: 1.6;
    }

    .section {
        margin-top: 26px;
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
        .feature-grid {
            grid-template-columns: 1fr;
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
                Halaman ini menjadi pintu masuk web version, lalu setelah login pengguna akan masuk ke dashboard mereka.
            </p>

            <div class="hero-actions">
                @if (session()->has('admin_user'))
                    <a href="{{ route('dashboard') }}" class="btn btn-primary">Buka Dashboard</a>
                @elseif (session()->has('web_user'))
                    <a href="{{ route('user.dashboard') }}" class="btn btn-primary">Buka Dashboard</a>
                @else
                    <a href="{{ route('login') }}" class="btn btn-primary">Masuk Sekarang</a>
                    <a href="{{ route('register') }}" class="btn btn-secondary">Buat Akun</a>
                @endif
                <a href="/download" class="btn btn-secondary">Lihat Download</a>
            </div>

            <div class="hero-metrics">
                <div class="hero-metric">
                    <strong>1</strong>
                    <span>Landing page untuk pengunjung baru</span>
                </div>
                <div class="hero-metric">
                    <strong>1</strong>
                    <span>Dashboard khusus setelah login</span>
                </div>
                <div class="hero-metric">
                    <strong>Supabase</strong>
                    <span>Auth source yang sama dengan mobile app</span>
                </div>
            </div>
        </div>

        <div class="hero-panel">
            <div class="glass-card">
                <h3>Alur Pengguna</h3>
                <p>Pengunjung melihat pengenalan platform terlebih dahulu. Setelah berhasil login, mereka diarahkan ke dashboard untuk melihat status akun dan pintasan kerja.</p>

                <div class="stack-list">
                    <div class="stack-item">
                        <strong>1. Jelajahi platform</strong>
                        <span>Baca gambaran singkat tentang fungsi Archivix dan apa yang akan tersedia di web version.</span>
                    </div>
                    <div class="stack-item">
                        <strong>2. Login dengan satu akun</strong>
                        <span>Semua akun memakai Supabase login yang sama, lalu dashboard akan menyesuaikan berdasarkan role akunmu.</span>
                    </div>
                    <div class="stack-item">
                        <strong>3. Masuk ke dashboard</strong>
                        <span>Lihat identitas akun dan area kerja yang nantinya bisa diisi fitur unggah, statistik, dan status dokumen sesuai aksesmu.</span>
                    </div>
                </div>
            </div>

            <div class="glass-card">
                <h3>Web Version Status</h3>
                <p>Versi web masih awal, jadi landing page ini sengaja berperan sebagai introduction page sambil dashboard dipakai sebagai area internal setelah pengguna berhasil login.</p>
            </div>
        </div>
    </section>

    <section class="section">
        <div class="section-head">
            <span>Kenapa Archivix</span>
            <h2>Dirancang untuk alur belajar dan pengelolaan arsip yang lebih jelas.</h2>
            <p>Daripada langsung menampilkan halaman kosong, pengunjung sekarang mendapatkan konteks tentang produk ini, sementara user yang sudah login bisa langsung pindah ke area dashboard.</p>
        </div>

        <div class="feature-grid">
            <article class="feature-card">
                <div class="feature-icon">01</div>
                <h3>Landing page yang jelas</h3>
                <p>Homepage sekarang berfungsi sebagai pengantar platform, bukan sekadar placeholder konten kosong.</p>
            </article>

            <article class="feature-card">
                <div class="feature-icon">02</div>
                <h3>Dashboard setelah login</h3>
                <p>Setelah auth berhasil, user langsung diarahkan ke dashboard agar pengalaman terasa lebih terstruktur.</p>
            </article>

            <article class="feature-card">
                <div class="feature-icon">03</div>
                <h3>Siap dikembangkan</h3>
                <p>Struktur ini enak untuk langkah berikutnya seperti menambahkan statistik, daftar konten, dan upload form berbasis Supabase.</p>
            </article>
        </div>
    </section>

    <section class="cta-band">
        <div>
            <h3>Siap lanjut ke dashboard?</h3>
            <p>Masuk dengan akun Supabase Archivix untuk membuka dashboard yang sesuai dengan role akunmu.</p>
        </div>

        @if (session()->has('admin_user'))
            <a href="{{ route('dashboard') }}" class="btn btn-primary">Ke Dashboard</a>
        @elseif (session()->has('web_user'))
            <a href="{{ route('user.dashboard') }}" class="btn btn-primary">Ke Dashboard</a>
        @else
            <a href="{{ route('login') }}" class="btn btn-primary">Masuk</a>
        @endif
    </section>
</div>
@endsection
