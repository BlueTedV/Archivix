<?php

namespace App\Http\Controllers;

use App\Services\SupabaseProfessorVerificationService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;
use RuntimeException;

class ProfessorVerificationController extends Controller
{
    public function index(
        SupabaseProfessorVerificationService $service,
    ): View {
        $queue = [];
        $loadError = null;

        try {
            $queue = $service->loadPendingQueue();
        } catch (RuntimeException $exception) {
            $loadError = $exception->getMessage();
        }

        return view('dashboard.professor_verification.index', [
            'queue' => $queue,
            'loadError' => $loadError,
        ]);
    }

    public function approve(
        Request $request,
        string $requestId,
        SupabaseProfessorVerificationService $service,
    ): RedirectResponse {
        $adminId = (string) data_get($request->session()->get('admin_user'), 'id', '');

        if ($adminId === '') {
            return back()->withErrors(['content' => 'Admin session is missing.']);
        }

        try {
            $service->approveRequest($requestId, $adminId);
        } catch (RuntimeException $exception) {
            return back()->withErrors(['content' => $exception->getMessage()]);
        }

        return redirect()
            ->route('dashboard.professor-verification.index')
            ->with('success', 'Professor verification approved.');
    }

    public function reject(
        Request $request,
        string $requestId,
        SupabaseProfessorVerificationService $service,
    ): RedirectResponse {
        $adminId = (string) data_get($request->session()->get('admin_user'), 'id', '');

        if ($adminId === '') {
            return back()->withErrors(['content' => 'Admin session is missing.']);
        }

        $data = $request->validate([
            'admin_notes' => ['required', 'string', 'max:2000'],
        ]);

        try {
            $service->rejectRequest($requestId, (string) $data['admin_notes'], $adminId);
        } catch (RuntimeException $exception) {
            return back()->withErrors(['content' => $exception->getMessage()]);
        }

        return redirect()
            ->route('dashboard.professor-verification.index')
            ->with('success', 'Professor verification rejected and feedback saved.');
    }

    public function proofUrl(
        string $requestId,
        SupabaseProfessorVerificationService $service,
    ): RedirectResponse {
        try {
            $signedUrl = $service->createProofSignedUrl($requestId);
        } catch (RuntimeException $exception) {
            return back()->withErrors(['content' => $exception->getMessage()]);
        }

        return redirect()->away($signedUrl);
    }
}
