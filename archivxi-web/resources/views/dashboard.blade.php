@extends('layouts.site')
@section('title', 'Dashboard')

@section('styles')
<style>
    .dashboard-wrap {
        max-width: 1160px;
        margin: 0 auto;
        padding: 34px 20px 56px;
    }

    .dashboard-hero {
        display: grid;
        grid-template-columns: 1.2fr 0.8fr;
        gap: 18px;
        margin-bottom: 22px;
    }

    .hero-card {
        padding: 30px;
        border-radius: 30px;
        background:
            radial-gradient(circle at top right, rgba(124, 194, 255, 0.24), transparent 28%),
            linear-gradient(135deg, #132238 0%, #1a3250 58%, #21476f 100%);
        color: #f7fbff;
        box-shadow: 0 24px 48px rgba(19, 34, 56, 0.22);
    }

    .hero-card span {
        display: inline-block;
        margin-bottom: 14px;
        padding: 8px 14px;
        border-radius: 999px;
        background: rgba(255, 255, 255, 0.10);
        color: #cfe6ff;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.1em;
        text-transform: uppercase;
    }

    .hero-card h1 {
        font-size: clamp(28px, 4vw, 42px);
        line-height: 1.08;
        letter-spacing: -0.04em;
        margin-bottom: 12px;
    }

    .hero-card p {
        max-width: 640px;
        color: rgba(247, 251, 255, 0.80);
        line-height: 1.75;
    }

    .profile-card {
        padding: 26px;
        border-radius: 30px;
        background: rgba(255, 255, 255, 0.95);
        border: 1px solid rgba(214, 222, 234, 0.95);
        box-shadow: 0 18px 40px rgba(14, 30, 56, 0.08);
    }

    .profile-card h3 {
        font-size: 18px;
        margin-bottom: 14px;
    }

    .profile-list {
        display: grid;
        gap: 12px;
    }

    .profile-item {
        padding: 14px 16px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .profile-item strong {
        display: block;
        margin-bottom: 4px;
        font-size: 12px;
        color: #5f7187;
        text-transform: uppercase;
        letter-spacing: 0.06em;
    }

    .profile-item span {
        font-size: 14px;
        color: #182433;
        word-break: break-word;
    }

    .stats-grid {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 16px;
        margin-bottom: 22px;
    }

    .stat-card {
        padding: 22px;
        border-radius: 24px;
        background: rgba(255, 255, 255, 0.94);
        border: 1px solid rgba(214, 222, 234, 0.95);
        box-shadow: 0 18px 36px rgba(14, 30, 56, 0.06);
    }

    .stat-card span {
        display: block;
        margin-bottom: 8px;
        font-size: 12px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: #6a7b90;
    }

    .stat-card strong {
        display: block;
        font-size: 28px;
        margin-bottom: 6px;
        color: #122031;
    }

    .stat-card p {
        color: #67788e;
        font-size: 13px;
        line-height: 1.65;
    }

    .dashboard-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 18px;
    }

    .panel {
        padding: 26px;
        border-radius: 28px;
        background: rgba(255, 255, 255, 0.95);
        border: 1px solid rgba(214, 222, 234, 0.95);
        box-shadow: 0 18px 36px rgba(14, 30, 56, 0.06);
    }

    .panel h2 {
        font-size: 20px;
        margin-bottom: 8px;
    }

    .panel p {
        color: #64768c;
        line-height: 1.7;
        margin-bottom: 16px;
    }

    .action-list,
    .roadmap-list {
        display: grid;
        gap: 12px;
    }

    .action-item,
    .roadmap-item {
        padding: 16px 18px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .action-item strong,
    .roadmap-item strong {
        display: block;
        margin-bottom: 5px;
        font-size: 14px;
    }

    .action-item span,
    .roadmap-item span {
        color: #697b91;
        font-size: 13px;
        line-height: 1.65;
    }

    .panel-actions {
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
        margin-top: 18px;
    }

    @media (max-width: 980px) {
        .dashboard-hero,
        .stats-grid,
        .dashboard-grid {
            grid-template-columns: 1fr;
        }
    }

    @media (max-width: 720px) {
        .dashboard-wrap {
            padding: 24px 16px 44px;
        }

        .hero-card,
        .profile-card,
        .stat-card,
        .panel {
            padding: 22px;
        }
    }
</style>
@endsection

@section('content')
<div class="dashboard-wrap">
    <section class="dashboard-hero">
        <div class="hero-card">
            <span>Admin Session</span>
            <h1>Selamat datang di dashboard admin Archivix.</h1>
            <p>
                Kamu sudah berhasil masuk melalui Supabase dan lolos pengecekan role admin.
                Dashboard ini sekarang siap kita kembangkan menjadi panel pengelolaan questions dan documents.
            </p>
        </div>

        <div class="profile-card">
            <h3>Informasi Akun</h3>

            <div class="profile-list">
                <div class="profile-item">
                    <strong>Email</strong>
                    <span>{{ $user?->email ?? 'Tidak tersedia' }}</span>
                </div>

                <div class="profile-item">
                    <strong>User ID</strong>
                    <span>{{ $user?->id ?? 'Tidak tersedia' }}</span>
                </div>

                <div class="profile-item">
                    <strong>Status</strong>
                    <span>{{ $user?->email_verified_at ? 'Email confirmed' : 'Email not verified' }}</span>
                </div>

                <div class="profile-item">
                    <strong>Role</strong>
                    <span>{{ $user?->role ?? 'unknown' }}</span>
                </div>
            </div>
        </div>
    </section>

    <section class="stats-grid">
        <article class="stat-card">
            <span>Auth</span>
            <strong>OK</strong>
            <p>Login admin lewat Supabase untuk panel web sudah aktif.</p>
        </article>

        <article class="stat-card">
            <span>Role</span>
            <strong>Admin</strong>
            <p>Hanya user Supabase dengan role admin yang bisa membuka dashboard ini.</p>
        </article>

        <article class="stat-card">
            <span>Content</span>
            <strong>0</strong>
            <p>Belum ada data live yang ditarik ke dashboard ini.</p>
        </article>

        <article class="stat-card">
            <span>Next Step</span>
            <strong>Build</strong>
            <p>Kita bisa sambungkan panel ini ke tabel Supabase berikutnya.</p>
        </article>
    </section>

    <section class="dashboard-grid">
        <div class="panel">
            <h2>Quick Actions</h2>
            <p>Beberapa pintasan sederhana supaya user punya arah yang jelas setelah login.</p>

            <div class="action-list">
                <div class="action-item">
                    <strong>Lihat landing page</strong>
                    <span>Kembali ke halaman utama publik untuk melihat introduction page.</span>
                </div>

                <div class="action-item">
                    <strong>Cek status akun</strong>
                    <span>Pastikan email, role admin, dan session Supabase terbaca dengan benar di dashboard.</span>
                </div>

                <div class="action-item">
                    <strong>Siapkan fitur berikutnya</strong>
                    <span>Dashboard ini siap dipakai untuk daftar post, papers, kategori, atau upload form.</span>
                </div>
            </div>

            <div class="panel-actions">
                <a href="/" class="btn btn-secondary">Kembali ke Home</a>
                <a href="{{ route('dashboard.posts.index') }}" class="btn btn-secondary">Kelola Konten</a>
                <a href="/download" class="btn btn-primary">Halaman Download</a>
            </div>
        </div>

        <div class="panel">
            <h2>Roadmap Dashboard</h2>
            <p>Area ini bisa berkembang dari placeholder menjadi dashboard yang benar-benar hidup.</p>

            <div class="roadmap-list">
                <div class="roadmap-item">
                    <strong>Integrasi data Supabase</strong>
                    <span>Tampilkan jumlah post, paper, kategori, dan recent activity langsung dari database.</span>
                </div>

                <div class="roadmap-item">
                    <strong>Content management</strong>
                    <span>Tambahkan form upload, edit, dan delete untuk konten yang dibuat user.</span>
                </div>

                <div class="roadmap-item">
                    <strong>Moderasi konten</strong>
                    <span>Tambahkan daftar, edit, publish, dan hapus untuk questions serta documents dari Supabase.</span>
                </div>
            </div>
        </div>
    </section>
</div>
@endsection
