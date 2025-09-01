import 'package:flutter/material.dart';
import '../services/in_app_notification_service.dart';

class NotificationOverlay extends StatefulWidget {
  final Widget child;

  const NotificationOverlay({
    super.key,
    required this.child,
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  @override
  void initState() {
    super.initState();
    // Initialize notifications for this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InAppNotificationService().initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          // Notification overlay space is handled by the InAppNotificationService
          // The service will insert notifications directly into the Overlay
        ],
      ),
    );
  }
}

// Extension to easily add notification support to any widget
extension WidgetNotification on Widget {
  Widget get withNotifications {
    return NotificationOverlay(child: this);
  }
}
