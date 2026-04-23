<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class EmailVerificationCodeNotification extends Notification
{
    use Queueable;

    public function __construct(
        private readonly string $code,
    ) {
    }

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Verify your Archivix account')
            ->greeting('Welcome to Archivix')
            ->line('Use the verification code below to activate your account.')
            ->line('Verification code: '.$this->code)
            ->line('This code expires in 15 minutes.')
            ->line('If you did not create this account, you can ignore this email.');
    }
}
