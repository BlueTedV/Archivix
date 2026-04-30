<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

class SupabaseUserDashboardService
{
    /**
     * @return array{
     *   stats: array<string, int>,
     *   papers: array<int, array<string, mixed>>,
     *   posts: array<int, array<string, mixed>>,
     *   recent_items: array<int, array<string, mixed>>,
     *   alerts: array<int, array<string, mixed>>,
     *   latest_feedback: array<int, array<string, mixed>>
     * }
     */
    public function dashboardData(string $userId): array
    {
        $papers = $this->fetchPapers($userId);
        $posts = $this->fetchPosts($userId);

        /** @var array<int, array<string, mixed>> $recentItems */
        $recentItems = collect([...$papers, ...$posts])
            ->sortByDesc(fn (array $item) => (string) ($item['created_at'] ?? ''))
            ->take(8)
            ->values()
            ->all();

        /** @var array<int, array<string, mixed>> $alerts */
        $alerts = collect($papers)
            ->map(fn (array $paper): ?array => $this->paperAlert($paper))
            ->filter()
            ->take(4)
            ->values()
            ->all();

        /** @var array<int, array<string, mixed>> $latestFeedback */
        $latestFeedback = collect($papers)
            ->filter(fn (array $paper): bool => trim((string) ($paper['rejection_reason'] ?? '')) !== '')
            ->sortByDesc(fn (array $paper) => (string) (
                $paper['reviewed_at']
                ?? $paper['created_at']
                ?? ''
            ))
            ->take(3)
            ->values()
            ->all();

        return [
            'stats' => [
                'papers' => count($papers),
                'posts' => count($posts),
                'draft_papers' => collect($papers)->where('status', 'draft')->count(),
                'submitted_papers' => collect($papers)->where('status', 'submitted')->count(),
                'under_review_papers' => collect($papers)->where('status', 'under_review')->count(),
                'published_papers' => collect($papers)->where('status', 'published')->count(),
                'rejected_papers' => collect($papers)->where('status', 'rejected')->count(),
                'total_views' => collect([...$papers, ...$posts])->sum('views_count'),
            ],
            'papers' => $papers,
            'posts' => $posts,
            'recent_items' => $recentItems,
            'alerts' => $alerts,
            'latest_feedback' => $latestFeedback,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function fetchPapers(string $userId): array
    {
        $rows = $this->getRows('papers', [
            'user_id' => 'eq.'.$userId,
            'select' => 'id,title,abstract,created_at,submitted_at,reviewed_at,published_at,views_count,user_id,category_id,status,rejection_reason,pdf_file_name,categories(name)',
            'order' => 'created_at.desc',
        ]);

        return collect($rows)
            ->map(fn (array $row): array => [
                'id' => (string) ($row['id'] ?? ''),
                'type' => 'paper',
                'type_label' => 'Document',
                'title' => (string) ($row['title'] ?? 'Untitled Document'),
                'excerpt' => Str::limit(trim((string) ($row['abstract'] ?? '')), 150),
                'created_at' => (string) ($row['created_at'] ?? ''),
                'submitted_at' => ($row['submitted_at'] ?? null) !== null ? (string) $row['submitted_at'] : null,
                'reviewed_at' => ($row['reviewed_at'] ?? null) !== null ? (string) $row['reviewed_at'] : null,
                'published_at' => ($row['published_at'] ?? null) !== null ? (string) $row['published_at'] : null,
                'views_count' => (int) ($row['views_count'] ?? 0),
                'status' => (string) ($row['status'] ?? 'draft'),
                'category_name' => (string) data_get($row, 'categories.name', 'Uncategorized'),
                'rejection_reason' => (string) ($row['rejection_reason'] ?? ''),
                'pdf_file_name' => (string) ($row['pdf_file_name'] ?? ''),
            ])
            ->values()
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function fetchPosts(string $userId): array
    {
        $rows = $this->getRows('posts', [
            'user_id' => 'eq.'.$userId,
            'select' => 'id,title,content,created_at,views_count,user_id,category_id,categories(name)',
            'order' => 'created_at.desc',
        ]);

        return collect($rows)
            ->map(fn (array $row): array => [
                'id' => (string) ($row['id'] ?? ''),
                'type' => 'post',
                'type_label' => 'Question',
                'title' => (string) ($row['title'] ?? 'Untitled Question'),
                'excerpt' => Str::limit(trim((string) ($row['content'] ?? '')), 150),
                'created_at' => (string) ($row['created_at'] ?? ''),
                'views_count' => (int) ($row['views_count'] ?? 0),
                'status' => 'live',
                'category_name' => (string) data_get($row, 'categories.name', 'Uncategorized'),
            ])
            ->values()
            ->all();
    }

    /**
     * @return array<string, mixed>|null
     */
    private function paperAlert(array $paper): ?array
    {
        $status = (string) ($paper['status'] ?? 'draft');

        return match ($status) {
            'rejected' => [
                'tone' => 'danger',
                'title' => 'Revision needed',
                'message' => 'Your document "'.$paper['title'].'" was rejected. Review the latest feedback below.',
                'timestamp' => (string) ($paper['reviewed_at'] ?? $paper['created_at'] ?? ''),
            ],
            'under_review' => [
                'tone' => 'info',
                'title' => 'Document under review',
                'message' => 'Your document "'.$paper['title'].'" is currently being reviewed.',
                'timestamp' => (string) ($paper['submitted_at'] ?? $paper['created_at'] ?? ''),
            ],
            'published' => [
                'tone' => 'success',
                'title' => 'Document published',
                'message' => 'Your document "'.$paper['title'].'" is now published.',
                'timestamp' => (string) ($paper['published_at'] ?? $paper['created_at'] ?? ''),
            ],
            'submitted' => [
                'tone' => 'warning',
                'title' => 'Submitted successfully',
                'message' => 'Your document "'.$paper['title'].'" is waiting in the review queue.',
                'timestamp' => (string) ($paper['submitted_at'] ?? $paper['created_at'] ?? ''),
            ],
            default => null,
        };
    }

    /**
     * @param array<string, string> $params
     * @return array<int, array<string, mixed>>
     */
    private function getRows(string $table, array $params): array
    {
        $response = $this->rest()->get('/rest/v1/'.$table, $params);

        if ($response->failed()) {
            throw new RuntimeException('Supabase failed to load '.$table.' for the user dashboard.');
        }

        $json = $response->json();

        if (! is_array($json)) {
            return [];
        }

        /** @var array<int, array<string, mixed>> $rows */
        $rows = array_values(array_filter($json, 'is_array'));

        return $rows;
    }

    private function rest()
    {
        $supabaseUrl = rtrim((string) config('services.supabase.url'), '/');
        $serviceRoleKey = (string) config('services.supabase.service_role_key');

        if ($supabaseUrl === '' || $serviceRoleKey === '') {
            throw new RuntimeException(
                'Supabase service role credentials are missing on the Laravel server.',
            );
        }

        return Http::baseUrl($supabaseUrl)
            ->acceptJson()
            ->timeout(20)
            ->withHeaders([
                'apikey' => $serviceRoleKey,
                'Authorization' => 'Bearer '.$serviceRoleKey,
            ]);
    }
}
