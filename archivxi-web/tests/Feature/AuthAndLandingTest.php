<?php

namespace Tests\Feature;

use App\Services\SupabaseAdminContentService;
use App\Services\SupabaseUserProfileService;
use Illuminate\Support\Facades\Http;
use Mockery;
use Tests\TestCase;

class AuthAndLandingTest extends TestCase
{
    public function test_the_public_landing_page_loads(): void
    {
        $response = $this->get('/');

        $response
            ->assertOk()
            ->assertSee('Archivix');
    }

    public function test_the_admin_login_page_loads(): void
    {
        $response = $this->get(route('admin.login'));

        $response
            ->assertOk()
            ->assertSee('Masuk ke Panel Admin');
    }

    public function test_the_reset_password_page_loads(): void
    {
        $response = $this->get(route('password.reset'));

        $response
            ->assertOk()
            ->assertSee('Reset password akunmu')
            ->assertSee('Simpan Password Baru');
    }

    public function test_the_public_browse_page_loads_for_guests(): void
    {
        $this->app->instance(
            SupabaseAdminContentService::class,
            new class extends SupabaseAdminContentService
            {
                public function listCategories(): array
                {
                    return [];
                }

                public function browseContent(
                    string $filter = 'all',
                    ?string $categoryId = null,
                    ?string $query = null,
                    ?string $userId = null,
                ): array {
                    return [
                        'items' => [],
                        'stats' => [
                            'total' => 0,
                            'posts' => 0,
                            'papers' => 0,
                        ],
                    ];
                }
            },
        );

        $response = $this->get(route('browse.index'));

        $response
            ->assertOk()
            ->assertSee('Find documents and questions')
            ->assertSee('Guests can read document and question pages here');
    }

    public function test_guests_are_redirected_to_admin_login_when_opening_dashboard(): void
    {
        $response = $this->get(route('dashboard'));

        $response->assertRedirect(route('admin.login'));
    }

    public function test_authenticated_users_can_react_with_json_without_a_redirect(): void
    {
        $service = Mockery::mock(SupabaseAdminContentService::class);

        $service->shouldReceive('getContentDetail')
            ->once()
            ->with('post', 'post-123', 'user-123')
            ->andReturn([
                'id' => 'post-123',
                'type' => 'post',
                'user_id' => 'owner-123',
                'likes_count' => 3,
                'dislikes_count' => 1,
                'comments_count' => 2,
                'user_reaction' => null,
            ]);

        $service->shouldReceive('toggleReaction')
            ->once()
            ->with('post', 'post-123', 'user-123', 1);

        $service->shouldReceive('getContentDetail')
            ->once()
            ->with('post', 'post-123', 'user-123')
            ->andReturn([
                'id' => 'post-123',
                'type' => 'post',
                'user_id' => 'owner-123',
                'likes_count' => 4,
                'dislikes_count' => 1,
                'comments_count' => 2,
                'user_reaction' => 1,
            ]);

        $this->app->instance(SupabaseAdminContentService::class, $service);

        $response = $this
            ->withSession([
                'web_user' => [
                    'id' => 'user-123',
                    'email' => 'user@example.com',
                    'name' => 'Archivix User',
                ],
            ])
            ->postJson(route('content.react', [
                'contentType' => 'post',
                'contentId' => 'post-123',
            ]), [
                'reaction_value' => 1,
            ]);

        $response
            ->assertOk()
            ->assertJson([
                'message' => 'Reaction updated.',
                'engagement' => [
                    'likes_count' => 4,
                    'dislikes_count' => 1,
                    'comments_count' => 2,
                    'user_reaction' => 1,
                ],
            ]);
    }

    public function test_logged_in_users_can_open_the_profile_editor(): void
    {
        $service = Mockery::mock(SupabaseUserProfileService::class);
        $service->shouldReceive('getProfile')
            ->once()
            ->with('user-123', 'Archivix User', 'user@example.com')
            ->andReturn([
                'id' => 'user-123',
                'username' => 'archivix_user',
                'full_name' => 'Archivix User',
                'bio' => 'Researching better archive flows.',
                'avatar_path' => '',
                'avatar_url' => '',
                'is_verified_professor' => false,
                'professor_institution' => '',
                'professor_position' => '',
                'professor_department' => '',
                'display_name' => 'Archivix User',
            ]);
        $this->app->instance(SupabaseUserProfileService::class, $service);

        $response = $this
            ->withSession([
                'web_user' => [
                    'id' => 'user-123',
                    'email' => 'user@example.com',
                    'name' => 'Archivix User',
                ],
            ])
            ->get(route('user.profile.edit'));

        $response
            ->assertOk()
            ->assertSee('Edit Profile')
            ->assertSee('archivix_user')
            ->assertSee('Researching better archive flows.');
    }

    public function test_users_can_submit_a_new_password_from_the_reset_page(): void
    {
        config()->set('services.supabase.url', 'https://project-ref.supabase.co');
        config()->set('services.supabase.anon_key', 'public-anon-key');

        Http::fake([
            'https://project-ref.supabase.co/auth/v1/user' => Http::response([], 200),
        ]);

        $response = $this->post(route('password.reset.submit'), [
            'access_token' => 'recovery-access-token',
            'password' => 'new-secret-123',
            'password_confirmation' => 'new-secret-123',
        ]);

        $response
            ->assertRedirect(route('login'))
            ->assertSessionHas('success', 'Password berhasil direset. Silakan login dengan password baru kamu.');

        Http::assertSent(function ($request) {
            return $request->url() === 'https://project-ref.supabase.co/auth/v1/user'
                && $request->method() === 'PUT'
                && $request->header('apikey') === ['public-anon-key']
                && $request->header('Authorization') === ['Bearer recovery-access-token']
                && $request['password'] === 'new-secret-123';
        });
    }
}
