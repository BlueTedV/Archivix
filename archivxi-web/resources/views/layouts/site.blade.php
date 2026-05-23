<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Archivix - @yield('title', 'Platform Dokumen')</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        :root {
            --navy-950: #0d1b2a;
            --navy-900: #132238;
            --navy-800: #1c3553;
            --sky-500: #3793ff;
            --slate-900: #16202d;
            --slate-700: #4d6077;
            --slate-500: #7b8a9f;
            --slate-200: #d6deea;
            --white: #ffffff;
        }

        body {
            font-family: 'Manrope', sans-serif;
            background:
                radial-gradient(circle at top left, rgba(55, 147, 255, 0.10), transparent 34%),
                linear-gradient(180deg, #f7fbff 0%, #eef4fb 100%);
            color: var(--slate-900);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .navbar {
            position: sticky;
            top: 0;
            z-index: 100;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 16px 24px;
            background: rgba(13, 27, 42, 0.92);
            backdrop-filter: blur(14px);
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        }

        .navbar-brand {
            display: flex;
            align-items: center;
            gap: 12px;
            text-decoration: none;
        }

        .brand-icon {
            width: 36px;
            height: 36px;
            border-radius: 12px;
            display: grid;
            place-items: center;
            background: linear-gradient(135deg, #3793ff 0%, #7cc2ff 100%);
            color: var(--white);
            font-weight: 800;
            font-size: 14px;
            box-shadow: 0 10px 24px rgba(55, 147, 255, 0.28);
        }

        .brand-name {
            color: var(--white);
            font-size: 18px;
            font-weight: 800;
            letter-spacing: 0.02em;
        }

        .navbar-right {
            display: flex;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
        }

        .nav-link {
            color: rgba(255, 255, 255, 0.72);
            text-decoration: none;
            font-size: 13px;
            font-weight: 700;
            padding: 8px 12px;
            border-radius: 999px;
            transition: 0.2s ease;
        }

        .nav-link:hover {
            color: var(--white);
            background: rgba(255, 255, 255, 0.08);
        }

        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            padding: 10px 18px;
            border: none;
            border-radius: 999px;
            font-family: inherit;
            font-size: 14px;
            font-weight: 800;
            cursor: pointer;
            text-decoration: none;
            transition: transform 0.15s ease, box-shadow 0.15s ease, background 0.15s ease;
        }

        .btn:hover {
            transform: translateY(-1px);
        }

        .btn-primary {
            background: linear-gradient(135deg, #3793ff 0%, #1d72da 100%);
            color: var(--white);
            box-shadow: 0 12px 24px rgba(29, 114, 218, 0.24);
        }

        .btn-secondary {
            background: var(--white);
            color: var(--slate-900);
            border: 1px solid var(--slate-200);
        }

        .btn-danger {
            background: #dc2626;
            color: var(--white);
        }

        .btn-full {
            width: 100%;
        }

        .card {
            background: rgba(255, 255, 255, 0.94);
            border: 1px solid rgba(214, 222, 234, 0.95);
            border-radius: 24px;
            padding: 28px;
            box-shadow: 0 18px 40px rgba(14, 30, 56, 0.08);
        }

        .form-label {
            display: block;
            margin-bottom: 8px;
            font-size: 13px;
            font-weight: 800;
            color: var(--slate-700);
        }

        .form-input {
            width: 100%;
            padding: 12px 14px;
            margin-bottom: 16px;
            border: 1px solid var(--slate-200);
            border-radius: 14px;
            font-family: inherit;
            font-size: 14px;
            background: #f9fbfe;
            color: var(--slate-900);
            transition: border-color 0.15s ease, box-shadow 0.15s ease, background 0.15s ease;
        }

        .form-input:focus {
            outline: none;
            border-color: var(--sky-500);
            box-shadow: 0 0 0 4px rgba(55, 147, 255, 0.12);
            background: var(--white);
        }

        textarea.form-input { resize: vertical; }

        .main-content {
            flex: 1;
        }

        .footer {
            margin-top: 48px;
            padding: 24px;
            text-align: center;
            color: var(--slate-500);
            font-size: 12.5px;
        }

        .footer span {
            color: var(--navy-800);
            font-weight: 800;
        }

        @media (max-width: 720px) {
            .navbar {
                padding: 14px 16px;
                align-items: flex-start;
                flex-direction: column;
                gap: 12px;
            }

            .navbar-right {
                width: 100%;
            }
        }
    </style>
    @yield('styles')
    <style>
        :root {
            --classic-bg: #e8e8e8;
            --classic-panel: #f7f7f4;
            --classic-white: #ffffff;
            --classic-border: #b5bbc6;
            --classic-border-dark: #7e8794;
            --classic-slate: #4a5568;
            --classic-slate-light: #73829b;
            --classic-slate-dark: #3f4857;
            --classic-text: #1f2937;
            --classic-muted: #6b7280;
            --classic-faint: #f3f4f6;
            --classic-amber-bg: #fff9e6;
            --classic-amber-border: #fcd34d;
            --classic-amber-text: #92400e;
        }

        body {
            font-family: Tahoma, Verdana, Arial, sans-serif;
            background: var(--classic-bg);
            color: var(--classic-text);
        }

        .navbar {
            position: sticky;
            padding: 0 24px;
            min-height: 54px;
            background: linear-gradient(180deg, var(--classic-slate-light) 0%, var(--classic-slate) 48%, var(--classic-slate-dark) 100%);
            border-bottom: 1px solid #2f3743;
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.28);
            backdrop-filter: none;
        }

        .brand-icon {
            width: 30px;
            height: 30px;
            border-radius: 4px;
            background: linear-gradient(180deg, #7f8da3 0%, var(--classic-slate) 100%);
            border: 1px solid #303844;
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.30);
            font-size: 12px;
        }

        .brand-name {
            font-size: 17px;
            letter-spacing: 0;
        }

        .nav-link,
        .btn,
        .nav-btn,
        button.btn,
        a.btn {
            border-radius: 4px;
            box-shadow: none;
            transform: none;
            transition: background 0.12s, border-color 0.12s;
        }

        .nav-link {
            color: #edf2f7;
            border: 1px solid transparent;
            padding: 7px 10px;
        }

        .nav-link:hover {
            color: #ffffff;
            background: rgba(255, 255, 255, 0.12);
            border-color: rgba(255, 255, 255, 0.20);
        }

        .btn:hover {
            transform: none;
        }

        .btn-primary {
            background: linear-gradient(180deg, var(--classic-slate-light) 0%, var(--classic-slate) 100%);
            color: #ffffff;
            border: 1px solid var(--classic-slate-dark);
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.30);
        }

        .btn-primary:hover {
            background: linear-gradient(180deg, #8491a6 0%, #546176 100%);
        }

        .btn-secondary {
            background: linear-gradient(180deg, #ffffff 0%, #ecece7 100%);
            color: var(--classic-text);
            border: 1px solid var(--classic-border);
        }

        .btn-danger {
            background: linear-gradient(180deg, #ef4444 0%, #991b1b 100%);
            border: 1px solid #7f1d1d;
            color: #ffffff;
        }

        .card,
        .hero-copy,
        .hero-card,
        .detail-hero,
        .profile-card,
        .panel,
        .feed-card,
        .detail-card,
        .manager-header .summary-card,
        .content-card,
        .feature-card,
        .cta-band,
        .download-strip,
        .app-preview-card,
        .dl-card,
        .auth-box .card {
            border-radius: 4px;
            border: 1px solid var(--classic-border);
            box-shadow: none;
            background: var(--classic-panel);
        }

        .hero-copy,
        .hero-card,
        .detail-hero,
        .manager-header .hero-card,
        .download-strip {
            background: linear-gradient(180deg, var(--classic-slate-light) 0%, var(--classic-slate) 42%, var(--classic-slate-dark) 100%);
            border: 1px solid var(--classic-slate-dark);
            box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.24);
            color: #ffffff;
        }

        .hero-copy h1,
        .hero-card h1,
        .detail-hero h1 {
            letter-spacing: 0;
        }

        .eyebrow,
        .hero-card span,
        .hero-badge,
        .app-preview-copy span,
        .download-strip span,
        .section-head span {
            border-radius: 3px;
            background: #e1e6ee;
            border: 1px solid #aeb7c4;
            color: var(--classic-slate-dark);
            letter-spacing: 0.04em;
        }

        .hero-copy .eyebrow,
        .hero-card span,
        .detail-hero .type-badge,
        .detail-hero .status-badge {
            background: rgba(255, 255, 255, 0.16);
            border-color: rgba(255, 255, 255, 0.24);
            color: #ffffff;
        }

        .hero-metric,
        .profile-item,
        .mini-item,
        .feedback-item,
        .alert-item,
        .account-item,
        .activity-item,
        .recent-item,
        .meta-item,
        .asset-item,
        .comment-card,
        .summary-item,
        .review-card,
        .empty-state,
        .phone-preview,
        .preview-placeholder,
        .auth-switch,
        .filter-pill,
        .engagement-btn {
            border-radius: 4px;
            background: #ffffff;
            border: 1px solid #c4cad3;
            box-shadow: none;
        }

        .phone-preview img {
            filter: none;
        }

        .type-badge,
        .status-badge,
        .pill,
        .filter-pill,
        .engagement-btn,
        .chip {
            border-radius: 3px;
        }

        .type-badge.post,
        .pill.type-post,
        .feature-icon {
            background: var(--classic-amber-bg);
            border: 1px solid var(--classic-amber-border);
            color: var(--classic-amber-text);
        }

        .type-badge.paper,
        .pill.type-paper {
            background: #e9eff7;
            border: 1px solid #b9c6d8;
            color: var(--classic-slate-dark);
        }

        .form-input,
        textarea,
        .comment-form textarea {
            border-radius: 4px;
            background: #ffffff;
            border: 1px solid #9ca3af;
            box-shadow: inset 1px 1px 2px rgba(0, 0, 0, 0.08);
        }

        .form-input:focus,
        textarea:focus,
        .comment-form textarea:focus {
            border-color: var(--classic-slate);
            box-shadow: inset 1px 1px 2px rgba(0, 0, 0, 0.08), 0 0 0 1px var(--classic-slate);
        }

        .footer {
            margin-top: 34px;
            padding: 16px 24px;
            background: #d7dce4;
            border-top: 1px solid var(--classic-border);
            color: var(--classic-muted);
        }

        .landing-wrap {
            max-width: 1220px;
            padding-top: 22px;
        }

        .landing-wrap .hero {
            grid-template-columns: minmax(0, 1.05fr) minmax(340px, 0.78fr);
            gap: 18px;
            margin-bottom: 18px;
        }

        .landing-wrap .hero-copy {
            padding: 26px 32px;
        }

        .landing-wrap .eyebrow {
            padding: 7px 10px;
            margin-bottom: 14px;
        }

        .landing-wrap .hero-copy h1 {
            font-size: clamp(30px, 3.3vw, 46px);
            line-height: 1.08;
            margin-bottom: 14px;
        }

        .landing-wrap .hero-copy p {
            font-size: 14px;
            line-height: 1.6;
            margin-bottom: 18px;
        }

        .landing-wrap .hero-actions {
            gap: 10px;
            margin-bottom: 16px;
        }

        .landing-wrap .hero-metrics {
            gap: 8px;
        }

        .landing-wrap .hero-copy .hero-metric {
            padding: 11px 12px;
            background: rgba(255, 255, 255, 0.12);
            border-color: rgba(255, 255, 255, 0.22);
        }

        .landing-wrap .hero-copy .hero-metric strong {
            color: #ffffff;
            font-size: 18px;
        }

        .landing-wrap .hero-copy .hero-metric span {
            color: #edf2f7;
            font-size: 11px;
        }

        .landing-wrap .app-preview-card {
            min-height: 0;
            padding: 22px;
            justify-content: flex-start;
        }

        .landing-wrap .app-preview-copy h2 {
            font-size: 24px;
            line-height: 1.18;
        }

        .landing-wrap .app-preview-copy p {
            font-size: 14px;
            line-height: 1.55;
        }

        .landing-wrap .phone-preview {
            min-height: 260px;
            padding: 14px;
        }

        .landing-wrap .phone-preview img {
            width: min(100%, 210px);
            max-height: 300px;
        }

        .landing-wrap .preview-placeholder {
            width: min(100%, 210px);
            color: var(--classic-muted);
            background: #f7f7f4;
        }

        .landing-wrap .preview-placeholder strong {
            color: var(--classic-text);
        }

        @media (max-width: 720px) {
            .navbar {
                padding: 10px 14px;
            }
        }

        @media (max-width: 980px) {
            .landing-wrap .hero {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
<nav class="navbar">
    <a href="/" class="navbar-brand">
        <div class="brand-icon">AX</div>
        <span class="brand-name">Archivix</span>
    </a>

    <div class="navbar-right">
        <a href="/" class="nav-link">Home</a>
        <a href="{{ route('browse.index') }}" class="nav-link">Browse</a>
        <a href="/download" class="nav-link">Download</a>

        @if (session()->has('admin_user'))
            <a href="{{ route('dashboard') }}" class="nav-link">Dashboard</a>
            <a href="{{ route('dashboard.posts.index') }}" class="nav-link">Content</a>
            <form action="{{ route('logout') }}" method="POST" style="margin: 0;">
                @csrf
                <button type="submit" class="btn btn-danger">Logout</button>
            </form>
        @elseif (session()->has('web_user'))
            <a href="{{ route('user.dashboard') }}" class="nav-link">My Dashboard</a>
            <a href="{{ route('user.profile.edit') }}" class="nav-link">Profile</a>
            <form action="{{ route('logout') }}" method="POST" style="margin: 0;">
                @csrf
                <button type="submit" class="btn btn-primary">Logout</button>
            </form>
        @else
            <a href="{{ route('login') }}" class="nav-link">Masuk / Daftar</a>
        @endif
    </div>
</nav>

<main class="main-content">
    @yield('content')
</main>

<footer class="footer">
    Copyright 2025 <span>Archivix</span> - Platform Dokumen Pembelajaran
</footer>
</body>
</html>
