<?php

namespace App\Http\Controllers;

use App\Services\SupabaseAdminContentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;
use RuntimeException;

class AdminContentController extends Controller
{
    public function index(
        Request $request,
        SupabaseAdminContentService $contentService,
    ): View {
        $filter = in_array(
            $request->query('filter'),
            ['all', 'posts', 'papers'],
            true,
        ) ? (string) $request->query('filter') : 'all';

        $payload = [
            'items' => [],
            'posts' => [],
            'papers' => [],
            'reviewQueue' => [],
            'stats' => [
                'total' => 0,
                'posts' => 0,
                'papers' => 0,
                'published_papers' => 0,
                'submitted_papers' => 0,
                'under_review_papers' => 0,
                'rejected_papers' => 0,
            ],
        ];
        $loadError = null;

        try {
            $payload = $contentService->listContent(
                $filter,
                $this->sessionUserId($request),
            );
        } catch (RuntimeException $exception) {
            $loadError = $exception->getMessage();
        }

        return view('dashboard.posts.index', [
            'filter' => $filter,
            'items' => $payload['items'],
            'reviewQueue' => $payload['reviewQueue'],
            'stats' => $payload['stats'],
            'loadError' => $loadError,
        ]);
    }

    public function edit(
        string $contentType,
        string $contentId,
        SupabaseAdminContentService $contentService,
    ): View {
        $type = $this->normalizeType($contentType);

        try {
            $item = $contentService->getEditableContent($type, $contentId);

            return view('dashboard.posts.edit', [
                'item' => $item,
                'categories' => $contentService->listCategories(),
                'versions' => $type === 'post'
                    ? $contentService->listPostVersions($contentId)
                    : [],
            ]);
        } catch (RuntimeException $exception) {
            abort(404, $exception->getMessage());
        }
    }

    public function show(
        Request $request,
        string $contentType,
        string $contentId,
        SupabaseAdminContentService $contentService,
    ): View {
        $type = $this->normalizeType($contentType);

        try {
            $item = $contentService->getContentDetail(
                $type,
                $contentId,
                $this->sessionUserId($request),
            );
            $this->authorizeContentVisibility($request, $item);

            return view('dashboard.posts.show', [
                'item' => $item,
            ]);
        } catch (RuntimeException $exception) {
            abort(404, $exception->getMessage());
        }
    }

    public function react(
        Request $request,
        string $contentType,
        string $contentId,
        SupabaseAdminContentService $contentService,
    ): JsonResponse|RedirectResponse {
        $type = $this->normalizeType($contentType);
        $userId = $this->sessionUserId($request);

        if ($userId === '') {
            if ($request->expectsJson()) {
                return response()->json([
                    'message' => 'Sign in to react to this content.',
                    'login_url' => route('login'),
                ], 401);
            }

            return redirect()->route('login');
        }

        $data = $request->validate([
            'reaction_value' => ['required', 'integer', 'in:-1,1'],
        ]);

        try {
            $item = $contentService->getContentDetail($type, $contentId, $userId);
            $this->authorizeContentVisibility($request, $item);
            $contentService->toggleReaction(
                $type,
                $contentId,
                $userId,
                (int) $data['reaction_value'],
            );
        } catch (RuntimeException $exception) {
            if ($request->expectsJson()) {
                return response()->json([
                    'message' => $exception->getMessage(),
                ], 422);
            }

            return back()->withErrors(['engagement' => $exception->getMessage()]);
        }

        if ($request->expectsJson()) {
            $item = $contentService->getContentDetail($type, $contentId, $userId);

            return response()->json([
                'message' => 'Reaction updated.',
                'engagement' => [
                    'likes_count' => (int) ($item['likes_count'] ?? 0),
                    'dislikes_count' => (int) ($item['dislikes_count'] ?? 0),
                    'comments_count' => (int) ($item['comments_count'] ?? 0),
                    'user_reaction' => $item['user_reaction'] ?? null,
                ],
            ]);
        }

        return back();
    }

    public function comment(
        Request $request,
        string $contentType,
        string $contentId,
        SupabaseAdminContentService $contentService,
    ): RedirectResponse {
        $type = $this->normalizeType($contentType);
        $userId = $this->sessionUserId($request);

        if ($userId === '') {
            return redirect()->route('login');
        }

        $data = $request->validate([
            'body' => ['required', 'string', 'max:2000'],
        ]);

        try {
            $item = $contentService->getContentDetail($type, $contentId, $userId);
            $this->authorizeContentVisibility($request, $item);
            $contentService->addComment(
                $type,
                $contentId,
                $userId,
                $this->sessionUserName($request),
                (string) $data['body'],
            );
        } catch (RuntimeException $exception) {
            return back()
                ->withInput()
                ->withErrors(['comment' => $exception->getMessage()]);
        }

        return back()->with('success', 'Comment posted.');
    }

    public function update(
        Request $request,
        string $contentType,
        string $contentId,
        SupabaseAdminContentService $contentService,
    ): RedirectResponse {
        $type = $this->normalizeType($contentType);
        $editorUserId = (string) data_get(
            $request->session()->get('admin_user'),
            'id',
            '',
        );

        if ($editorUserId === '') {
            return back()->withErrors([
                'content' => 'Admin session is missing the editor user id.',
            ]);
        }

        if ($type === 'post') {
            $data = $request->validate([
                'title' => ['required', 'string', 'max:255'],
                'content' => ['required', 'string'],
                'category_id' => ['nullable', 'string'],
                'keep_attachment_ids' => ['nullable', 'array'],
                'keep_attachment_ids.*' => ['string'],
                'attachments' => ['nullable', 'array'],
                'attachments.*' => ['file', 'max:51200'],
            ]);

            try {
                $updated = $contentService->updatePost(
                    $contentId,
                    [
                        ...$data,
                        'attachments' => $request->file('attachments', []),
                    ],
                    $editorUserId,
                );
            } catch (RuntimeException $exception) {
                return back()
                    ->withInput()
                    ->withErrors(['content' => $exception->getMessage()]);
            }

            if (! $updated) {
                return back()->with('success', 'No changes to save.');
            }

            return redirect()
                ->route('dashboard.posts.index')
                ->with('success', 'Question updated successfully.');
        }

        $data = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'abstract' => ['required', 'string'],
            'category_id' => ['nullable', 'string'],
            'replacement_pdf' => ['nullable', 'file', 'mimes:pdf', 'max:51200'],
        ]);

        try {
            $updated = $contentService->updatePaper(
                $contentId,
                [
                    ...$data,
                    'replacement_pdf' => $request->file('replacement_pdf'),
                ],
                $editorUserId,
            );
        } catch (RuntimeException $exception) {
            return back()
                ->withInput()
                ->withErrors(['content' => $exception->getMessage()]);
        }

        if (! $updated) {
            return back()->with('success', 'No changes to save.');
        }

        return redirect()
            ->route('dashboard.posts.index', ['filter' => 'papers'])
            ->with('success', 'Document updated successfully.');
    }

    public function publish(
        Request $request,
        string $contentId,
        SupabaseAdminContentService $contentService,
    ): RedirectResponse {
        $reviewerUserId = (string) data_get(
            $request->session()->get('admin_user'),
            'id',
            '',
        );

        if ($reviewerUserId === '') {
            return back()->withErrors([
                'content' => 'Admin session is missing the reviewer user id.',
            ]);
        }

        try {
            $contentService->publishPaper($contentId, $reviewerUserId);
        } catch (RuntimeException $exception) {
            return back()->withErrors(['content' => $exception->getMessage()]);
        }

        return redirect()
            ->route('dashboard.posts.index', ['filter' => 'papers'])
            ->with('success', 'Document published successfully.');
    }

    public function markUnderReview(
        Request $request,
        string $contentId,
        SupabaseAdminContentService $contentService,
    ): RedirectResponse {
        $reviewerUserId = (string) data_get(
            $request->session()->get('admin_user'),
            'id',
            '',
        );

        if ($reviewerUserId === '') {
            return back()->withErrors([
                'content' => 'Admin session is missing the reviewer user id.',
            ]);
        }

        try {
            $contentService->markPaperUnderReview($contentId, $reviewerUserId);
        } catch (RuntimeException $exception) {
            return back()->withErrors(['content' => $exception->getMessage()]);
        }

        return redirect()
            ->route('dashboard.posts.index', ['filter' => 'papers'])
            ->with('success', 'Document moved to under review.');
    }

    public function reject(
        Request $request,
        string $contentId,
        SupabaseAdminContentService $contentService,
    ): RedirectResponse {
        $reviewerUserId = (string) data_get(
            $request->session()->get('admin_user'),
            'id',
            '',
        );

        if ($reviewerUserId === '') {
            return back()->withErrors([
                'content' => 'Admin session is missing the reviewer user id.',
            ]);
        }

        $data = $request->validate([
            'rejection_reason' => ['required', 'string', 'max:2000'],
        ]);

        try {
            $contentService->rejectPaper(
                $contentId,
                (string) $data['rejection_reason'],
                $reviewerUserId,
            );
        } catch (RuntimeException $exception) {
            return back()->withErrors(['content' => $exception->getMessage()]);
        }

        return redirect()
            ->route('dashboard.posts.index', ['filter' => 'papers'])
            ->with('success', 'Document rejected and feedback saved.');
    }

    public function destroy(
        string $contentType,
        string $contentId,
        SupabaseAdminContentService $contentService,
    ): RedirectResponse {
        $type = $this->normalizeType($contentType);

        try {
            $contentService->deleteContent($type, $contentId);
        } catch (RuntimeException $exception) {
            return back()->withErrors(['content' => $exception->getMessage()]);
        }

        return redirect()
            ->route('dashboard.posts.index')
            ->with('success', ucfirst($type).' deleted successfully.');
    }

    private function normalizeType(string $type): string
    {
        return match ($type) {
            'post', 'paper' => $type,
            default => abort(404),
        };
    }

    private function sessionUserId(Request $request): string
    {
        return (string) (
            data_get($request->session()->get('admin_user'), 'id')
            ?? data_get($request->session()->get('web_user'), 'id')
            ?? ''
        );
    }

    private function sessionUserName(Request $request): string
    {
        return (string) (
            data_get($request->session()->get('admin_user'), 'name')
            ?? data_get($request->session()->get('web_user'), 'name')
            ?? data_get($request->session()->get('admin_user'), 'email')
            ?? data_get($request->session()->get('web_user'), 'email')
            ?? 'Archivix User'
        );
    }

    /**
     * @param  array<string, mixed>  $item
     */
    private function authorizeContentVisibility(Request $request, array $item): void
    {
        if ($request->session()->has('admin_user')) {
            return;
        }

        if (($item['type'] ?? '') === 'post') {
            return;
        }

        $sessionUserId = $this->sessionUserId($request);
        $isOwner = $sessionUserId !== '' && $sessionUserId === (string) ($item['user_id'] ?? '');
        $isPublished = (string) ($item['status'] ?? '') === 'published';

        if (! $isOwner && ! $isPublished) {
            abort(404);
        }
    }
}
