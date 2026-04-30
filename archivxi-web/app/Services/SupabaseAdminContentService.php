<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

class SupabaseAdminContentService
{
    /**
     * @return array{
     *   items: array<int, array<string, mixed>>,
     *   posts: array<int, array<string, mixed>>,
     *   papers: array<int, array<string, mixed>>,
     *   reviewQueue: array<int, array<string, mixed>>,
     *   stats: array<string, int>
     * }
     */
    public function listContent(string $filter = 'all'): array
    {
        $posts = in_array($filter, ['all', 'posts'], true)
            ? $this->fetchPosts()
            : [];
        $papers = in_array($filter, ['all', 'papers'], true)
            ? $this->fetchPapers()
            : [];

        /** @var array<int, array<string, mixed>> $items */
        $items = collect([...$posts, ...$papers])
            ->sortByDesc(fn (array $item) => (string) ($item['created_at'] ?? ''))
            ->values()
            ->all();
        $reviewQueue = collect($papers)
            ->whereIn('status', ['submitted', 'under_review'])
            ->sortBy(fn (array $item) => (string) (
                $item['submitted_at']
                ?? $item['created_at']
                ?? ''
            ))
            ->values()
            ->all();

        return [
            'items' => $items,
            'posts' => $posts,
            'papers' => $papers,
            'reviewQueue' => $reviewQueue,
            'stats' => [
                'total' => count($items),
                'posts' => count($posts),
                'papers' => count($papers),
                'published_papers' => collect($papers)
                    ->where('status', 'published')
                    ->count(),
                'submitted_papers' => collect($papers)
                    ->where('status', 'submitted')
                    ->count(),
                'under_review_papers' => collect($papers)
                    ->where('status', 'under_review')
                    ->count(),
                'rejected_papers' => collect($papers)
                    ->where('status', 'rejected')
                    ->count(),
            ],
        ];
    }

    /**
     * @return array<int, array{id: string, name: string}>
     */
    public function listCategories(): array
    {
        $rows = $this->getRows('categories', [
            'select' => 'id,name',
            'order' => 'name.asc',
        ]);

        return collect($rows)
            ->map(fn (array $row): array => [
                'id' => (string) ($row['id'] ?? ''),
                'name' => (string) ($row['name'] ?? 'Untitled Category'),
            ])
            ->filter(fn (array $row): bool => $row['id'] !== '')
            ->values()
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function listPostVersions(string $postId): array
    {
        $rows = $this->getRows('post_versions', [
            'post_id' => 'eq.'.$postId,
            'select' => 'id,version_number,title,content,category_name,attachments_snapshot,created_at',
            'order' => 'version_number.desc',
        ]);

        return collect($rows)
            ->map(function (array $row): array {
                $attachments = collect($row['attachments_snapshot'] ?? [])
                    ->filter(fn ($attachment) => is_array($attachment))
                    ->map(function (array $attachment): array {
                        $fileUrl = (string) ($attachment['file_url'] ?? '');

                        return [
                            ...$attachment,
                            'view_url' => $this->publicStorageUrl(
                                bucket: 'post-attachments',
                                path: $fileUrl,
                            ),
                        ];
                    })
                    ->values()
                    ->all();

                return [
                    'id' => (string) ($row['id'] ?? ''),
                    'version_number' => (int) ($row['version_number'] ?? 0),
                    'title' => (string) ($row['title'] ?? 'Untitled Question'),
                    'content' => (string) ($row['content'] ?? ''),
                    'category_name' => (string) ($row['category_name'] ?? ''),
                    'created_at' => (string) ($row['created_at'] ?? ''),
                    'attachments' => $attachments,
                ];
            })
            ->values()
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    public function getEditableContent(string $type, string $id): array
    {
        return match ($type) {
            'post' => $this->mapEditablePost(
                $this->getSingleRow('posts', [
                    'id' => 'eq.'.$id,
                    'select' => 'id,title,content,category_id,created_at,views_count,user_id,categories(name)',
                    'limit' => '1',
                ]),
                $this->listPostAttachments($id),
            ),
            'paper' => $this->mapEditablePaper($this->getSingleRow('papers', [
                'id' => 'eq.'.$id,
                'select' => 'id,title,abstract,category_id,created_at,submitted_at,reviewed_at,published_at,views_count,user_id,status,rejection_reason,pdf_file_name,pdf_file_size,pdf_url,categories(name)',
                'limit' => '1',
            ])),
            default => throw new RuntimeException('Unsupported content type.'),
        };
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function updatePost(
        string $id,
        array $payload,
        string $editorUserId,
    ): bool
    {
        $currentPost = $this->getEditableContent('post', $id);
        $currentAttachments = $currentPost['attachments'] ?? [];
        $normalizedCategoryId = ($payload['category_id'] ?? '') !== ''
            ? (string) $payload['category_id']
            : null;
        $keepAttachmentIds = collect($payload['keep_attachment_ids'] ?? [])
            ->map(fn ($value) => (string) $value)
            ->filter()
            ->values()
            ->all();
        /** @var array<int, UploadedFile> $newAttachments */
        $newAttachments = $payload['attachments'] ?? [];

        $hasAttachmentChanges =
            count($keepAttachmentIds) !== count($currentAttachments)
            || $newAttachments !== [];
        $hasContentChanges =
            trim((string) ($payload['title'] ?? '')) !== (string) $currentPost['title']
            || trim((string) ($payload['content'] ?? '')) !== (string) $currentPost['content']
            || ($normalizedCategoryId !== ($currentPost['category_id'] ?? null));

        if (! $hasAttachmentChanges && ! $hasContentChanges) {
            return false;
        }

        $this->archivePostVersion(
            post: $currentPost,
            attachments: $currentAttachments,
            editorUserId: $editorUserId,
        );

        $this->patchRow('posts', $id, [
            'title' => trim((string) ($payload['title'] ?? '')),
            'content' => trim((string) ($payload['content'] ?? '')),
            'category_id' => $normalizedCategoryId,
        ]);

        $attachmentsToDelete = collect($currentAttachments)
            ->reject(fn (array $attachment): bool => in_array(
                (string) ($attachment['id'] ?? ''),
                $keepAttachmentIds,
                true,
            ))
            ->pluck('id')
            ->map(fn ($idValue) => (string) $idValue)
            ->filter()
            ->values()
            ->all();

        if ($attachmentsToDelete !== []) {
            foreach ($attachmentsToDelete as $attachmentId) {
                $this->deleteRows('post_attachments', [
                    'id' => 'eq.'.$attachmentId,
                ]);
            }
        }

        foreach (array_values($newAttachments) as $index => $attachment) {
            $extension = $attachment->getClientOriginalExtension();
            $fileName = $attachment->getClientOriginalName();
            $storageName = now()->timestamp.'_'.Str::random(8)
                .($extension !== '' ? '.'.$extension : '');
            $storagePath = $currentPost['user_id'].'/'.$storageName;

            $this->uploadStorageObject(
                bucket: 'post-attachments',
                path: $storagePath,
                file: $attachment,
            );

            $this->insertRow('post_attachments', [
                'post_id' => $id,
                'file_url' => $storagePath,
                'file_name' => $fileName,
                'file_type' => $this->detectAttachmentType($extension),
                'file_size' => $attachment->getSize(),
                'mime_type' => $attachment->getClientMimeType(),
            ]);
        }

        return true;
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function updatePaper(
        string $id,
        array $payload,
        string $editorUserId,
    ): bool
    {
        $currentPaper = $this->getEditableContent('paper', $id);
        $normalizedCategoryId = ($payload['category_id'] ?? '') !== ''
            ? (string) $payload['category_id']
            : null;
        /** @var UploadedFile|null $replacementPdf */
        $replacementPdf = $payload['replacement_pdf'] ?? null;
        $hasFileChange = $replacementPdf instanceof UploadedFile;
        $hasContentChanges =
            trim((string) ($payload['title'] ?? '')) !== (string) $currentPaper['title']
            || trim((string) ($payload['abstract'] ?? '')) !== (string) $currentPaper['abstract']
            || ($normalizedCategoryId !== ($currentPaper['category_id'] ?? null));

        if (! $hasFileChange && ! $hasContentChanges) {
            return false;
        }

        $this->archivePaperVersion(
            paper: $currentPaper,
            editorUserId: $editorUserId,
        );

        $updatePayload = [
            'title' => trim((string) ($payload['title'] ?? '')),
            'abstract' => trim((string) ($payload['abstract'] ?? '')),
            'category_id' => $normalizedCategoryId,
        ];

        if ($replacementPdf instanceof UploadedFile) {
            $extension = $replacementPdf->getClientOriginalExtension();
            $storageName = now()->timestamp.'_'.Str::random(8)
                .($extension !== '' ? '.'.$extension : '');
            $storagePath = $currentPaper['user_id'].'/'.$storageName;

            $this->uploadStorageObject(
                bucket: 'papers-pdf',
                path: $storagePath,
                file: $replacementPdf,
            );

            $updatePayload['pdf_url'] = $storagePath;
            $updatePayload['pdf_file_name'] = $replacementPdf->getClientOriginalName();
            $updatePayload['pdf_file_size'] = $replacementPdf->getSize();
        }

        $this->patchRow('papers', $id, $updatePayload);

        return true;
    }

    public function markPaperUnderReview(string $id, string $reviewerUserId): void
    {
        $this->getEditableContent('paper', $id);

        $this->patchRow('papers', $id, [
            'status' => 'under_review',
            'reviewed_at' => null,
            'reviewed_by' => $reviewerUserId,
            'published_at' => null,
            'rejection_reason' => null,
        ]);
    }

    public function publishPaper(string $id, string $reviewerUserId): void
    {
        $paper = $this->getEditableContent('paper', $id);

        $payload = [
            'status' => 'published',
            'reviewed_at' => now()->toIso8601String(),
            'reviewed_by' => $reviewerUserId,
            'rejection_reason' => null,
        ];

        if (($paper['published_at'] ?? null) === null) {
            $payload['published_at'] = now()->toIso8601String();
        }

        $this->patchRow('papers', $id, $payload);
    }

    public function rejectPaper(
        string $id,
        string $rejectionReason,
        string $reviewerUserId,
    ): void {
        $this->getEditableContent('paper', $id);

        $this->patchRow('papers', $id, [
            'status' => 'rejected',
            'reviewed_at' => now()->toIso8601String(),
            'reviewed_by' => $reviewerUserId,
            'published_at' => null,
            'rejection_reason' => trim($rejectionReason),
        ]);
    }

    public function deleteContent(string $type, string $id): void
    {
        $table = match ($type) {
            'post' => 'posts',
            'paper' => 'papers',
            default => throw new RuntimeException('Unsupported content type.'),
        };

        $response = $this->rest()
            ->withHeaders(['Prefer' => 'return=minimal'])
            ->delete('/rest/v1/'.$table.'?'.$this->query(['id' => 'eq.'.$id]));

        if ($response->failed()) {
            throw new RuntimeException('Supabase failed to delete the selected content.');
        }
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function fetchPosts(): array
    {
        $rows = $this->getRows('posts', [
            'select' => 'id,title,content,created_at,views_count,user_id,category_id,categories(name)',
            'order' => 'created_at.desc',
        ]);

        return collect($rows)
            ->map(fn (array $row): array => $this->mapListPost($row))
            ->values()
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function fetchPapers(): array
    {
        $rows = $this->getRows('papers', [
            'select' => 'id,title,abstract,created_at,submitted_at,reviewed_at,published_at,views_count,user_id,category_id,status,rejection_reason,pdf_file_name,categories(name)',
            'order' => 'created_at.desc',
        ]);

        return collect($rows)
            ->map(fn (array $row): array => $this->mapListPaper($row))
            ->values()
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function listPostAttachments(string $postId): array
    {
        return $this->getRows('post_attachments', [
            'post_id' => 'eq.'.$postId,
            'select' => 'id,file_url,file_name,file_type,file_size,mime_type,created_at',
            'order' => 'created_at.asc',
        ]);
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function listPaperAuthors(string $paperId): array
    {
        return $this->getRows('paper_authors', [
            'paper_id' => 'eq.'.$paperId,
            'select' => 'name,email,affiliation,author_order',
            'order' => 'author_order.asc',
        ]);
    }

    /**
     * @param array<string, string> $params
     * @return array<int, array<string, mixed>>
     */
    private function getRows(string $table, array $params): array
    {
        $response = $this->rest()->get('/rest/v1/'.$table, $params);

        if ($response->failed()) {
            throw new RuntimeException('Supabase failed to load '.$table.'.');
        }

        $json = $response->json();

        if (! is_array($json)) {
            return [];
        }

        /** @var array<int, array<string, mixed>> $rows */
        $rows = array_values(array_filter($json, 'is_array'));

        return $rows;
    }

    /**
     * @param array<string, string> $params
     * @return array<string, mixed>
     */
    private function getSingleRow(string $table, array $params): array
    {
        $rows = $this->getRows($table, $params);

        if ($rows === []) {
            throw new RuntimeException('Requested content could not be found.');
        }

        return $rows[0];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function patchRow(string $table, string $id, array $payload): void
    {
        $response = $this->rest()
            ->asJson()
            ->withHeaders(['Prefer' => 'return=minimal'])
            ->patch('/rest/v1/'.$table.'?'.$this->query(['id' => 'eq.'.$id]), $payload);

        if ($response->failed()) {
            throw new RuntimeException('Supabase failed to update the selected content.');
        }
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function insertRow(string $table, array $payload): void
    {
        $response = $this->rest()
            ->asJson()
            ->withHeaders(['Prefer' => 'return=minimal'])
            ->post('/rest/v1/'.$table, $payload);

        if ($response->failed()) {
            throw new RuntimeException('Supabase failed to insert into '.$table.'.');
        }
    }

    /**
     * @param array<string, string> $filters
     */
    private function deleteRows(string $table, array $filters): void
    {
        $response = $this->rest()
            ->withHeaders(['Prefer' => 'return=minimal'])
            ->delete('/rest/v1/'.$table.'?'.$this->query($filters));

        if ($response->failed()) {
            throw new RuntimeException('Supabase failed to delete from '.$table.'.');
        }
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private function mapListPost(array $row): array
    {
        return [
            'id' => (string) ($row['id'] ?? ''),
            'type' => 'post',
            'type_label' => 'Question',
            'title' => (string) ($row['title'] ?? 'Untitled Question'),
            'excerpt' => Str::limit(trim((string) ($row['content'] ?? '')), 150),
            'created_at' => (string) ($row['created_at'] ?? ''),
            'views_count' => (int) ($row['views_count'] ?? 0),
            'user_id' => (string) ($row['user_id'] ?? ''),
            'category_id' => $row['category_id'] ?? null,
            'category_name' => (string) data_get($row, 'categories.name', 'Uncategorized'),
            'status' => 'live',
        ];
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private function mapListPaper(array $row): array
    {
        $status = (string) ($row['status'] ?? 'draft');

        return [
            'id' => (string) ($row['id'] ?? ''),
            'type' => 'paper',
            'type_label' => 'Document',
            'title' => (string) ($row['title'] ?? 'Untitled Document'),
            'excerpt' => Str::limit(trim((string) ($row['abstract'] ?? '')), 150),
            'created_at' => (string) ($row['created_at'] ?? ''),
            'submitted_at' => ($row['submitted_at'] ?? null) !== null
                ? (string) $row['submitted_at']
                : null,
            'reviewed_at' => ($row['reviewed_at'] ?? null) !== null
                ? (string) $row['reviewed_at']
                : null,
            'published_at' => ($row['published_at'] ?? null) !== null
                ? (string) $row['published_at']
                : null,
            'views_count' => (int) ($row['views_count'] ?? 0),
            'user_id' => (string) ($row['user_id'] ?? ''),
            'category_id' => $row['category_id'] ?? null,
            'category_name' => (string) data_get($row, 'categories.name', 'Uncategorized'),
            'status' => $status,
            'rejection_reason' => (string) ($row['rejection_reason'] ?? ''),
            'pdf_file_name' => (string) ($row['pdf_file_name'] ?? ''),
        ];
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private function mapEditablePost(array $row, array $attachments): array
    {
        return [
            'id' => (string) ($row['id'] ?? ''),
            'type' => 'post',
            'type_label' => 'Question',
            'title' => (string) ($row['title'] ?? ''),
            'content' => (string) ($row['content'] ?? ''),
            'category_id' => ($row['category_id'] ?? null) !== null
                ? (string) $row['category_id']
                : null,
            'category_name' => (string) data_get($row, 'categories.name', 'Uncategorized'),
            'created_at' => (string) ($row['created_at'] ?? ''),
            'views_count' => (int) ($row['views_count'] ?? 0),
            'user_id' => (string) ($row['user_id'] ?? ''),
            'attachments' => $attachments,
        ];
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private function mapEditablePaper(array $row): array
    {
        return [
            'id' => (string) ($row['id'] ?? ''),
            'type' => 'paper',
            'type_label' => 'Document',
            'title' => (string) ($row['title'] ?? ''),
            'abstract' => (string) ($row['abstract'] ?? ''),
            'category_id' => ($row['category_id'] ?? null) !== null
                ? (string) $row['category_id']
                : null,
            'category_name' => (string) data_get($row, 'categories.name', 'Uncategorized'),
            'created_at' => (string) ($row['created_at'] ?? ''),
            'submitted_at' => ($row['submitted_at'] ?? null) !== null
                ? (string) $row['submitted_at']
                : null,
            'reviewed_at' => ($row['reviewed_at'] ?? null) !== null
                ? (string) $row['reviewed_at']
                : null,
            'published_at' => ($row['published_at'] ?? null) !== null
                ? (string) $row['published_at']
                : null,
            'views_count' => (int) ($row['views_count'] ?? 0),
            'user_id' => (string) ($row['user_id'] ?? ''),
            'status' => (string) ($row['status'] ?? 'draft'),
            'rejection_reason' => (string) ($row['rejection_reason'] ?? ''),
            'pdf_file_name' => (string) ($row['pdf_file_name'] ?? ''),
            'pdf_file_size' => ($row['pdf_file_size'] ?? null) !== null
                ? (int) $row['pdf_file_size']
                : null,
            'pdf_url' => (string) ($row['pdf_url'] ?? ''),
        ];
    }

    /**
     * @param array<string, mixed> $post
     * @param array<int, array<string, mixed>> $attachments
     */
    private function archivePostVersion(
        array $post,
        array $attachments,
        string $editorUserId,
    ): void {
        $versionNumber = $this->nextVersionNumber(
            table: 'post_versions',
            foreignKey: 'post_id',
            contentId: (string) $post['id'],
        );

        $this->insertRow('post_versions', [
            'post_id' => $post['id'],
            'version_number' => $versionNumber,
            'title' => $post['title'],
            'content' => $post['content'],
            'category_id' => $post['category_id'],
            'category_name' => $post['category_name'],
            'attachments_snapshot' => $attachments,
            'owner_user_id' => $post['user_id'],
            'editor_user_id' => $editorUserId,
        ]);
    }

    /**
     * @param array<string, mixed> $paper
     */
    private function archivePaperVersion(
        array $paper,
        string $editorUserId,
    ): void {
        $versionNumber = $this->nextVersionNumber(
            table: 'paper_versions',
            foreignKey: 'paper_id',
            contentId: (string) $paper['id'],
        );

        $archivedPdfUrl = $this->freezePaperPdf(
            paper: $paper,
            versionNumber: $versionNumber,
        );

        $this->insertRow('paper_versions', [
            'paper_id' => $paper['id'],
            'version_number' => $versionNumber,
            'title' => $paper['title'],
            'abstract' => $paper['abstract'],
            'category_id' => $paper['category_id'],
            'category_name' => $paper['category_name'],
            'pdf_url' => $archivedPdfUrl,
            'pdf_file_name' => $paper['pdf_file_name'],
            'pdf_file_size' => $paper['pdf_file_size'],
            'authors_snapshot' => $this->listPaperAuthors((string) $paper['id']),
            'owner_user_id' => $paper['user_id'],
            'editor_user_id' => $editorUserId,
        ]);
    }

    /**
     * @param array<string, mixed> $paper
     */
    private function freezePaperPdf(array $paper, int $versionNumber): ?string
    {
        $rawPdfUrl = trim((string) ($paper['pdf_url'] ?? ''));
        if ($rawPdfUrl === '') {
            return null;
        }

        if (Str::startsWith($rawPdfUrl, ['http://', 'https://'])) {
            return $rawPdfUrl;
        }

        $originalFileName = trim((string) ($paper['pdf_file_name'] ?? ''));
        $extension = pathinfo(
            $originalFileName !== '' ? $originalFileName : $rawPdfUrl,
            PATHINFO_EXTENSION,
        );
        $safePaperId = str_replace('-', '', (string) $paper['id']);
        $archivedPath = $paper['user_id']
            .'/history_'.$safePaperId.'_v'.$versionNumber.'_'.now()->timestamp
            .($extension !== '' ? '.'.$extension : '.pdf');

        $response = $this->storage()
            ->asJson()
            ->post('/storage/v1/object/copy', [
                'bucketId' => 'papers-pdf',
                'sourceKey' => $rawPdfUrl,
                'destinationKey' => $archivedPath,
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Supabase failed to archive the current PDF version.');
        }

        return $archivedPath;
    }

    private function nextVersionNumber(
        string $table,
        string $foreignKey,
        string $contentId,
    ): int {
        $latest = $this->getRows($table, [
            $foreignKey => 'eq.'.$contentId,
            'select' => 'version_number',
            'order' => 'version_number.desc',
            'limit' => '1',
        ]);

        if ($latest === []) {
            return 1;
        }

        return ((int) ($latest[0]['version_number'] ?? 0)) + 1;
    }

    private function uploadStorageObject(
        string $bucket,
        string $path,
        UploadedFile $file,
    ): void {
        $mimeType = $file->getMimeType() ?: 'application/octet-stream';
        $contents = file_get_contents($file->getRealPath());

        if ($contents === false) {
            throw new RuntimeException('Laravel could not read the uploaded file.');
        }

        $response = $this->storage()
            ->withHeaders([
                'Content-Type' => $mimeType,
                'x-upsert' => 'false',
            ])
            ->withBody($contents, $mimeType)
            ->post('/storage/v1/object/'.$bucket.'/'.$path);

        if ($response->failed()) {
            throw new RuntimeException('Supabase Storage failed to upload the selected file.');
        }
    }

    private function detectAttachmentType(?string $extension): string
    {
        $normalized = strtolower((string) $extension);
        $imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        $videoExtensions = ['mp4', 'mov', 'avi', 'mkv'];

        if (in_array($normalized, $imageExtensions, true)) {
            return 'image';
        }

        if (in_array($normalized, $videoExtensions, true)) {
            return 'video';
        }

        return 'document';
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

    private function storage()
    {
        $supabaseUrl = rtrim((string) config('services.supabase.url'), '/');
        $serviceRoleKey = (string) config('services.supabase.service_role_key');

        if ($supabaseUrl === '' || $serviceRoleKey === '') {
            throw new RuntimeException(
                'Supabase service role credentials are missing on the Laravel server.',
            );
        }

        return Http::baseUrl($supabaseUrl)
            ->timeout(60)
            ->withHeaders([
                'apikey' => $serviceRoleKey,
                'Authorization' => 'Bearer '.$serviceRoleKey,
            ]);
    }

    /**
     * @param array<string, string> $params
     */
    private function query(array $params): string
    {
        return http_build_query($params, '', '&', PHP_QUERY_RFC3986);
    }

    private function publicStorageUrl(string $bucket, string $path): string
    {
        if ($path === '') {
            return '';
        }

        if (Str::startsWith($path, ['http://', 'https://'])) {
            return $path;
        }

        $supabaseUrl = rtrim((string) config('services.supabase.url'), '/');
        $encodedPath = str_replace('%2F', '/', rawurlencode($path));

        return $supabaseUrl.'/storage/v1/object/public/'.$bucket.'/'.$encodedPath;
    }
}
