<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class SupabaseProfessorVerificationService
{
    private string $url;
    private string $serviceKey;

    public function __construct()
    {
        $this->url = rtrim((string) config('services.supabase.url'), '/');
        $this->serviceKey = (string) config('services.supabase.service_role_key');
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function loadPendingQueue(): array
    {
        $rows = $this->getRows('professor_verification_requests', [
            'status' => 'eq.pending',
            'select' => 'id,user_id,legal_name,institution,institutional_email,academic_position,department,proof_type,proof_file_path,notes,status,created_at',
            'order' => 'created_at.asc',
        ]);

        return collect($rows)
            ->map(fn (array $row): array => [
                'id' => (string) ($row['id'] ?? ''),
                'user_id' => (string) ($row['user_id'] ?? ''),
                'legal_name' => (string) ($row['legal_name'] ?? 'Unknown'),
                'institution' => (string) ($row['institution'] ?? ''),
                'institutional_email' => (string) ($row['institutional_email'] ?? ''),
                'academic_position' => (string) ($row['academic_position'] ?? ''),
                'department' => (string) ($row['department'] ?? ''),
                'proof_type' => (string) ($row['proof_type'] ?? ''),
                'proof_file_path' => (string) ($row['proof_file_path'] ?? ''),
                'notes' => (string) ($row['notes'] ?? ''),
                'status' => (string) ($row['status'] ?? 'pending'),
                'created_at' => (string) ($row['created_at'] ?? ''),
            ])
            ->values()
            ->all();
    }

    public function approveRequest(string $requestId, string $adminId): void
    {
        // Load the request first so we can update the user's profile.
        $rows = $this->getRows('professor_verification_requests', [
            'id' => 'eq.'.$requestId,
            'select' => 'id,user_id,institution,academic_position,department',
            'limit' => '1',
        ]);

        if ($rows === []) {
            throw new RuntimeException('Verification request not found.');
        }

        $request = $rows[0];
        $userId = (string) ($request['user_id'] ?? '');
        $reviewedAt = now()->toIso8601String();

        // Update the user's profile to mark them as a verified professor.
        $this->patchRow('profiles', $userId, [
            'is_verified_professor' => true,
            'professor_verified_at' => $reviewedAt,
            'professor_verified_by' => $adminId,
            'professor_institution' => $request['institution'],
            'professor_position' => $request['academic_position'],
            'professor_department' => $request['department'],
        ]);

        // Mark the request as approved.
        $this->patchRow('professor_verification_requests', $requestId, [
            'status' => 'approved',
            'reviewed_at' => $reviewedAt,
            'reviewed_by' => $adminId,
            'admin_notes' => null,
        ]);
    }

    public function rejectRequest(string $requestId, string $adminNotes, string $adminId): void
    {
        $this->patchRow('professor_verification_requests', $requestId, [
            'status' => 'rejected',
            'reviewed_at' => now()->toIso8601String(),
            'reviewed_by' => $adminId,
            'admin_notes' => trim($adminNotes),
        ]);
    }

    /**
     * Returns a short-lived signed URL for the proof file so the admin can
     * view it without exposing the private storage bucket publicly.
     */
    public function createProofSignedUrl(string $requestId): string
    {
        $rows = $this->getRows('professor_verification_requests', [
            'id' => 'eq.'.$requestId,
            'select' => 'proof_file_path',
            'limit' => '1',
        ]);

        if ($rows === []) {
            throw new RuntimeException('Verification request not found.');
        }

        $proofPath = (string) ($rows[0]['proof_file_path'] ?? '');
        if ($proofPath === '') {
            throw new RuntimeException('No proof file attached to this request.');
        }

        $response = $this->rest()
            ->asJson()
            ->post('/storage/v1/object/sign/professor-verification-proofs/'.ltrim($proofPath, '/'), [
                'expiresIn' => 600, // 10 minutes
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Could not generate a signed URL for the proof file.');
        }

        $signedUrl = (string) ($response->json('signedURL') ?? '');
        if ($signedUrl === '') {
            throw new RuntimeException('Supabase returned an empty signed URL.');
        }

        return $this->url.'/storage/v1'.$signedUrl;
    }

    // ─── HTTP helpers ─────────────────────────────────────────────────────────

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
     * @param array<string, mixed> $payload
     */
    private function patchRow(string $table, string $id, array $payload): void
    {
        $response = $this->rest()
            ->asJson()
            ->withHeaders(['Prefer' => 'return=minimal'])
            ->patch('/rest/v1/'.$table.'?id=eq.'.$id, $payload);

        if ($response->failed()) {
            throw new RuntimeException('Supabase failed to update '.$table.'.');
        }
    }

    private function rest(): \Illuminate\Http\Client\PendingRequest
    {
        return Http::baseUrl($this->url)
            ->withHeaders([
                'apikey' => $this->serviceKey,
                'Authorization' => 'Bearer '.$this->serviceKey,
            ]);
    }
}
