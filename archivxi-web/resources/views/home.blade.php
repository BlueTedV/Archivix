@extends('layouts.app')
@section('title', 'Beranda')

@section('styles')
<style>
    .home-wrap {
        max-width: 860px;
        margin: 0 auto;
        padding: 28px 20px;
    }

    .hero {
        background: #1e2a45;
        border-radius: 12px;
        padding: 32px 28px;
        margin-bottom: 28px;
        position: relative;
        overflow: hidden;
    }

    .hero::before {
        content: '';
        position: absolute;
        top: -30px; right: -30px;
        width: 160px; height: 160px;
        background: rgba(59,91,219,0.25);
        border-radius: 50%;
    }

    .hero-label {
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 1px;
        text-transform: uppercase;
        color: #7c9fd4;
        margin-bottom: 8px;
    }

    .hero h2 {
        font-size: 22px;
        font-weight: 700;
        color: #f1f5f9;
        margin-bottom: 5px;
    }

    .hero p {
        font-size: 13.5px;
        color: #94a3b8;
        line-height: 1.5;
    }

    .bar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 20px;
        flex-wrap: wrap;
        gap: 12px;
    }

    .bar-title {
        font-size: 15px;
        font-weight: 700;
        color: #111827;
        padding-left: 10px;
        border-left: 3px solid #3b5bdb;
    }

    .filter-group { display: flex; gap: 8px; }

    .chip {
        padding: 6px 14px;
        border: 1px solid #e5e7eb;
        border-radius: 20px;
        background: white;
        font-size: 12.5px;
        font-weight: 500;
        color: #6b7280;
        cursor: pointer;
        transition: all 0.15s;
    }

    .chip:hover, .chip.active {
        border-color: #3b5bdb;
        color: #3b5bdb;
        background: #eef2ff;
    }

    .empty-state {
        background: white;
        border: 1px dashed #d1d5db;
        border-radius: 10px;
        padding: 56px 24px;
        text-align: center;
        color: #9ca3af;
    }

    .empty-state .icon { font-size: 36px; margin-bottom: 12px; }
    .empty-state p { font-size: 14px; line-height: 1.6; }

    .count-label {
        font-size: 12.5px;
        color: #9ca3af;
        margin-bottom: 16px;
    }
</style>
@endsection

@section('content')
<div class="home-wrap">

    <div class="hero">
        <div class="hero-label">Archivix Platform</div>
        <h2>Selamat datang 👋</h2>
        <p>Temukan, bagikan, dan unduh berbagai konten edukatif dari komunitas.</p>
    </div>

    <div class="bar">
        <div class="bar-title">Recent Activity</div>
        <div class="filter-group">
            <button class="chip active">Terbaru</button>
            <button class="chip">Semua</button>
        </div>
    </div>

    <div class="count-label">0 item tersedia</div>

    <div class="empty-state">
        <div class="icon">📭</div>
        <p>Belum ada unggahan.<br>Konten akan muncul di sini setelah terhubung ke database.</p>
    </div>

</div>
@endsection