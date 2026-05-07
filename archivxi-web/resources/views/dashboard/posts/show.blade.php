@extends('layouts.site')
@section('title', $item['title'] ?? 'Content Detail')

@section('styles')
<style>
    .detail-wrap {
        max-width: 1100px;
        margin: 0 auto;
        padding: 34px 20px 56px;
    }

    .detail-hero,
    .detail-card {
        border-radius: 28px;
        border: 1px solid rgba(214, 222, 234, 0.95);
        box-shadow: 0 18px 36px rgba(14, 30, 56, 0.08);
    }

    .detail-hero {
        padding: 30px;
        margin-bottom: 18px;
        background:
            radial-gradient(circle at top right, rgba(124, 194, 255, 0.24), transparent 30%),
            linear-gradient(135deg, #132238 0%, #1a3250 58%, #21476f 100%);
        color: #f7fbff;
    }

    .detail-hero h1 {
        max-width: 820px;
        font-size: clamp(28px, 4vw, 42px);
        line-height: 1.08;
        letter-spacing: -0.04em;
        margin-bottom: 12px;
    }

    .detail-hero p {
        max-width: 760px;
        color: rgba(247, 251, 255, 0.80);
        line-height: 1.75;
        margin-bottom: 18px;
    }

    .detail-grid {
        display: grid;
        grid-template-columns: 1.35fr 0.65fr;
        gap: 18px;
    }

    .detail-card {
        padding: 26px;
        background: rgba(255, 255, 255, 0.95);
    }

    .detail-card h2 {
        font-size: 20px;
        margin-bottom: 10px;
        color: #132238;
    }

    .body-copy {
        color: #4d6077;
        line-height: 1.8;
        white-space: pre-wrap;
    }

    .meta-list,
    .asset-list {
        display: grid;
        gap: 12px;
    }

    .meta-item,
    .asset-item {
        padding: 14px 16px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .meta-item strong,
    .asset-item strong {
        display: block;
        margin-bottom: 4px;
        color: #132238;
        font-size: 13px;
    }

    .meta-item span,
    .asset-item span {
        color: #697b91;
        font-size: 13px;
        line-height: 1.65;
        word-break: break-word;
    }

    .actions {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
    }

    .engagement-bar {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        margin-bottom: 18px;
    }

    .engagement-form {
        margin: 0;
    }

    .engagement-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        min-height: 42px;
        padding: 9px 14px;
        border-radius: 999px;
        border: 1px solid #d7e1ec;
        background: #f8fbff;
        color: #4d6077;
        font-family: inherit;
        font-size: 13px;
        font-weight: 800;
        cursor: pointer;
    }

    .engagement-btn.active {
        border-color: #1d72da;
        background: #eef6ff;
        color: #1d72da;
    }

    .comment-form {
        display: grid;
        gap: 10px;
        margin-bottom: 18px;
    }

    .comment-form textarea {
        min-height: 110px;
        width: 100%;
        padding: 12px 14px;
        border: 1px solid #d6deea;
        border-radius: 16px;
        background: #f8fbff;
        color: #132238;
        font-family: inherit;
        resize: vertical;
    }

    .comment-card {
        padding: 16px 18px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .comment-card strong {
        display: block;
        margin-bottom: 4px;
        color: #132238;
    }

    .comment-card span {
        display: block;
        margin-bottom: 8px;
        color: #7b8a9f;
        font-size: 12px;
    }

    .comment-card p {
        color: #4d6077;
        line-height: 1.75;
        margin: 0;
        white-space: pre-wrap;
    }

    .alert {
        border-radius: 18px;
        padding: 12px 14px;
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
        padding: 24px 18px;
        border-radius: 20px;
        background: #f8fbff;
        border: 1px dashed #c9d8e8;
        color: #64768c;
        text-align: center;
    }

    @media (max-width: 980px) {
        .detail-grid {
            grid-template-columns: 1fr;
        }
    }

    @media (max-width: 720px) {
        .detail-wrap {
            padding: 24px 16px 44px;
        }

        .detail-hero,
        .detail-card {
            padding: 22px;
        }

    }
</style>
@endsection

@section('content')
@php
    $isPaper = ($item['type'] ?? '') === 'paper';
    $canManage = session()->has('admin_user');
    $routeBase = $canManage ? 'dashboard.posts' : 'content';
    $backUrl = $canManage ? route('dashboard.posts.index') : route('user.dashboard');
    $mainBody = $isPaper ? ($item['abstract'] ?? '') : ($item['content'] ?? '');
    $status = $isPaper ? ($item['status'] ?? 'draft') : 'live';
    $formatDate = function (?string $value): string {
        return $value
            ? \Illuminate\Support\Carbon::parse($value)->translatedFormat('d M Y H:i')
            : 'Not available';
    };
    $formatBytes = function ($bytes): string {
        if ($bytes === null || $bytes === '') {
            return 'Unknown size';
        }

        $bytes = (int) $bytes;
        if ($bytes >= 1048576) {
            return number_format($bytes / 1048576, 2).' MB';
        }

        if ($bytes >= 1024) {
            return number_format($bytes / 1024, 2).' KB';
        }

        return $bytes.' B';
    };
@endphp

<div class="detail-wrap">
    @if (session('success'))
        <div class="alert alert-success">{{ session('success') }}</div>
    @endif

    @if ($errors->any())
        <div class="alert alert-error">{{ $errors->first() }}</div>
    @endif

    <section class="detail-hero">
        <h1>{{ $item['title'] }}</h1>
        <p>{{ \Illuminate\Support\Str::limit(trim($mainBody), 220) ?: 'No summary available yet.' }}</p>

        <div class="actions">
            <span class="type-badge {{ $item['type'] }}">{{ $item['type_label'] }}</span>
            <span class="status-badge {{ str_replace('-', '_', $status) }}">{{ str_replace('_', ' ', $status) }}</span>
            <a href="{{ $backUrl }}" class="btn btn-secondary">Back</a>
            @if ($canManage)
                <a href="{{ route('dashboard.posts.edit', ['contentType' => $item['type'], 'contentId' => $item['id']]) }}" class="btn btn-primary">Edit</a>
            @endif
        </div>
    </section>

    <section class="detail-card" style="margin-bottom: 18px;">
        <h2>Engagement</h2>
        <div class="engagement-bar">
            <form class="engagement-form" action="{{ route($routeBase.'.react', ['contentType' => $item['type'], 'contentId' => $item['id']]) }}" method="POST">
                @csrf
                <input type="hidden" name="reaction_value" value="1">
                <button type="submit" class="engagement-btn {{ ($item['user_reaction'] ?? null) === 1 ? 'active' : '' }}">
                    <span aria-hidden="true">+</span>
                    <span>{{ $item['likes_count'] ?? 0 }} likes</span>
                </button>
            </form>

            <form class="engagement-form" action="{{ route($routeBase.'.react', ['contentType' => $item['type'], 'contentId' => $item['id']]) }}" method="POST">
                @csrf
                <input type="hidden" name="reaction_value" value="-1">
                <button type="submit" class="engagement-btn {{ ($item['user_reaction'] ?? null) === -1 ? 'active' : '' }}">
                    <span aria-hidden="true">-</span>
                    <span>{{ $item['dislikes_count'] ?? 0 }} dislikes</span>
                </button>
            </form>

            <div class="engagement-btn" aria-label="Comment count">
                <span aria-hidden="true">#</span>
                <span>{{ $item['comments_count'] ?? count($item['comments'] ?? []) }} comments</span>
            </div>
        </div>
    </section>

    <section class="detail-grid">
        <article class="detail-card">
            <h2>{{ $isPaper ? 'Document Abstract' : 'Question Content' }}</h2>
            <div class="body-copy">{{ $mainBody !== '' ? $mainBody : 'No content available.' }}</div>
        </article>

        <aside class="detail-card">
            <h2>Content Info</h2>
            <div class="meta-list">
                <div class="meta-item">
                    <strong>Category</strong>
                    <span>{{ $item['category_name'] }}</span>
                </div>
                <div class="meta-item">
                    <strong>Owner ID</strong>
                    <span>{{ $item['user_id'] }}</span>
                </div>
                <div class="meta-item">
                    <strong>Views</strong>
                    <span>{{ $item['views_count'] }}</span>
                </div>
                <div class="meta-item">
                    <strong>Uploaded</strong>
                    <span>{{ $formatDate($item['created_at'] ?? null) }}</span>
                </div>
                @if ($isPaper)
                    <div class="meta-item">
                        <strong>Submitted</strong>
                        <span>{{ $formatDate($item['submitted_at'] ?? null) }}</span>
                    </div>
                    <div class="meta-item">
                        <strong>Published</strong>
                        <span>{{ $formatDate($item['published_at'] ?? null) }}</span>
                    </div>
                @endif
            </div>
        </aside>
    </section>

    <section class="detail-card" style="margin-top: 18px;">
        @if ($isPaper)
            <h2>Document File</h2>
            @if (($item['pdf_view_url'] ?? '') !== '')
                <div class="asset-item" style="margin-bottom: 14px;">
                    <strong>{{ $item['pdf_file_name'] !== '' ? $item['pdf_file_name'] : 'Document PDF' }}</strong>
                    <span>{{ $formatBytes($item['pdf_file_size'] ?? null) }}</span>
                    <div class="actions" style="margin-top: 12px;">
                        <a href="{{ $item['pdf_view_url'] }}" target="_blank" rel="noopener" class="btn btn-secondary">Open PDF</a>
                        <a href="{{ $item['pdf_download_url'] }}" class="btn btn-primary">Download PDF</a>
                    </div>
                </div>
            @else
                <div class="empty-state">No PDF file is attached to this document.</div>
            @endif
        @else
            <h2>Post Attachments</h2>
            @if (count($item['attachments'] ?? []) === 0)
                <div class="empty-state">No files are attached to this question.</div>
            @else
                <div class="asset-list">
                    @foreach ($item['attachments'] as $attachment)
                        <div class="asset-item">
                            <strong>{{ $attachment['file_name'] ?? 'Attachment' }}</strong>
                            <span>{{ $attachment['mime_type'] ?? ($attachment['file_type'] ?? 'File') }} - {{ $formatBytes($attachment['file_size'] ?? null) }}</span>
                            <div class="actions" style="margin-top: 12px;">
                                @if (($attachment['view_url'] ?? '') !== '')
                                    <a href="{{ $attachment['view_url'] }}" target="_blank" rel="noopener" class="btn btn-secondary">Open File</a>
                                @endif
                                @if (($attachment['download_url'] ?? '') !== '')
                                    <a href="{{ $attachment['download_url'] }}" class="btn btn-primary">Download File</a>
                                @endif
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif
        @endif
    </section>

    <section class="detail-card" style="margin-top: 18px;">
        <h2>Comments</h2>

        <form class="comment-form" action="{{ route($routeBase.'.comment', ['contentType' => $item['type'], 'contentId' => $item['id']]) }}" method="POST">
            @csrf
            <textarea name="body" placeholder="Write a comment..." required>{{ old('body') }}</textarea>
            <button type="submit" class="btn btn-primary">Post Comment</button>
        </form>

        @if (count($item['comments'] ?? []) === 0)
            <div class="empty-state">No comments yet. Be the first to comment.</div>
        @else
            <div class="asset-list">
                @foreach ($item['comments'] as $comment)
                    <article class="comment-card">
                        <strong>{{ $comment['author_label'] }}</strong>
                        <span>{{ $formatDate($comment['created_at'] ?? null) }}</span>
                        <p>{{ $comment['body'] }}</p>
                    </article>
                @endforeach
            </div>
        @endif
    </section>
</div>
@endsection
