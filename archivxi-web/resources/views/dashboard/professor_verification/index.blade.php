@extends('layouts.site')
@section('title', 'Professor Verification Queue')

@section('styles')
<style>
    .pv-wrap {
        max-width: 1100px;
        margin: 0 auto;
        padding: 34px 20px 56px;
    }

    .pv-hero {
        padding: 30px;
        border-radius: 28px;
        background:
            radial-gradient(circle at top right, rgba(124, 194, 255, 0.22), transparent 30%),
            linear-gradient(135deg, #132238 0%, #1a3250 58%, #21476f 100%);
        color: #f7fbff;
        box-shadow: 0 18px 36px rgba(19, 34, 56, 0.18);
        margin-bottom: 22px;
    }

    .pv-hero span {
        display: inline-block;
        margin-bottom: 12px;
        padding: 7px 13px;
        border-radius: 999px;
        background: rgba(255, 255, 255, 0.12);
        color: #cfe6ff;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
    }

    .pv-hero h1 {
        font-size: clamp(24px, 3.5vw, 36px);
        line-height: 1.1;
        letter-spacing: -0.03em;
        margin-bottom: 10px;
    }

    .pv-hero p {
        color: rgba(247, 251, 255, 0.80);
        line-height: 1.75;
        max-width: 640px;
        margin-bottom: 16px;
    }

    .pv-hero-actions {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
    }

    .alert {
        border-radius: 18px;
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

    .queue-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
        gap: 18px;
    }

    .request-card {
        background: rgba(255, 255, 255, 0.97);
        border: 1px solid rgba(214, 222, 234, 0.95);
        border-radius: 24px;
        padding: 22px;
        box-shadow: 0 10px 24px rgba(14, 30, 56, 0.06);
        display: flex;
        flex-direction: column;
        gap: 14px;
    }

    .request-card-header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 10px;
    }

    .request-name {
        font-size: 16px;
        font-weight: 800;
        color: #132238;
        margin-bottom: 3px;
    }

    .request-position {
        font-size: 13px;
        color: #5f7187;
    }

    .status-badge {
        display: inline-flex;
        align-items: center;
        padding: 5px 10px;
        border-radius: 999px;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        white-space: nowrap;
        background: #fff7ed;
        border: 1px solid #fdba74;
        color: #c2410c;
    }

    .meta-grid {
        display: grid;
        gap: 6px;
    }

    .meta-row {
        display: flex;
        gap: 8px;
        font-size: 13px;
        color: #5f7187;
        align-items: baseline;
    }

    .meta-row strong {
        font-size: 11px;
        font-weight: 800;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: #8a9ab0;
        min-width: 90px;
        flex-shrink: 0;
    }

    .notes-box {
        padding: 12px 14px;
        border-radius: 14px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
        font-size: 13px;
        color: #4a5568;
        line-height: 1.65;
    }

    .notes-box strong {
        display: block;
        font-size: 11px;
        font-weight: 800;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: #8a9ab0;
        margin-bottom: 6px;
    }

    .card-actions {
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
        padding-top: 4px;
        border-top: 1px solid #e8eef6;
    }

    .reject-form {
        border-top: 1px solid #e8eef6;
        padding-top: 14px;
    }

    .reject-form label {
        display: block;
        font-size: 12px;
        font-weight: 700;
        color: #5f7187;
        margin-bottom: 6px;
    }

    .reject-form textarea {
        width: 100%;
        min-height: 80px;
        padding: 10px 12px;
        border-radius: 12px;
        border: 1px solid #d1dae6;
        font-size: 13px;
        line-height: 1.6;
        resize: vertical;
        margin-bottom: 10px;
        box-sizing: border-box;
    }

    .reject-form textarea:focus {
        outline: none;
        border-color: #3793ff;
        box-shadow: 0 0 0 3px rgba(55, 147, 255, 0.12);
    }

    .empty-state {
        grid-column: 1 / -1;
        padding: 48px 24px;
        text-align: center;
        background: rgba(255, 255, 255, 0.95);
        border: 1px dashed #c9d8e8;
        border-radius: 24px;
        color: #64768c;
    }

    .empty-state h3 {
        font-size: 20px;
        margin-bottom: 8px;
        color: #132238;
    }

    .empty-state p {
        font-size: 14px;
        line-height: 1.7;
    }

    @media (max-width: 640px) {
        .queue-grid {
            grid-template-columns: 1fr;
        }
    }
</style>
@endsection

@section('content')
<div class="pv-wrap">

    @if (session('success'))
        <div class="alert alert-success">{{ session('success') }}</div>
    @endif

    @if ($errors->any())
        <div class="alert alert-error">{{ $errors->first() }}</div>
    @endif

    @if ($loadError)
        <div class="alert alert-error">{{ $loadError }}</div>
    @endif

    <div class="pv-hero">
        <span>Admin — Professor Verification</span>
        <h1>Antrian Verifikasi Profesor</h1>
        <p>
            Tinjau setiap permohonan verifikasi akademik secara manual. Setujui jika bukti afiliasi valid,
            atau tolak dengan catatan agar pemohon tahu apa yang perlu diperbaiki.
        </p>
        <div class="pv-hero-actions">
            <a href="{{ route('dashboard') }}" class="btn btn-secondary">Kembali ke Dashboard</a>
            <a href="{{ route('dashboard.professor-verification.index') }}" class="btn btn-primary">Muat Ulang</a>
        </div>
    </div>

    <div class="queue-grid">
        @forelse ($queue as $request)
            <article class="request-card">

                {{-- Header --}}
                <div class="request-card-header">
                    <div>
                        <div class="request-name">{{ $request['legal_name'] }}</div>
                        <div class="request-position">
                            {{ $request['academic_position'] }}
                            @if ($request['institution'] !== '')
                                &mdash; {{ $request['institution'] }}
                            @endif
                        </div>
                    </div>
                    <span class="status-badge">Pending</span>
                </div>

                {{-- Details --}}
                <div class="meta-grid">
                    <div class="meta-row">
                        <strong>Email</strong>
                        <span>{{ $request['institutional_email'] }}</span>
                    </div>
                    <div class="meta-row">
                        <strong>Department</strong>
                        <span>{{ $request['department'] !== '' ? $request['department'] : '—' }}</span>
                    </div>
                    <div class="meta-row">
                        <strong>Proof type</strong>
                        <span>{{ $request['proof_type'] !== '' ? $request['proof_type'] : '—' }}</span>
                    </div>
                    <div class="meta-row">
                        <strong>Submitted</strong>
                        <span>{{ \Illuminate\Support\Carbon::parse($request['created_at'])->translatedFormat('d M Y H:i') }}</span>
                    </div>
                </div>

                {{-- Optional notes from applicant --}}
                @if (trim($request['notes']) !== '')
                    <div class="notes-box">
                        <strong>Applicant notes</strong>
                        {{ $request['notes'] }}
                    </div>
                @endif

                {{-- Primary actions --}}
                <div class="card-actions">
                    {{-- View proof file (opens signed URL) --}}
                    <a href="{{ route('dashboard.professor-verification.proof', $request['id']) }}"
                       target="_blank"
                       class="btn btn-secondary">
                        View Proof
                    </a>

                    {{-- Approve --}}
                    <form action="{{ route('dashboard.professor-verification.approve', $request['id']) }}" method="POST" style="margin:0;">
                        @csrf
                        <button type="submit" class="btn btn-primary"
                                onclick="return confirm('Approve this professor verification request?')">
                            Approve
                        </button>
                    </form>
                </div>

                {{-- Reject with reason --}}
                <div class="reject-form">
                    <form action="{{ route('dashboard.professor-verification.reject', $request['id']) }}" method="POST">
                        @csrf
                        <label for="notes_{{ $request['id'] }}">Reject — Feedback for applicant</label>
                        <textarea
                            id="notes_{{ $request['id'] }}"
                            name="admin_notes"
                            placeholder="Jelaskan apa yang perlu diperbaiki atau dilengkapi oleh pemohon..."
                            required
                        >{{ old('admin_notes') }}</textarea>
                        <button type="submit" class="btn btn-danger">Reject</button>
                    </form>
                </div>

            </article>
        @empty
            <div class="empty-state">
                <h3>Tidak ada permohonan yang menunggu.</h3>
                <p>Begitu ada pengguna yang mengajukan verifikasi profesor, kartunya akan muncul di sini.</p>
            </div>
        @endforelse
    </div>

</div>
@endsection
