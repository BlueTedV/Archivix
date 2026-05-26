@extends('layouts.site')
@section('title', 'Download Aplikasi')

@section('styles')
<style>
    .dl-wrap {
        max-width: 960px;
        margin: 0 auto;
        padding: 56px 20px 72px;
    }

    .dl-hero {
        text-align: center;
        margin-bottom: 36px;
    }

    .dl-kicker {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 8px 14px;
        border-radius: 999px;
        background: #eef2ff;
        color: #334155;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }

    .dl-hero h1 {
        margin: 18px 0 12px;
        font-size: clamp(32px, 5vw, 48px);
        line-height: 1.1;
        color: #0f172a;
    }

    .dl-hero p {
        max-width: 680px;
        margin: 0 auto;
        color: #475569;
        font-size: 16px;
        line-height: 1.7;
    }

    .dl-grid {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 20px;
        margin-bottom: 24px;
    }

    .dl-card {
        display: flex;
        flex-direction: column;
        gap: 18px;
        min-height: 100%;
        padding: 28px;
        background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%);
        border: 1px solid #dbe4f0;
        border-radius: 24px;
        box-shadow: 0 20px 50px rgba(15, 23, 42, 0.06);
    }

    .dl-card-head {
        display: flex;
        justify-content: space-between;
        gap: 16px;
        align-items: flex-start;
    }

    .dl-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 68px;
        padding: 8px 12px;
        border-radius: 16px;
        background: #1e293b;
        color: #ffffff;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }

    .dl-card h2 {
        margin: 0 0 6px;
        color: #0f172a;
        font-size: 24px;
    }

    .dl-platform {
        margin: 0;
        color: #64748b;
        font-size: 14px;
    }

    .dl-status {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        width: fit-content;
        padding: 7px 12px;
        border-radius: 999px;
        font-size: 12px;
        font-weight: 700;
    }

    .dl-status--ready {
        background: #dcfce7;
        color: #166534;
    }

    .dl-status--pending {
        background: #e2e8f0;
        color: #475569;
    }

    .dl-meta {
        display: grid;
        gap: 10px;
        padding: 16px 18px;
        border-radius: 18px;
        background: #ffffff;
        border: 1px solid #e2e8f0;
    }

    .dl-meta-row {
        display: flex;
        justify-content: space-between;
        gap: 12px;
        font-size: 14px;
    }

    .dl-meta-label {
        color: #64748b;
    }

    .dl-meta-value {
        color: #0f172a;
        font-weight: 600;
        text-align: right;
    }

    .dl-actions {
        margin-top: auto;
    }

    .dl-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        padding: 13px 18px;
        border-radius: 16px;
        background: #1d4ed8;
        color: #ffffff;
        font-size: 14px;
        font-weight: 700;
        text-decoration: none;
        transition: transform 0.15s ease, box-shadow 0.15s ease, background 0.15s ease;
        box-shadow: 0 16px 30px rgba(29, 78, 216, 0.22);
    }

    .dl-btn:hover {
        background: #1e40af;
        transform: translateY(-1px);
    }

    .dl-btn.is-disabled {
        background: #94a3b8;
        box-shadow: none;
        pointer-events: none;
    }

    .dl-footnote {
        margin-top: 28px;
        padding: 18px 20px;
        border-radius: 18px;
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        color: #475569;
        font-size: 14px;
        line-height: 1.7;
    }

    @media (max-width: 720px) {
        .dl-grid {
            grid-template-columns: 1fr;
        }

        .dl-card {
            padding: 22px;
            border-radius: 20px;
        }

        .dl-card-head,
        .dl-meta-row {
            flex-direction: column;
        }

        .dl-meta-value {
            text-align: left;
        }
    }
</style>
@endsection

@section('content')
<div class="dl-wrap">
    <div class="dl-hero">
        <span class="dl-kicker">ArchivXI Mobile Downloads</span>
        <h1>Unduh aplikasi resmi ArchivXI</h1>
        <p>
            Halaman ini otomatis menampilkan file yang sudah diunggah ke server website.
            Jika tombol aktif, file siap diunduh oleh pengunjung.
        </p>
    </div>

    <div class="dl-grid">
        @foreach ($downloads as $download)
            <article class="dl-card">
                <div class="dl-card-head">
                    <div>
                        <h2>{{ $download['name'] }}</h2>
                        <p class="dl-platform">{{ $download['format'] }} - {{ $download['requirements'] }}</p>
                    </div>
                    <span class="dl-badge">{{ $download['format'] }}</span>
                </div>

                <span class="dl-status {{ $download['is_available'] ? 'dl-status--ready' : 'dl-status--pending' }}">
                    {{ $download['is_available'] ? 'Siap diunduh' : 'Belum tersedia' }}
                </span>

                <div class="dl-meta">
                    <div class="dl-meta-row">
                        <span class="dl-meta-label">Nama file</span>
                        <span class="dl-meta-value">{{ $download['filename'] }}</span>
                    </div>
                    <div class="dl-meta-row">
                        <span class="dl-meta-label">Ukuran</span>
                        <span class="dl-meta-value">{{ $download['size'] ?? '-' }}</span>
                    </div>
                    <div class="dl-meta-row">
                        <span class="dl-meta-label">Terakhir diperbarui</span>
                        <span class="dl-meta-value">{{ $download['updated_at'] ?? '-' }}</span>
                    </div>
                </div>

                <div class="dl-actions">
                    @if ($download['is_available'])
                        <a href="{{ $download['url'] }}" class="dl-btn" download>
                            {{ $download['title'] }}
                        </a>
                    @else
                        <a href="#" class="dl-btn is-disabled" aria-disabled="true">
                            {{ $download['empty_state'] }}
                        </a>
                    @endif
                </div>
            </article>
        @endforeach
    </div>

    <div class="dl-footnote">
        Untuk Android, aktifkan izin instalasi dari sumber lain jika perangkat memintanya.
        Untuk tim internal: unggah file rilis ke folder <strong>public/downloads</strong> dengan nama yang sesuai agar tombol aktif otomatis.
    </div>
</div>
@endsection
