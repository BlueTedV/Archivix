<?php

namespace Tests\Feature;

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

    public function test_guests_are_redirected_to_admin_login_when_opening_dashboard(): void
    {
        $response = $this->get(route('dashboard'));

        $response->assertRedirect(route('admin.login'));
    }
}
