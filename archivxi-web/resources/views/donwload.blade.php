@extends('layouts.site')
@section('title', 'Download Aplikasi')

@section('styles')
<style>
    .dl-wrap {
        max-width: 640px;
        margin: 0 auto;
        padding: 48px 20px;
    }

    .dl-header {
        text-align: center;
        margin-bottom: 40px;
    }

    .dl-header h2 { font-size: 24px; font-weight: 700; margin-bottom: 8px; }
    .dl-header p { font-size: 14px; color: #6b7280; }

    .dl-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 16px;
        margin-bottom: 32px;
    }

    .dl-card {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 12px;
        padding: 28px 20px;
        text-align: center;
        transition: border-color 0.15s, box-shadow 0.15s;
        cursor: pointer;
    }

    .dl-card:hover {
        border-color: #3b5bdb;
        box-shadow: 0 4px 20px rgba(59,91,219,0.1);
    }

    .dl-icon { font-size: 40px; margin-bottom: 14px; display: block; }
    .dl-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 4px; }
    .dl-card .platform { font-size: 12px; color: #9ca3af; margin-bottom: 16px; }

    .dl-btn {
        display: inline-block;
        background: #1e2a45;
        color: white;
        padding: 8px 20px;
        border-radius: 7px;
        font-size: 13px;
        font-weight: 600;
        text-decoration: none;
        transition: background 0.15s;
    }

    .dl-btn:hover { background: #3b5bdb; }

    .dl-note {
        text-align: center;
        font-size: 12px;
        color: #9ca3af;
        padding-top: 24px;
        border-top: 1px solid #f3f4f6;
    }
</style>
@endsection

@section('content')
<div class="dl-wrap">

    <div class="dl-header">
        <h2>Download ArchivXI</h2>
        <p>Tersedia untuk Android dan Windows. Gratis dan selalu diperbarui.</p>
    </div>

    <div class="dl-grid">
        <div class="dl-card">
            <span class="dl-icon">🤖</span>
            <h3>Android</h3>
            <p class="platform">APK · Android 8.0+</p>
            <a href="#" class="dl-btn">Download APK</a>
        </div>

        <div class="dl-card">
            <span class="dl-icon">🪟</span>
            <h3>Windows</h3>
            <p class="platform">EXE · Windows 10+</p>
            <a href="#" class="dl-btn">Download EXE</a>
        </div>
    </div>

    <div class="dl-note">
        Versi 1.0.0 — Dirilis April 2025 &nbsp;·&nbsp; Butuh bantuan? Hubungi tim kami
    </div>

</div>
@endsection
