@extends('layouts.site')
@section('title', 'Content Manager')

@section('styles')
<style>
    .manager-wrap {
        max-width: 1220px;
        margin: 0 auto;
        padding: 34px 20px 56px;
    }

    .manager-header {
        display: grid;
        grid-template-columns: 1.25fr 0.75fr;
        gap: 18px;
        margin-bottom: 22px;
    }

    .hero-card,
    .summary-card,
    .content-card {
        background: rgba(255, 255, 255, 0.95);
        border: 1px solid rgba(214, 222, 234, 0.95);
        border-radius: 28px;
        box-shadow: 0 18px 36px rgba(14, 30, 56, 0.08);
    }

    .hero-card {
        padding: 30px;
        background:
            radial-gradient(circle at top right, rgba(124, 194, 255, 0.24), transparent 30%),
            linear-gradient(135deg, #132238 0%, #1a3250 58%, #21476f 100%);
        color: #f7fbff;
    }

    .hero-card span {
        display: inline-block;
        margin-bottom: 14px;
        padding: 8px 14px;
        border-radius: 999px;
        background: rgba(255, 255, 255, 0.12);
        color: #cfe6ff;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }

    .hero-card h1 {
        font-size: clamp(28px, 4vw, 40px);
        line-height: 1.06;
        letter-spacing: -0.04em;
        margin-bottom: 12px;
    }

    .hero-card p {
        max-width: 640px;
        color: rgba(247, 251, 255, 0.82);
        line-height: 1.75;
        margin-bottom: 18px;
    }

    .hero-actions {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
    }

    .summary-card {
        padding: 24px;
    }

    .summary-card h2 {
        font-size: 18px;
        margin-bottom: 14px;
    }

    .summary-grid {
        display: grid;
        gap: 12px;
    }

    .summary-item {
        padding: 14px 16px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .summary-item strong {
        display: block;
        font-size: 12px;
        color: #5f7187;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        margin-bottom: 4px;
    }

    .summary-item span {
        font-size: 28px;
        font-weight: 800;
        color: #122031;
    }

    .alert {
        border-radius: 20px;
        padding: 14px 16px;
        margin-bottom: 18px;
        font-size: 13px;
        line-height: 1.6;
    }

    .alert-success {
        background: #ecfdf5;
        border: 1px solid #a7f3d0;
        color: #047857;
    }

    .alert-error {
        background: #fef2f2;
        border: 1px solid #fecaca;
        color: #b91c1c;
    }

    .content-card {
        padding: 24px;
    }

    .toolbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 14px;
        flex-wrap: wrap;
        margin-bottom: 16px;
    }

    .toolbar h2 {
        font-size: 22px;
        margin-bottom: 4px;
    }

    .toolbar p {
        color: #64768c;
        line-height: 1.7;
    }

    .filter-bar {
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
    }

    .filter-pill {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        padding: 10px 14px;
        border-radius: 999px;
        border: 1px solid #d7e1ec;
        background: #f8fbff;
        color: #4d6077;
        text-decoration: none;
        font-size: 13px;
        font-weight: 800;
    }

    .filter-pill.active {
        background: linear-gradient(135deg, #3793ff 0%, #1d72da 100%);
        border-color: #1d72da;
        color: #ffffff;
        box-shadow: 0 12px 24px rgba(29, 114, 218, 0.22);
    }

    .content-table {
        width: 100%;
        border-collapse: separate;
        border-spacing: 0;
    }

    .content-table th,
    .content-table td {
        text-align: left;
        padding: 16px 14px;
        border-bottom: 1px solid #e3ebf4;
        vertical-align: top;
    }

    .content-table th {
        font-size: 12px;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: #697b91;
    }

    .content-title {
        font-size: 15px;
        font-weight: 800;
        color: #132238;
        margin-bottom: 6px;
    }

    .content-excerpt {
        color: #5f7187;
        font-size: 13px;
        line-height: 1.65;
        max-width: 420px;
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

    .status-badge.draft {
        background: #eff6ff;
        border: 1px solid #bfdbfe;
        color: #1d4ed8;
    }

    .status-badge.archived {
        background: #f3f4f6;
        border: 1px solid #d1d5db;
        color: #4b5563;
    }

    .meta-stack {
        display: grid;
        gap: 4px;
        color: #5f7187;
        font-size: 13px;
    }

    .actions {
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
    }

    .action-form {
        margin: 0;
    }

    .empty-state {
        padding: 32px 18px;
        text-align: center;
        color: #64768c;
    }

    @media (max-width: 980px) {
        .manager-header {
            grid-template-columns: 1fr;
        }
    }

    @media (max-width: 900px) {
        .content-table,
        .content-table thead,
        .content-table tbody,
        .content-table tr,
        .content-table th,
        .content-table td {
            display: block;
            width: 100%;
        }

        .content-table thead {
            display: none;
        }

        .content-table tr {
            border: 1px solid #e3ebf4;
            border-radius: 22px;
            margin-bottom: 14px;
            padding: 6px 0;
        }

        .content-table td {
            border-bottom: none;
            padding: 10px 14px;
        }
    }
</style>
@endsection

@section('content')
<div class="manager-wrap">
    @if (session('success'))
        <div class="alert alert-success">{{ session('success') }}</div>
    @endif

    @if ($errors->any())
        <div class="alert alert-error">{{ $errors->first() }}</div>
    @endif

    @if ($loadError)
        <div class="alert alert-error">{{ $loadError }}</div>
    @endif

    <section class="manager-header">
        <div class="hero-card">
            <span>Content Control</span>
            <h1>Kelola questions dan documents dari Supabase.</h1>
            <p>
                Halaman ini adalah meja kerja admin pertama untuk meninjau konten, membuka form edit,
                menerbitkan dokumen yang belum live, dan menghapus item yang memang harus dihapus.
            </p>

            <div class="hero-actions">
                <a href="{{ route('dashboard') }}" class="btn btn-secondary">Kembali ke Dashboard</a>
                <a href="{{ route('dashboard.posts.index', ['filter' => 'all']) }}" class="btn btn-primary">Muat Ulang Daftar</a>
            </div>
        </div>

        <div class="summary-card">
            <h2>Ringkasan Konten</h2>

            <div class="summary-grid">
                <div class="summary-item">
                    <strong>Total Visible</strong>
                    <span>{{ $stats['total'] }}</span>
                </div>

                <div class="summary-item">
                    <strong>Questions</strong>
                    <span>{{ $stats['posts'] }}</span>
                </div>

                <div class="summary-item">
                    <strong>Documents</strong>
                    <span>{{ $stats['papers'] }}</span>
                </div>

                <div class="summary-item">
                    <strong>Published Documents</strong>
                    <span>{{ $stats['published_papers'] }}</span>
                </div>
            </div>
        </div>
    </section>

    <section class="content-card">
        <div class="toolbar">
            <div>
                <h2>/dashboard/posts</h2>
                <p>Filter daftar ini untuk fokus pada questions atau documents. Semua aksi edit, publish, dan delete berjalan dari sini.</p>
            </div>

            <div class="filter-bar">
                <a href="{{ route('dashboard.posts.index', ['filter' => 'all']) }}" class="filter-pill {{ $filter === 'all' ? 'active' : '' }}">All Content</a>
                <a href="{{ route('dashboard.posts.index', ['filter' => 'posts']) }}" class="filter-pill {{ $filter === 'posts' ? 'active' : '' }}">Questions</a>
                <a href="{{ route('dashboard.posts.index', ['filter' => 'papers']) }}" class="filter-pill {{ $filter === 'papers' ? 'active' : '' }}">Documents</a>
            </div>
        </div>

        @if (count($items) === 0)
            <div class="empty-state">
                <h3>Belum ada konten untuk filter ini.</h3>
                <p>Setelah ada questions atau documents di Supabase, daftarnya akan muncul di sini.</p>
            </div>
        @else
            <table class="content-table">
                <thead>
                    <tr>
                        <th>Type</th>
                        <th>Title</th>
                        <th>Status</th>
                        <th>Category</th>
                        <th>Owner</th>
                        <th>Views</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($items as $item)
                        <tr>
                            <td>
                                <span class="type-badge {{ $item['type'] }}">{{ $item['type_label'] }}</span>
                            </td>
                            <td>
                                <div class="content-title">{{ $item['title'] }}</div>
                                <div class="content-excerpt">{{ $item['excerpt'] !== '' ? $item['excerpt'] : 'No summary available yet.' }}</div>
                            </td>
                            <td>
                                <div class="meta-stack">
                                    <div>
                                        <span class="status-badge {{ $item['status'] }}">{{ $item['status'] }}</span>
                                    </div>
                                    <span>Dibuat {{ \Illuminate\Support\Carbon::parse($item['created_at'])->translatedFormat('d M Y H:i') }}</span>
                                    @if (($item['published_at'] ?? null) !== null)
                                        <span>Published {{ \Illuminate\Support\Carbon::parse($item['published_at'])->translatedFormat('d M Y H:i') }}</span>
                                    @endif
                                </div>
                            </td>
                            <td>{{ $item['category_name'] }}</td>
                            <td><code>{{ $item['user_id'] }}</code></td>
                            <td>{{ $item['views_count'] }}</td>
                            <td>
                                <div class="actions">
                                    <a href="{{ route('dashboard.posts.edit', ['contentType' => $item['type'], 'contentId' => $item['id']]) }}" class="btn btn-secondary">Edit</a>

                                    @if ($item['type'] === 'paper' && $item['status'] !== 'published')
                                        <form action="{{ route('dashboard.posts.publish', ['contentId' => $item['id']]) }}" method="POST" class="action-form">
                                            @csrf
                                            <button type="submit" class="btn btn-primary">Publish</button>
                                        </form>
                                    @endif

                                    <form action="{{ route('dashboard.posts.destroy', ['contentType' => $item['type'], 'contentId' => $item['id']]) }}" method="POST" class="action-form" onsubmit="return confirm('Delete this item from Supabase?');">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="btn btn-danger">Delete</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        @endif
    </section>
</div>
@endsection
