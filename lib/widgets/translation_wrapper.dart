import 'package:flutter/material.dart';
import 'floating_translation_widget.dart';

/// A wrapper widget that provides translation functionality to any screen
/// This ensures consistent translation UI across all screens
class TranslationWrapper extends StatelessWidget {
  final Widget child;
  final bool showFloatingButton;

  const TranslationWrapper({
    super.key,
    required this.child,
    this.showFloatingButton = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showFloatingButton) {
      return child;
    }

    return FloatingTranslationWidget(
      child: child,
    );
  }

  /// Static method to wrap any widget with translation functionality
  static Widget wrap(Widget child, {bool showFloatingButton = true}) {
    return TranslationWrapper(
      showFloatingButton: showFloatingButton,
      child: child,
    );
  }
}

/// Extension to make it easy to add translation to any widget
extension WidgetTranslation on Widget {
  Widget get withTranslation {
    return TranslationWrapper(child: this);
  }
  
  Widget withTranslation({bool showFloatingButton = true}) {
    return TranslationWrapper(
      showFloatingButton: showFloatingButton,
      child: this,
    );
  }
}
