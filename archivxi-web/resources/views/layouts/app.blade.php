<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Archivix — @yield('title', 'Platform Dokumen')</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Inter', sans-serif;
            background: #f6f7f9;
            color: #111827;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        /* ── NAVBAR ── */
        .navbar {
            background: #1e2a45;
            padding: 0 32px;
            height: 58px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            position: sticky;
            top: 0;
            z-index: 100;
        }

        .navbar-brand {
            display: flex;
            align-items: center;
            gap: 10px;
            text-decoration: none;
        }

        .brand-icon {
            width: 30px;
            height: 30px;
            background: #3b5bdb;
            border-radius: 7px;
            display: grid;
            place-items: center;
            color: white;
            font-weight: 800;
            font-size: 13px;
            letter-spacing: -0.5px;
        }

        .brand-name {
            color: #f1f5f9;
            font-size: 17px;
            font-weight: 700;
            letter-spacing: 0.3px;
        }

        .navbar-right {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .nav-link {
            color: #94a3b8;
            text-decoration: none;
            font-size: 13.5px;
            font-weight: 500;
            padding: 6px 12px;
            border-radius: 6px;
            transition: color 0.15s, background 0.15s;
        }

        .nav-link:hover { color: #f1f5f9; background: rgba(255,255,255,0.07); }

        .nav-btn {
            background: #3b5bdb;
            color: white;
            text-decoration: none;
            font-size: 13px;
            font-weight: 600;
            padding: 7px 16px;
            border-radius: 7px;
            transition: background 0.15s;
        }

        .nav-btn:hover { background: #3451c7; }

        /* ── LAYOUT ── */
        .page-wrapper {
            flex: 1;
            width: 100%;
            max-width: 860px;
            margin: 0 auto;
            padding: 32px 20px;
        }

        .page-wrapper.wide { max-width: 1100px; }
        .page-wrapper.narrow { max-width: 480px; }

        /* ── CARD ── */
        .card {
            background: white;
            border: 1px solid #e5e7eb;
            border-radius: 10px;
            padding: 28px;
        }

        /* ── FORM ── */
        .form-label {
            display: block;
            font-size: 13px;
            font-weight: 600;
            color: #374151;
            margin-bottom: 6px;
        }

        .form-input {
            width: 100%;
            padding: 9px 13px;
            border: 1px solid #d1d5db;
            border-radius: 7px;
            font-size: 14px;
            font-family: inherit;
            color: #111827;
            background: #fafafa;
            transition: border-color 0.15s, box-shadow 0.15s;
            margin-bottom: 16px;
        }

        .form-input:focus {
            outline: none;
            border-color: #3b5bdb;
            box-shadow: 0 0 0 3px rgba(59,91,219,0.1);
            background: white;
        }

        textarea.form-input { resize: vertical; }

        /* ── BUTTONS ── */
        .btn {
            display: inline-flex;
            align-items: center;
            gap: 7px;
            padding: 9px 20px;
            font-size: 14px;
            font-weight: 600;
            border-radius: 7px;
            border: none;
            cursor: pointer;
            text-decoration: none;
            transition: background 0.15s, transform 0.1s;
            font-family: inherit;
        }

        .btn:active { transform: scale(0.98); }

        .btn-primary { background: #3b5bdb; color: white; }
        .btn-primary:hover { background: #3451c7; }

        .btn-secondary { background: #f3f4f6; color: #374151; border: 1px solid #e5e7eb; }
        .btn-secondary:hover { background: #e9eaec; }

        .btn-full { width: 100%; justify-content: center; padding: 10px; font-size: 14.5px; }

        /* ── FOOTER ── */
        .footer {
            background: #1e2a45;
            color: #64748b;
            text-align: center;
            padding: 18px;
            font-size: 12.5px;
        }

        .footer span { color: #94a3b8; }
    </style>
    @yield('styles')
</head>
<body>

<nav class="navbar">
    <a href="/" class="navbar-brand">
        <div class="brand-icon">AX</div>
        <span class="brand-name">Archivix</span>
    </a>
    <<div class="navbar-right">
    <a href="/download" class="nav-link">Download</a>

    @if(session('is_admin'))
        <a href="/admin" class="nav-link">Admin</a>
        <a href="/logout" class="nav-btn" style="background:#dc2626;">Logout</a>
    @else
        <a href="/login" class="nav-btn">Masuk</a>
    @endif
</div>
</nav>

<div class="main-content" style="flex:1;">
    @yield('content')
</div>

<footer class="footer">
   © 2025 <span>Archivix</span> — Platform Dokumen Pembelajaran
</footer>

</body>
</html>
