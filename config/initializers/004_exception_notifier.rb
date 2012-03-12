ExceptionNotification::Notifier.exception_recipients = [CONFIG["admin_contact"]]
ExceptionNotification::Notifier.sender_address = CONFIG["admin_contact"]
ExceptionNotification::Notifier.email_prefix = "[%s] " % CONFIG["app_name"]
