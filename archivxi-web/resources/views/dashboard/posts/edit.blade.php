@extends('layouts.site')
@section('title', 'Edit Content')

@section('styles')
<style>
    .edit-wrap {
        max-width: 980px;
        margin: 0 auto;
        padding: 34px 20px 56px;
    }

    .edit-grid {
        display: grid;
        grid-template-columns: 0.72fr 1.28fr;
        gap: 18px;
        align-items: start;
    }

    .panel {
        padding: 26px;
        border-radius: 28px;
        background: rgba(255, 255, 255, 0.95);
        border: 1px solid rgba(214, 222, 234, 0.95);
        box-shadow: 0 18px 36px rgba(14, 30, 56, 0.08);
    }

    .panel h1,
    .panel h2 {
        margin-bottom: 8px;
    }

    .panel p {
        color: #64768c;
        line-height: 1.7;
        margin-bottom: 16px;
    }

    .meta-card {
        padding: 14px 16px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
        margin-bottom: 12px;
    }

    .meta-card strong {
        display: block;
        margin-bottom: 4px;
        font-size: 12px;
        color: #5f7187;
        text-transform: uppercase;
        letter-spacing: 0.06em;
    }

    .meta-card span,
    .meta-card code {
        font-size: 14px;
        color: #182433;
        word-break: break-word;
    }

    .textarea-lg {
        min-height: 220px;
    }

    .form-actions {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
        margin-top: 6px;
    }

    .alert {
        border-radius: 20px;
        padding: 14px 16px;
        margin-bottom: 18px;
        font-size: 13px;
        line-height: 1.6;
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

    .file-stack {
        display: grid;
        gap: 10px;
        margin-bottom: 16px;
    }

    .file-card {
        padding: 12px 14px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .file-card strong {
        display: block;
        margin-bottom: 4px;
        font-size: 13px;
    }

    .file-card span {
        color: #64768c;
        font-size: 12px;
        line-height: 1.6;
    }

    .keep-row {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-top: 8px;
        color: #42566d;
        font-size: 12px;
        font-weight: 700;
    }

    .history-block {
        margin-top: 20px;
        padding-top: 18px;
        border-top: 1px solid #dfe8f2;
    }

    @media (max-width: 940px) {
        .edit-grid {
            grid-template-columns: 1fr;
        }
    }
</style>
@endsection

@section('content')
<div class="edit-wrap">
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

    <div class="edit-grid">
        <section class="panel">
            <h2>Item Context</h2>
            <p>Ringkasan cepat sebelum kamu simpan perubahan ke Supabase.</p>

            <div class="meta-card">
                <strong>Type</strong>
                <span>{{ $item['type_label'] }}</span>
            </div>

            <div class="meta-card">
                <strong>Owner ID</strong>
                <code>{{ $item['user_id'] }}</code>
            </div>

            <div class="meta-card">
                <strong>Category</strong>
                <span>{{ $item['category_name'] }}</span>
            </div>

            <div class="meta-card">
                <strong>Created</strong>
                <span>{{ \Illuminate\Support\Carbon::parse($item['created_at'])->translatedFormat('d M Y H:i') }}</span>
            </div>

            @if ($item['type'] === 'post')
                <div class="meta-card">
                    <strong>Attachments</strong>
                    <span>{{ count($item['attachments'] ?? []) }} file(s) currently attached</span>
                </div>
            @else
                <div class="meta-card">
                    <strong>Status</strong>
                    <span>{{ $item['status'] }}</span>
                </div>

                <div class="meta-card">
                    <strong>Published At</strong>
                    <span>
                        {{ $item['published_at'] ? \Illuminate\Support\Carbon::parse($item['published_at'])->translatedFormat('d M Y H:i') : 'Not published yet' }}
                    </span>
                </div>

                <div class="meta-card">
                    <strong>Submitted At</strong>
                    <span>
                        {{ ($item['submitted_at'] ?? null) ? \Illuminate\Support\Carbon::parse($item['submitted_at'])->translatedFormat('d M Y H:i') : 'Not submitted yet' }}
                    </span>
                </div>

                <div class="meta-card">
                    <strong>Reviewed At</strong>
                    <span>
                        {{ ($item['reviewed_at'] ?? null) ? \Illuminate\Support\Carbon::parse($item['reviewed_at'])->translatedFormat('d M Y H:i') : 'No review decision yet' }}
                    </span>
                </div>

                <div class="meta-card">
                    <strong>Rejection Reason</strong>
                    <span>{{ $item['rejection_reason'] !== '' ? $item['rejection_reason'] : 'No rejection feedback saved' }}</span>
                </div>

                <div class="meta-card">
                    <strong>PDF File</strong>
                    <span>{{ $item['pdf_file_name'] !== '' ? $item['pdf_file_name'] : 'No file name recorded' }}</span>
                </div>
            @endif
        </section>

        <section class="panel">
            <h1>Edit {{ $item['type_label'] }}</h1>
            <p>Perubahan di halaman ini akan dikirim langsung ke Supabase memakai kredensial admin Laravel, lalu versi sebelumnya diarsipkan sebelum file atau isi konten diganti.</p>

            <form action="{{ route('dashboard.posts.update', ['contentType' => $item['type'], 'contentId' => $item['id']]) }}" method="POST" enctype="multipart/form-data">
                @csrf
                @method('PUT')

                <label class="form-label">Title</label>
                <input
                    type="text"
                    name="title"
                    class="form-input"
                    value="{{ old('title', $item['title']) }}"
                    required
                >

                <label class="form-label">Category</label>
                <select name="category_id" class="form-input">
                    <option value="">No category</option>
                    @foreach ($categories as $category)
                        <option
                            value="{{ $category['id'] }}"
                            @selected(old('category_id', $item['category_id']) === $category['id'])
                        >
                            {{ $category['name'] }}
                        </option>
                    @endforeach
                </select>

                @if ($item['type'] === 'post')
                    <label class="form-label">Question Details</label>
                    <textarea name="content" class="form-input textarea-lg" required>{{ old('content', $item['content']) }}</textarea>

                    <label class="form-label">Current Attachments</label>
                    @if (count($item['attachments'] ?? []) === 0)
                        <div class="file-card" style="margin-bottom: 16px;">
                            <strong>No attachments yet</strong>
                            <span>This question currently has no attached files.</span>
                        </div>
                    @else
                        <div class="file-stack">
                            @foreach ($item['attachments'] as $attachment)
                                @php
                                    $keptIds = old('keep_attachment_ids', collect($item['attachments'])->pluck('id')->all());
                                @endphp
                                <div class="file-card">
                                    <strong>{{ $attachment['file_name'] ?? 'Unnamed file' }}</strong>
                                    <span>
                                        {{ strtoupper($attachment['file_type'] ?? 'document') }}
                                        @if (($attachment['file_size'] ?? null) !== null)
                                            · {{ number_format(((int) $attachment['file_size']) / 1024, 1) }} KB
                                        @endif
                                    </span>
                                    <label class="keep-row">
                                        <input
                                            type="checkbox"
                                            name="keep_attachment_ids[]"
                                            value="{{ $attachment['id'] }}"
                                            @checked(in_array($attachment['id'], $keptIds, true))
                                        >
                                        Keep this file
                                    </label>
                                </div>
                            @endforeach
                        </div>
                    @endif

                    <label class="form-label">Add New Attachments</label>
                    <input
                        type="file"
                        name="attachments[]"
                        class="form-input"
                        multiple
                    >
                    <p style="color:#64768c;font-size:12px;margin-top:-8px;margin-bottom:16px;">
                        Unchecked files will be removed from the live question, but the previous version will still keep their archived snapshot.
                    </p>
                @else
                    <label class="form-label">Abstract</label>
                    <textarea name="abstract" class="form-input textarea-lg" required>{{ old('abstract', $item['abstract']) }}</textarea>

                    <label class="form-label">Replace PDF</label>
                    <input
                        type="file"
                        name="replacement_pdf"
                        class="form-input"
                        accept="application/pdf"
                    >
                    <p style="color:#64768c;font-size:12px;margin-top:-8px;margin-bottom:16px;">
                        Upload a new PDF to replace the live document file. Laravel will archive the current PDF version before switching it.
                    </p>
                @endif

                <div class="form-actions">
                    <a href="{{ route('dashboard.posts.index', ['filter' => $item['type'] === 'post' ? 'posts' : 'papers']) }}" class="btn btn-secondary">Cancel</a>
                    <button type="submit" class="btn btn-primary">Save Changes</button>
                </div>
            </form>

            @if ($item['type'] === 'paper')
                <div class="history-block">
                    <h2>Review Actions</h2>
                    <p>Jalankan workflow review admin dari halaman web ini supaya document moderation tetap terpusat di Laravel.</p>

                    <div class="form-actions">
                        @if ($item['status'] !== 'under_review')
                            <form action="{{ route('dashboard.posts.under-review', ['contentId' => $item['id']]) }}" method="POST">
                                @csrf
                                <button type="submit" class="btn btn-secondary">Mark Under Review</button>
                            </form>
                        @endif

                        @if ($item['status'] !== 'published')
                            <form action="{{ route('dashboard.posts.publish', ['contentId' => $item['id']]) }}" method="POST">
                                @csrf
                                <button type="submit" class="btn btn-primary">Publish Document</button>
                            </form>
                        @endif
                    </div>

                    <form action="{{ route('dashboard.posts.reject', ['contentId' => $item['id']]) }}" method="POST" style="margin-top: 14px;">
                        @csrf
                        <label class="form-label">Reject With Reason</label>
                        <textarea
                            name="rejection_reason"
                            class="form-input"
                            placeholder="Tulis catatan revisi untuk author..."
                            required
                        >{{ old('rejection_reason', $item['status'] === 'rejected' ? $item['rejection_reason'] : '') }}</textarea>
                        <div class="form-actions">
                            <button type="submit" class="btn btn-danger">Reject Document</button>
                        </div>
                    </form>
                </div>
            @endif

            @if ($item['type'] === 'post')
                <div class="history-block">
                    <h2>Archived Versions</h2>
                    <p>Setiap kali file atau isi question diubah, versi sebelumnya tetap tersimpan di sini.</p>

                    @if (count($versions) === 0)
                        <div class="file-card">
                            <strong>No archived versions yet</strong>
                            <span>Version history will appear here after the next saved change.</span>
                        </div>
                    @else
                        <div class="file-stack">
                            @foreach ($versions as $version)
                                <div class="file-card">
                                    <strong>Version {{ $version['version_number'] }} · {{ $version['title'] }}</strong>
                                    <span>
                                        {{ $version['created_at'] !== '' ? \Illuminate\Support\Carbon::parse($version['created_at'])->translatedFormat('d M Y H:i') : 'Unknown time' }}
                                        @if ($version['category_name'] !== '')
                                            · {{ $version['category_name'] }}
                                        @endif
                                    </span>

                                    @if (count($version['attachments']) === 0)
                                        <div class="keep-row" style="margin-top: 10px;">
                                            <span>No archived attachments in this version.</span>
                                        </div>
                                    @else
                                        <div class="form-actions" style="margin-top: 10px;">
                                            @foreach ($version['attachments'] as $attachment)
                                                <a
                                                    href="{{ $attachment['view_url'] }}"
                                                    target="_blank"
                                                    rel="noopener noreferrer"
                                                    class="btn btn-secondary"
                                                >
                                                    {{ $attachment['file_name'] ?? 'Open Attachment' }}
                                                </a>
                                            @endforeach
                                        </div>
                                    @endif
                                </div>
                            @endforeach
                        </div>
                    @endif
                </div>
            @endif
        </section>
    </div>
</div>
@endsection
