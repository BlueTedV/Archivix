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

    .dashboard-grid {
        display: block;
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

    .recent-list {
        display: grid;
        gap: 12px;
    }

    .recent-item {
        padding: 16px 18px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .recent-item strong {
        display: block;
        margin-bottom: 5px;
        font-size: 14px;
    }

    .recent-item span,
    .recent-item p {
        color: #697b91;
        font-size: 13px;
        line-height: 1.65;
        margin: 0;
    }

    .recent-head {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 14px;
        margin-bottom: 8px;
    }

    .badge-row {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        margin-top: 10px;
    }

    .type-badge,
    .status-badge {
        display: inline-flex;
        align-items: center;
        padding: 6px 10px;
        border-radius: 999px;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.06em;
        text-transform: uppercase;
    }

    .type-badge.post {
        background: #fff6e7;
        border: 1px solid #f4d7a4;
        color: #b26f07;
    }

    .type-badge.paper {
        background: #eef6ff;
        border: 1px solid #cde1f6;
        color: #1c5ea8;
    }

    .status-badge.live,
    .status-badge.published {
        background: #ecfdf5;
        border: 1px solid #a7f3d0;
        color: #047857;
    }

    .status-badge.draft,
    .status-badge.under_review {
        background: #eff6ff;
        border: 1px solid #bfdbfe;
        color: #1d4ed8;
    }

    .status-badge.submitted {
        background: #fff7ed;
        border: 1px solid #fdba74;
        color: #c2410c;
    }

    .status-badge.rejected {
        background: #fef2f2;
        border: 1px solid #fecaca;
        color: #b91c1c;
    }

    .empty-state {
        padding: 28px 18px;
        border-radius: 20px;
        background: #f8fbff;
        border: 1px dashed #c9d8e8;
        color: #64768c;
        text-align: center;
    }

    .alert-error {
        border-radius: 20px;
        padding: 14px 16px;
        margin-bottom: 18px;
        font-size: 13px;
        line-height: 1.6;
        background: #fef2f2;
        border: 1px solid #fecaca;
        color: #b91c1c;
    }

    .panel-actions {
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
        margin-top: 18px;
    }

    @media (max-width: 980px) {
        .dashboard-hero {
            grid-template-columns: 1fr;
        }
    }

    @media (max-width: 720px) {
        .dashboard-wrap {
            padding: 24px 16px 44px;
        }

        .hero-card,
        .profile-card,
        .panel {
            padding: 22px;
        }

        .recent-head {
            flex-direction: column;
        }
    }
</style>
@endsection

@section('content')
<div class="dashboard-wrap">
    @if ($loadError)
        <div class="alert-error">{{ $loadError }}</div>
    @endif

    <section class="dashboard-hero">
        <div class="hero-card">
            <span>Admin Panel</span>
            <h1>Selamat datang di dashboard admin Archivix.</h1>
            <p>
                Kelola questions dan documents, tinjau status publikasi, dan pantau aktivitas konten dari satu ruang kerja admin.
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

    <section class="dashboard-grid">
        <div class="panel">
            <h2>Recent Uploads</h2>
            <p>Questions dan documents terbaru yang masuk ke Archivix.</p>

            @if (count($recentUploads) === 0)
                <div class="empty-state">Belum ada upload terbaru untuk ditampilkan.</div>
            @else
                <div class="recent-list">
                    @foreach ($recentUploads as $item)
                        <article class="recent-item">
                            <div class="recent-head">
                                <div>
                                    <strong>{{ $item['title'] }}</strong>
                                    <p>{{ $item['excerpt'] !== '' ? $item['excerpt'] : 'No summary available yet.' }}</p>
                                </div>
                                <a href="{{ route('dashboard.posts.show', ['contentType' => $item['type'], 'contentId' => $item['id']]) }}" class="btn btn-secondary">View Detail</a>
                            </div>

                            <div class="badge-row">
                                <span class="type-badge {{ $item['type'] }}">{{ $item['type_label'] }}</span>
                                <span class="status-badge {{ str_replace('-', '_', $item['status']) }}">{{ str_replace('_', ' ', $item['status']) }}</span>
                                <span>+ {{ $item['likes_count'] ?? 0 }}</span>
                                <span>- {{ $item['dislikes_count'] ?? 0 }}</span>
                                <span># {{ $item['comments_count'] ?? 0 }}</span>
                                <span>Category: {{ $item['category_name'] }}</span>
                                <span>Uploaded {{ \Illuminate\Support\Carbon::parse($item['created_at'])->translatedFormat('d M Y H:i') }}</span>
                            </div>
                        </article>
                    @endforeach
                </div>

                <div class="panel-actions">
                    <a href="{{ route('dashboard.posts.index') }}" class="btn btn-primary">View All Content</a>
                </div>
            @endif
        </div>
    </section>
</div>
@endsection
