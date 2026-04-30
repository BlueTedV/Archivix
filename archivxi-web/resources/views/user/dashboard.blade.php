@extends('layouts.site')
@section('title', 'User Dashboard')

@section('styles')
<style>
    .dashboard-wrap {
        max-width: 1180px;
        margin: 0 auto;
        padding: 34px 20px 56px;
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

    .hero-grid {
        display: grid;
        grid-template-columns: 1.15fr 0.85fr;
        gap: 18px;
        margin-bottom: 20px;
    }

    .hero-card,
    .panel,
    .stat-card,
    .feed-card {
        border-radius: 28px;
        border: 1px solid rgba(214, 222, 234, 0.95);
        box-shadow: 0 18px 36px rgba(14, 30, 56, 0.08);
    }

    .hero-card {
        padding: 30px;
        background:
            radial-gradient(circle at top right, rgba(124, 194, 255, 0.24), transparent 28%),
            linear-gradient(135deg, #132238 0%, #1a3250 58%, #21476f 100%);
        color: #f7fbff;
    }

    .hero-badge {
        display: inline-flex;
        align-items: center;
        gap: 8px;
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
        color: rgba(247, 251, 255, 0.82);
        line-height: 1.75;
        margin-bottom: 18px;
    }

    .hero-actions,
    .panel-actions {
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
    }

    .panel {
        padding: 26px;
        background: rgba(255, 255, 255, 0.95);
    }

    .panel h2,
    .feed-card h2 {
        font-size: 20px;
        margin-bottom: 8px;
        color: #132238;
    }

    .panel-intro,
    .feed-card > p {
        color: #64768c;
        line-height: 1.7;
        margin-bottom: 16px;
        font-size: 13px;
    }

    .mini-list,
    .feedback-list,
    .alert-list,
    .account-list {
        display: grid;
        gap: 12px;
    }

    .mini-item,
    .feedback-item,
    .alert-item,
    .account-item {
        padding: 14px 16px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .mini-item strong,
    .feedback-item strong,
    .alert-item strong,
    .account-item strong {
        display: block;
        margin-bottom: 5px;
        font-size: 13px;
        color: #132238;
    }

    .mini-item span,
    .feedback-item span,
    .alert-item span,
    .account-item span {
        color: #697b91;
        font-size: 13px;
        line-height: 1.65;
        display: block;
    }

    .stats-grid {
        display: grid;
        grid-template-columns: repeat(6, minmax(0, 1fr));
        gap: 14px;
        margin-bottom: 20px;
    }

    .stat-card {
        padding: 20px;
        background: rgba(255, 255, 255, 0.94);
    }

    .stat-card span {
        display: block;
        margin-bottom: 8px;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: #6a7b90;
    }

    .stat-card strong {
        display: block;
        font-size: 26px;
        margin-bottom: 6px;
        color: #122031;
    }

    .stat-card p {
        color: #67788e;
        font-size: 12px;
        line-height: 1.65;
    }

    .highlight-band {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 18px;
        margin-bottom: 20px;
    }

    .feedback-item {
        background: #fff7ed;
        border-color: #fdba74;
    }

    .feedback-item p,
    .alert-item p,
    .activity-excerpt {
        margin: 0;
        color: #5f7187;
        font-size: 13px;
        line-height: 1.7;
    }

    .alert-item.success {
        background: #ecfdf5;
        border-color: #a7f3d0;
    }

    .alert-item.warning {
        background: #fff7ed;
        border-color: #fdba74;
    }

    .alert-item.info {
        background: #eff6ff;
        border-color: #bfdbfe;
    }

    .alert-item.danger {
        background: #fef2f2;
        border-color: #fecaca;
    }

    .content-grid {
        display: grid;
        grid-template-columns: 1.25fr 0.75fr;
        gap: 18px;
    }

    .feed-card {
        padding: 24px;
        background: rgba(255, 255, 255, 0.95);
    }

    .activity-list {
        display: grid;
        gap: 12px;
    }

    .activity-item {
        padding: 16px 18px;
        border-radius: 20px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .activity-head {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
        margin-bottom: 8px;
    }

    .activity-title {
        font-size: 15px;
        font-weight: 800;
        color: #132238;
    }

    .meta-row {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        margin-top: 10px;
    }

    .pill {
        display: inline-flex;
        align-items: center;
        padding: 6px 10px;
        border-radius: 999px;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.06em;
        text-transform: uppercase;
    }

    .pill.type-paper {
        background: #eef6ff;
        border: 1px solid #cde1f6;
        color: #1c5ea8;
    }

    .pill.type-post {
        background: #fff6e7;
        border: 1px solid #f4d7a4;
        color: #b26f07;
    }

    .pill.status-draft {
        background: #eef4ff;
        border: 1px solid #bfdbfe;
        color: #1d4ed8;
    }

    .pill.status-submitted {
        background: #fff7ed;
        border: 1px solid #fdba74;
        color: #c2410c;
    }

    .pill.status-under_review {
        background: #eff6ff;
        border: 1px solid #bfdbfe;
        color: #1d4ed8;
    }

    .pill.status-published,
    .pill.status-live {
        background: #ecfdf5;
        border: 1px solid #a7f3d0;
        color: #047857;
    }

    .pill.status-rejected {
        background: #fef2f2;
        border: 1px solid #fecaca;
        color: #b91c1c;
    }

    .subtle {
        color: #7b8a9f;
        font-size: 12px;
        line-height: 1.6;
    }

    .empty-state {
        padding: 24px 18px;
        border-radius: 20px;
        background: #f8fbff;
        border: 1px dashed #c9d8e8;
        color: #64768c;
        text-align: center;
    }

    @media (max-width: 1100px) {
        .stats-grid {
            grid-template-columns: repeat(3, minmax(0, 1fr));
        }
    }

    @media (max-width: 980px) {
        .hero-grid,
        .highlight-band,
        .content-grid {
            grid-template-columns: 1fr;
        }
    }

    @media (max-width: 720px) {
        .dashboard-wrap {
            padding: 24px 16px 44px;
        }

        .stats-grid {
            grid-template-columns: repeat(2, minmax(0, 1fr));
        }

        .activity-head {
            flex-direction: column;
            align-items: flex-start;
        }
    }
</style>
@endsection

@section('content')
@php
    $stats = $dashboard['stats'];
    $recentItems = $dashboard['recent_items'];
    $alerts = $dashboard['alerts'];
    $latestFeedback = $dashboard['latest_feedback'];

    $formatDate = function (?string $value): string {
        if (! $value) {
            return 'Not available';
        }

        return \Illuminate\Support\Carbon::parse($value)->translatedFormat('d M Y H:i');
    };

    $relativeDate = function (?string $value): string {
        if (! $value) {
            return 'No timestamp';
        }

        return \Illuminate\Support\Carbon::parse($value)->diffForHumans();
    };

    $nextAction = match (true) {
        $stats['rejected_papers'] > 0 => 'You have documents that need revision. Check the latest feedback section first.',
        $stats['under_review_papers'] > 0 => 'Some of your documents are currently under review. Watch the alerts section for updates.',
        $stats['draft_papers'] > 0 => 'You still have drafts waiting to be finished before submission.',
        $stats['papers'] === 0 && $stats['posts'] === 0 => 'Start by creating your first document or question from the mobile app.',
        default => 'Your account is in good shape. Keep an eye on recent activity and status changes.',
    };
@endphp

<div class="dashboard-wrap">
    @if (session('success'))
        <div class="alert alert-success">{{ session('success') }}</div>
    @endif

    @if ($loadError)
        <div class="alert alert-error">{{ $loadError }}</div>
    @endif

    <section class="hero-grid">
        <div class="hero-card">
            <div class="hero-badge">Archivix Workspace</div>
            <h1>Welcome back, {{ $user->name }}.</h1>
            <p>
                This dashboard gives you a quick view of your documents, questions, review progress, and the latest feedback from the Archivix workflow.
            </p>

            <div class="hero-actions">
                <a href="/download" class="btn btn-primary">Continue in Mobile App</a>
                <a href="/" class="btn btn-secondary">Back to Home</a>
            </div>
        </div>

        <div class="panel">
            <h2>Next Best Action</h2>
            <p class="panel-intro">{{ $nextAction }}</p>

            <div class="mini-list">
                <div class="mini-item">
                    <strong>Documents in review flow</strong>
                    <span>{{ $stats['submitted_papers'] + $stats['under_review_papers'] }} item(s) are in the queue right now.</span>
                </div>
                <div class="mini-item">
                    <strong>Visible reach</strong>
                    <span>Your questions and documents have collected {{ $stats['total_views'] }} total view(s).</span>
                </div>
                <div class="mini-item">
                    <strong>Account source</strong>
                    <span>This web dashboard uses the same Supabase account as your mobile app.</span>
                </div>
            </div>
        </div>
    </section>

    <section class="stats-grid">
        <article class="stat-card">
            <span>Documents</span>
            <strong>{{ $stats['papers'] }}</strong>
            <p>Total papers and documents linked to your account.</p>
        </article>

        <article class="stat-card">
            <span>Questions</span>
            <strong>{{ $stats['posts'] }}</strong>
            <p>Questions or posts you have already published.</p>
        </article>

        <article class="stat-card">
            <span>Drafts</span>
            <strong>{{ $stats['draft_papers'] }}</strong>
            <p>Documents that still need work before submission.</p>
        </article>

        <article class="stat-card">
            <span>In Review</span>
            <strong>{{ $stats['submitted_papers'] + $stats['under_review_papers'] }}</strong>
            <p>Items waiting in the admin review workflow.</p>
        </article>

        <article class="stat-card">
            <span>Published</span>
            <strong>{{ $stats['published_papers'] }}</strong>
            <p>Documents already approved and published.</p>
        </article>

        <article class="stat-card">
            <span>Need Revision</span>
            <strong>{{ $stats['rejected_papers'] }}</strong>
            <p>Documents rejected with feedback to review.</p>
        </article>
    </section>

    <section class="highlight-band">
        <div class="panel">
            <h2>Latest Feedback</h2>
            <p class="panel-intro">If a document was rejected, the latest reviewer notes appear here so you know what to fix next.</p>

            @if (count($latestFeedback) === 0)
                <div class="empty-state">
                    No rejection feedback yet. When an admin leaves revision notes, they will appear here.
                </div>
            @else
                <div class="feedback-list">
                    @foreach ($latestFeedback as $paper)
                        <div class="feedback-item">
                            <strong>{{ $paper['title'] }}</strong>
                            <span class="subtle">Reviewed {{ $relativeDate($paper['reviewed_at'] ?? $paper['created_at']) }}</span>
                            <p>{{ $paper['rejection_reason'] }}</p>
                        </div>
                    @endforeach
                </div>
            @endif
        </div>

        <div class="panel">
            <h2>Status Alerts</h2>
            <p class="panel-intro">Important updates from your submission lifecycle are grouped here for quick scanning.</p>

            @if (count($alerts) === 0)
                <div class="empty-state">
                    No active alerts right now. Your next updates will appear here once your content moves through review.
                </div>
            @else
                <div class="alert-list">
                    @foreach ($alerts as $alert)
                        <div class="alert-item {{ $alert['tone'] }}">
                            <strong>{{ $alert['title'] }}</strong>
                            <span class="subtle">{{ $relativeDate($alert['timestamp']) }}</span>
                            <p>{{ $alert['message'] }}</p>
                        </div>
                    @endforeach
                </div>
            @endif
        </div>
    </section>

    <section class="content-grid">
        <div class="feed-card">
            <h2>Recent Activity</h2>
            <p>Your most recent documents and questions, sorted by creation date.</p>

            @if (count($recentItems) === 0)
                <div class="empty-state">
                    You have not created any content yet. Start in the mobile app and your activity will appear here.
                </div>
            @else
                <div class="activity-list">
                    @foreach ($recentItems as $item)
                        <article class="activity-item">
                            <div class="activity-head">
                                <div>
                                    <div class="activity-title">{{ $item['title'] }}</div>
                                    <div class="subtle">Created {{ $relativeDate($item['created_at']) }}</div>
                                </div>

                                <div class="meta-row">
                                    <span class="pill type-{{ $item['type'] }}">{{ $item['type_label'] }}</span>
                                    <span class="pill status-{{ str_replace('-', '_', $item['status']) }}">{{ str_replace('_', ' ', ucfirst($item['status'])) }}</span>
                                </div>
                            </div>

                            <p class="activity-excerpt">
                                {{ $item['excerpt'] !== '' ? $item['excerpt'] : 'No summary available yet.' }}
                            </p>

                            <div class="meta-row">
                                <span class="subtle">Category: {{ $item['category_name'] }}</span>
                                <span class="subtle">Views: {{ $item['views_count'] }}</span>
                                @if (($item['type'] ?? '') === 'paper' && ($item['submitted_at'] ?? null))
                                    <span class="subtle">Submitted: {{ $formatDate($item['submitted_at']) }}</span>
                                @endif
                                @if (($item['type'] ?? '') === 'paper' && ($item['published_at'] ?? null))
                                    <span class="subtle">Published: {{ $formatDate($item['published_at']) }}</span>
                                @endif
                            </div>
                        </article>
                    @endforeach
                </div>
            @endif
        </div>

        <div class="feed-card">
            <h2>Account Snapshot</h2>
            <p>Core identity and session information for your current web account.</p>

            <div class="account-list">
                <div class="account-item">
                    <strong>Name</strong>
                    <span>{{ $user->name }}</span>
                </div>

                <div class="account-item">
                    <strong>Email</strong>
                    <span>{{ $user->email }}</span>
                </div>

                <div class="account-item">
                    <strong>Verification Status</strong>
                    <span>{{ $user->email_verified_at ? 'Verified in Supabase' : 'Not verified yet' }}</span>
                </div>

                <div class="account-item">
                    <strong>Joined</strong>
                    <span>{{ optional($user->created_at)?->translatedFormat('d M Y H:i') ?? 'Not available' }}</span>
                </div>

                <div class="account-item">
                    <strong>Last Sign In</strong>
                    <span>{{ optional($user->last_sign_in_at)?->translatedFormat('d M Y H:i') ?? 'Not available' }}</span>
                </div>
            </div>

            <div class="panel-actions" style="margin-top: 18px;">
                <a href="/download" class="btn btn-secondary">Open Mobile Flow</a>
                <form action="{{ route('logout') }}" method="POST" style="margin: 0;">
                    @csrf
                    <button type="submit" class="btn btn-primary">Logout</button>
                </form>
            </div>
        </div>
    </section>
</div>
@endsection
