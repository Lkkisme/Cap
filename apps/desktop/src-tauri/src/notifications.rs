use crate::{general_settings::GeneralSettingsStore, AppSounds};
use tauri_plugin_notification::NotificationExt;
use tauri_specta::Event;

#[allow(unused)]
pub enum NotificationType {
    VideoSaved,
    VideoCopiedToClipboard,
    ShareableLinkCopied,
    UploadFailed,
    VideoSaveFailed,
    VideoCopyFailed,
    ShareableLinkFailed,
    ScreenshotSaved,
    ScreenshotCopiedToClipboard,
    ScreenshotSaveFailed,
    ScreenshotCopyFailed,
}

impl NotificationType {
    fn details(&self) -> (&'static str, &'static str, bool) {
        match self {
            NotificationType::VideoSaved => (
                "notifications.videoSaved.title",
                "notifications.videoSaved.body",
                false,
            ),
            NotificationType::VideoCopiedToClipboard => (
                "notifications.videoCopied.title",
                "notifications.videoCopied.body",
                false,
            ),
            NotificationType::ShareableLinkCopied => (
                "notifications.linkCopied.title",
                "notifications.linkCopied.body",
                false,
            ),
            NotificationType::UploadFailed => (
                "notifications.uploadFailed.title",
                "notifications.uploadFailed.body",
                true,
            ),
            NotificationType::VideoSaveFailed => (
                "notifications.videoSaveFailed.title",
                "notifications.videoSaveFailed.body",
                true,
            ),
            NotificationType::VideoCopyFailed => (
                "notifications.videoCopyFailed.title",
                "notifications.videoCopyFailed.body",
                true,
            ),
            NotificationType::ShareableLinkFailed => (
                "notifications.shareFailed.title",
                "notifications.shareFailed.body",
                true,
            ),
            NotificationType::ScreenshotSaved => (
                "notifications.screenshotSaved.title",
                "notifications.screenshotSaved.body",
                false,
            ),
            NotificationType::ScreenshotCopiedToClipboard => (
                "notifications.screenshotCopied.title",
                "notifications.screenshotCopied.body",
                false,
            ),
            NotificationType::ScreenshotSaveFailed => (
                "notifications.screenshotSaveFailed.title",
                "notifications.screenshotSaveFailed.body",
                true,
            ),
            NotificationType::ScreenshotCopyFailed => (
                "notifications.screenshotCopyFailed.title",
                "notifications.screenshotCopyFailed.body",
                true,
            ),
        }
    }

    #[allow(unused)]
    pub fn message(&self) -> &'static str {
        match self {
            NotificationType::UploadFailed => {
                "Failed to upload your video after multiple attempts. Please try again later."
            }
            _ => "",
        }
    }

    #[allow(unused)]
    pub fn title(&self) -> &'static str {
        match self {
            NotificationType::UploadFailed => "Upload Failed",
            _ => "",
        }
    }

    pub fn send(self, app: &tauri::AppHandle) {
        send_notification(app, self);
    }
}

pub fn send_notification(app: &tauri::AppHandle, notification_type: NotificationType) {
    // Check if notifications are enabled in settings
    let enable_notifications = GeneralSettingsStore::get(app)
        .map(|settings| settings.is_some_and(|s| s.enable_notifications))
        .unwrap_or(false);

    if !enable_notifications {
        return;
    }

    let (title, body, is_error) = notification_type.details();

    app.notification()
        .builder()
        .title(title)
        .body(body)
        .show()
        .ok();

    let _ = crate::NewNotification {
        title: title.to_string(),
        body: body.to_string(),
        is_error,
    }
    .emit(app);

    AppSounds::Notification.play();
}
