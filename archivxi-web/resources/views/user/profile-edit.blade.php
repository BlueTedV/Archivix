@extends('layouts.site')
@section('title', 'Edit Profile')

@section('styles')
<style>
    .profile-wrap {
        max-width: 1040px;
        margin: 0 auto;
        padding: 34px 20px 56px;
    }

    .profile-grid {
        display: grid;
        grid-template-columns: 320px minmax(0, 1fr);
        gap: 18px;
    }

    .profile-card,
    .profile-form {
        padding: 24px;
        border-radius: 28px;
        border: 1px solid rgba(214, 222, 234, 0.95);
        background: rgba(255, 255, 255, 0.95);
        box-shadow: 0 18px 36px rgba(14, 30, 56, 0.08);
    }

    .alert {
        border-radius: 18px;
        padding: 12px 14px;
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

    .profile-avatar {
        width: 108px;
        height: 108px;
        display: grid;
        place-items: center;
        margin-bottom: 14px;
        overflow: hidden;
        border-radius: 18px;
        border: 1px solid #cde1f6;
        background: linear-gradient(135deg, #21476f 0%, #3793ff 100%);
        color: #ffffff;
        font-size: 34px;
        font-weight: 800;
    }

    .profile-avatar img {
        width: 100%;
        height: 100%;
        object-fit: cover;
    }

    .profile-card h1 {
        font-size: 24px;
        margin-bottom: 6px;
        color: #132238;
    }

    .profile-handle {
        color: #64768c;
        font-size: 13px;
        margin-bottom: 14px;
    }

    .profile-copy,
    .profile-note,
    .field-note {
        color: #64768c;
        font-size: 13px;
        line-height: 1.7;
    }

    .profile-meta,
    .professor-meta {
        display: grid;
        gap: 12px;
        margin-top: 16px;
    }

    .meta-item {
        padding: 12px 14px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    .meta-item strong {
        display: block;
        margin-bottom: 4px;
        font-size: 12px;
        color: #5f7187;
        text-transform: uppercase;
        letter-spacing: 0.06em;
    }

    .meta-item span {
        color: #132238;
        font-size: 13px;
        line-height: 1.65;
        word-break: break-word;
    }

    .profile-form h2 {
        font-size: 22px;
        margin-bottom: 6px;
        color: #132238;
    }

    .profile-form > p {
        margin-bottom: 18px;
        color: #64768c;
        font-size: 13px;
        line-height: 1.7;
    }

    .form-grid {
        display: grid;
        gap: 16px;
    }

    .checkbox-row {
        display: flex;
        align-items: center;
        gap: 10px;
        margin-top: -2px;
    }

    .checkbox-row input {
        width: 16px;
        height: 16px;
    }

    .actions {
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
        margin-top: 22px;
    }

    .profile-note {
        margin-top: 16px;
        padding: 12px 14px;
        border-radius: 18px;
        background: #f8fbff;
        border: 1px solid #dfe8f2;
    }

    @media (max-width: 920px) {
        .profile-grid {
            grid-template-columns: 1fr;
        }
    }

    @media (max-width: 720px) {
        .profile-wrap {
            padding: 24px 16px 44px;
        }

        .profile-card,
        .profile-form {
            padding: 22px;
        }
    }
</style>
@endsection

@section('content')
@php
    $profile = $profile ?? [];
    $displayName = trim((string) ($profile['display_name'] ?? $sessionUser['name'] ?? 'Archivix User'));
    $username = trim((string) ($profile['username'] ?? $sessionUser['username'] ?? ''));
    $fullName = old('full_name', (string) ($profile['full_name'] ?? ''));
    $bio = old('bio', (string) ($profile['bio'] ?? ''));
    $avatarUrl = (string) ($profile['avatar_url'] ?? '');
    $avatarInitial = strtoupper(substr(ltrim($displayName, '@'), 0, 1));
@endphp

<div class="profile-wrap">
    @if (session('success'))
        <div class="alert alert-success">{{ session('success') }}</div>
    @endif

    @if ($errors->any())
        <div class="alert alert-error">{{ $errors->first() }}</div>
    @endif

    @if ($loadError)
        <div class="alert alert-error">{{ $loadError }}</div>
    @endif

    <div class="profile-grid">
        <aside class="profile-card">
            <div class="profile-avatar">
                @if ($avatarUrl !== '')
                    <img src="{{ $avatarUrl }}" alt="Profile avatar">
                @else
                    <span>{{ $avatarInitial !== '' ? $avatarInitial : '?' }}</span>
                @endif
            </div>

            <h1>{{ $displayName }}</h1>
            <div class="profile-handle">
                {{ $username !== '' ? '@'.$username : ($sessionUser['email'] ?? 'No username yet') }}
            </div>

            <p class="profile-copy">
                {{ trim((string) ($profile['bio'] ?? '')) !== '' ? $profile['bio'] : 'Add a short public description so people know your field, interests, or what you work on.' }}
            </p>

            <div class="profile-meta">
                <div class="meta-item">
                    <strong>Email</strong>
                    <span>{{ $sessionUser['email'] ?? 'Not available' }}</span>
                </div>
                <div class="meta-item">
                    <strong>Public Name</strong>
                    <span>{{ trim((string) ($profile['full_name'] ?? '')) !== '' ? $profile['full_name'] : 'Not set yet' }}</span>
                </div>
            </div>

            @if (($profile['is_verified_professor'] ?? false) === true)
                <div class="professor-meta">
                    <div class="meta-item">
                        <strong>Professor Verification</strong>
                        <span>Verified professor account</span>
                    </div>
                    @if (trim((string) ($profile['professor_institution'] ?? '')) !== '')
                        <div class="meta-item">
                            <strong>Institution</strong>
                            <span>{{ $profile['professor_institution'] }}</span>
                        </div>
                    @endif
                    @if (trim((string) ($profile['professor_position'] ?? '')) !== '')
                        <div class="meta-item">
                            <strong>Position</strong>
                            <span>{{ $profile['professor_position'] }}</span>
                        </div>
                    @endif
                    @if (trim((string) ($profile['professor_department'] ?? '')) !== '')
                        <div class="meta-item">
                            <strong>Department</strong>
                            <span>{{ $profile['professor_department'] }}</span>
                        </div>
                    @endif
                </div>
            @endif
        </aside>

        <section class="profile-form">
            <h2>Edit Profile</h2>
            <p>These fields match the mobile profile editor and control how your public profile appears in search and other Archivix surfaces.</p>

            <form action="{{ route('user.profile.update') }}" method="POST" enctype="multipart/form-data">
                @csrf
                @method('PUT')

                <div class="form-grid">
                    <div>
                        <label for="username" class="form-label">Username</label>
                        <input
                            id="username"
                            name="username"
                            class="form-input"
                            value="{{ old('username', $username) }}"
                            placeholder="your_handle"
                        >
                        <div class="field-note">3-24 characters. Letters, numbers, and underscores only.</div>
                    </div>

                    <div>
                        <label for="full_name" class="form-label">Real Name</label>
                        <input
                            id="full_name"
                            name="full_name"
                            class="form-input"
                            value="{{ $fullName }}"
                            placeholder="Your actual name or research alias"
                        >
                    </div>

                    <div>
                        <label for="bio" class="form-label">Description</label>
                        <textarea
                            id="bio"
                            name="bio"
                            class="form-input"
                            rows="5"
                            maxlength="240"
                            placeholder="Share your field, interests, or what you research. This appears on your public profile."
                        >{{ $bio }}</textarea>
                        <div class="field-note">This is the public description other users will see when they open your profile from search.</div>
                    </div>

                    <div>
                        <label for="avatar" class="form-label">Profile Photo</label>
                        <input id="avatar" name="avatar" type="file" accept="image/*" class="form-input">
                        <div class="field-note">Upload a square-friendly image up to 5 MB. The web version does not crop automatically.</div>
                    </div>

                    @if ($avatarUrl !== '')
                        <label class="checkbox-row">
                            <input type="checkbox" name="remove_avatar" value="1" {{ old('remove_avatar') ? 'checked' : '' }}>
                            <span class="field-note">Remove current profile photo</span>
                        </label>
                    @endif
                </div>

                <div class="actions">
                    <button type="submit" class="btn btn-primary">Save Profile</button>
                    <a href="{{ route('user.dashboard') }}" class="btn btn-secondary">Back to Dashboard</a>
                </div>
            </form>

            <div class="profile-note">
                The mobile app also supports avatar cropping before upload. On web, the original image is uploaded directly.
            </div>
        </section>
    </div>
</div>
@endsection
