@extends('layouts.site')
@section('title', 'Browse Archive')

@section('styles')
<style>
    .browse-wrap {
        max-width: 1080px;
        margin: 0 auto;
        padding: 34px 20px 56px;
    }

    .browse-search,
    .result-card,
    .empty-state,
    .alert-error {
        border-radius: 4px;
        border: 1px solid #c4cad3;
        background: #ffffff;
        box-shadow: none;
    }

    .browse-search {
        padding: 18px;
        margin-bottom: 18px;
    }

    .browse-search h1 {
        margin-bottom: 6px;
        font-size: 22px;
        color: #1f2937;
    }

    .browse-search p {
        max-width: 720px;
        margin-bottom: 16px;
        color: #6b7280;
        font-size: 13px;
        line-height: 1.7;
    }

    .search-grid {
        display: grid;
        grid-template-columns: minmax(220px, 1fr) 190px 220px auto;
        gap: 10px;
        align-items: end;
    }

    .form-control {
        width: 100%;
        min-height: 40px;
        padding: 9px 12px;
        border: 1px solid #9ca3af;
        border-radius: 4px;
        background: #ffffff;
        color: #1f2937;
        font: inherit;
        box-shadow: inset 1px 1px 2px rgba(0, 0, 0, 0.08);
    }

    .field-label {
        display: block;
        margin-bottom: 6px;
        font-size: 12px;
        font-weight: 700;
        color: #4a5568;
    }

    .result-head {
        display: flex;
        align-items: center;
        gap: 10px;
        margin: 18px 0 12px;
    }

    .result-marker {
        width: 3px;
        height: 28px;
        background: #4a5568;
    }

    .result-head h2 {
        font-size: 18px;
        margin-bottom: 2px;
    }

    .result-head p {
        color: #6b7280;
        font-size: 12px;
    }

    .result-list {
        display: grid;
        gap: 12px;
    }

    .result-card {
        padding: 16px;
    }

    .result-card.question {
        background: #fff9e6;
        border-color: #fcd34d;
    }

    .type-badge,
    .meta-chip {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        border-radius: 4px;
        border: 1px solid #b5bbc6;
        padding: 5px 8px;
        font-size: 11px;
        font-weight: 700;
    }

    .type-badge.document {
        background: #f3f4f6;
        color: #4a5568;
    }

    .type-badge.question {
        background: #fff3c4;
        border-color: #f0c454;
        color: #92400e;
    }

    .result-card h3 {
        margin: 10px 0 6px;
        font-size: 17px;
        line-height: 1.35;
        color: #1f2937;
    }

    .byline,
    .excerpt,
    .meta-row {
        color: #6b7280;
        font-size: 12px;
    }

    .excerpt {
        margin-top: 8px;
        line-height: 1.6;
    }

    .meta-row {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        align-items: center;
        margin-top: 12px;
    }

    .meta-chip {
        background: #f3f4f6;
        color: #4a5568;
        font-weight: 500;
    }

    .card-actions {
        margin-top: 14px;
    }

    .guest-note {
        margin-top: 14px;
        padding: 10px 12px;
        border: 1px solid #d1d5db;
        border-radius: 4px;
        background: #f7f7f4;
        color: #6b7280;
        font-size: 12px;
        line-height: 1.55;
    }

    .empty-state,
    .alert-error {
        padding: 24px 18px;
        color: #6b7280;
        text-align: center;
    }

    .alert-error {
        margin-bottom: 18px;
        border-color: #fecaca;
        background: #fef2f2;
        color: #b91c1c;
    }

    @media (max-width: 900px) {
        .search-grid {
            grid-template-columns: 1fr 1fr;
        }
    }

    @media (max-width: 620px) {
        .browse-wrap {
            padding: 24px 16px 44px;
        }

        .search-grid {
            grid-template-columns: 1fr;
        }
    }
</style>
@endsection

@section('content')
@php
    $isGuest = ! session()->has('admin_user') && ! session()->has('web_user');
    $formatDate = function (?string $value): string {
        if (! $value) {
            return 'Unknown date';
        }

        return \Illuminate\Support\Carbon::parse($value)->diffForHumans();
    };
    $contentLabel = match ($filter) {
        'papers' => 'documents',
        'posts' => 'questions',
        default => 'documents and questions',
    };
@endphp

<div class="browse-wrap">
    @if ($loadError)
        <div class="alert-error">{{ $loadError }}</div>
    @endif

    <section class="browse-search">
        <h1>Find documents and questions</h1>
        <p>Search by title, abstract, or question content, then narrow the archive by category or result type.</p>

        <form action="{{ route('browse.index') }}" method="GET" class="search-grid">
            <div>
                <label for="q" class="field-label">Search</label>
                <input
                    id="q"
                    name="q"
                    value="{{ $query }}"
                    class="form-control"
                    placeholder="Try a keyword or title..."
                >
            </div>

            <div>
                <label for="filter" class="field-label">Result Type</label>
                <select id="filter" name="filter" class="form-control">
                    <option value="all" @selected($filter === 'all')>All</option>
                    <option value="papers" @selected($filter === 'papers')>Documents only</option>
                    <option value="posts" @selected($filter === 'posts')>Questions only</option>
                </select>
            </div>

            <div>
                <label for="category" class="field-label">Category</label>
                <select id="category" name="category" class="form-control">
                    <option value="all" @selected($categoryId === 'all' || $categoryId === '')>All categories</option>
                    @foreach ($categories as $category)
                        <option value="{{ $category['id'] }}" @selected($categoryId === $category['id'])>{{ $category['name'] }}</option>
                    @endforeach
                </select>
            </div>

            <button type="submit" class="btn btn-primary">Search</button>
        </form>

        @if ($isGuest)
            <div class="guest-note">
                Guests can read document and question pages here. Sign in to download files, comment, view version history, or react.
            </div>
        @endif
    </section>

    <section>
        <div class="result-head">
            <div class="result-marker"></div>
            <div>
                <h2>{{ $query === '' ? 'Explore Archive' : 'Search Results' }}</h2>
                <p>
                    @if ($query === '')
                        Showing {{ $stats['total'] }} recent {{ $contentLabel }}.
                    @else
                        Showing {{ $stats['total'] }} result(s) for "{{ $query }}".
                    @endif
                </p>
            </div>
        </div>

        @if (count($items) === 0)
            <div class="empty-state">
                No {{ $contentLabel }} match the current filters yet. Try a different keyword, category, or result type.
            </div>
        @else
            <div class="result-list">
                @foreach ($items as $item)
                    @php
                        $isPaper = ($item['type'] ?? '') === 'paper';
                        $detailUrl = route('content.show', ['contentType' => $item['type'], 'contentId' => $item['id']]);
                    @endphp

                    <article class="result-card {{ $isPaper ? 'document' : 'question' }}">
                        <span class="type-badge {{ $isPaper ? 'document' : 'question' }}">
                            {{ $isPaper ? 'Document' : 'Question' }}
                        </span>

                        <h3>{{ $item['title'] }}</h3>

                        @if ($isPaper)
                            <div class="byline">{{ $item['authors_label'] ?? 'Unknown author' }}</div>
                        @endif

                        <p class="excerpt">{{ $item['excerpt'] !== '' ? $item['excerpt'] : 'No summary available yet.' }}</p>

                        <div class="meta-row">
                            <span class="meta-chip">{{ $item['category_name'] }}</span>
                            <span>{{ $formatDate($item['published_at'] ?? $item['created_at'] ?? null) }}</span>
                            <span>{{ $item['views_count'] ?? 0 }} views</span>
                            <span>{{ $item['comments_count'] ?? 0 }} comments</span>
                            @if ($isPaper)
                                <span>{{ $item['likes_count'] ?? 0 }} likes</span>
                            @else
                                <span>{{ $item['likes_count'] ?? 0 }} likes</span>
                                <span>{{ $item['dislikes_count'] ?? 0 }} dislikes</span>
                            @endif
                        </div>

                        <div class="card-actions">
                            <a href="{{ $detailUrl }}" class="btn btn-secondary">View</a>
                        </div>
                    </article>
                @endforeach
            </div>
        @endif
    </section>
</div>
@endsection
