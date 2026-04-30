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
</head>
<body>
<nav class="navbar">
    <a href="/" class="navbar-brand">
        <div class="brand-icon">AX</div>
        <span class="brand-name">Archivix</span>
    </a>

    <div class="navbar-right">
        <a href="/" class="nav-link">Home</a>
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
            <form action="{{ route('logout') }}" method="POST" style="margin: 0;">
                @csrf
                <button type="submit" class="btn btn-primary">Logout</button>
            </form>
        @else
            <a href="{{ route('login') }}" class="nav-link">Login</a>
            <a href="{{ route('register') }}" class="nav-link">Register</a>
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
