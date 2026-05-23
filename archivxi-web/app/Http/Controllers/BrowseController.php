<?php

namespace App\Http\Controllers;

use App\Services\SupabaseAdminContentService;
use Illuminate\Http\Request;
use Illuminate\View\View;
use RuntimeException;

class BrowseController extends Controller
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
        $categoryId = (string) $request->query('category', 'all');
        $query = trim((string) $request->query('q', ''));
        $payload = [
            'items' => [],
            'stats' => [
                'total' => 0,
                'posts' => 0,
                'papers' => 0,
            ],
        ];
        $categories = [];
        $loadError = null;

        try {
            $categories = $contentService->listCategories();
            $payload = $contentService->browseContent(
                filter: $filter,
                categoryId: $categoryId,
                query: $query,
                userId: $this->sessionUserId($request),
            );
        } catch (RuntimeException $exception) {
            $loadError = $exception->getMessage();
        }

        return view('browse.index', [
            'filter' => $filter,
            'categoryId' => $categoryId,
            'query' => $query,
            'items' => $payload['items'],
            'stats' => $payload['stats'],
            'categories' => $categories,
            'loadError' => $loadError,
        ]);
    }

    private function sessionUserId(Request $request): string
    {
        return (string) (
            data_get($request->session()->get('admin_user'), 'id')
            ?? data_get($request->session()->get('web_user'), 'id')
            ?? ''
        );
    }
}
