import 'package:flutter/material.dart';
import '../services/translation_service.dart';
import 'dart:developer' as developer;

class FloatingTranslationWidget extends StatefulWidget {
  final Widget child;
  
  const FloatingTranslationWidget({
    super.key,
    required this.child,
  });

  @override
  State<FloatingTranslationWidget> createState() => _FloatingTranslationWidgetState();
}

class _FloatingTranslationWidgetState extends State<FloatingTranslationWidget> with TickerProviderStateMixin {
  final TranslationService _translationService = TranslationService();
  bool _isDragging = false;
  Offset _position = const Offset(300, 500); // Right button side of screen
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _translationService.initialize();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              onPanStart: (details) {
                _isDragging = true;
              },
              onPanUpdate: (details) {
                if (_isDragging) {
                  setState(() {
                    _position = Offset(
                      (_position.dx + details.delta.dx).clamp(0.0, MediaQuery.of(context).size.width - 60),
                      (_position.dy + details.delta.dy).clamp(0.0, MediaQuery.of(context).size.height - 60),
                    );
                  });
                }
              },
              onPanEnd: (details) {
                _isDragging = false;
              },
              onTap: _cycleLanguage,
              child: AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value * 0.5, // Subtle rotation
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.lightBlue.shade300,
                              Colors.lightBlue.shade500,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.lightBlue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildCompactContent(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _getCurrentLanguageDisplay(),
          const SizedBox(height: 2),
          Text(
            _getCurrentLanguageCode(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Cycle through languages: EN → ZH → ES → EN
  void _cycleLanguage() async {
    _rotationController.forward().then((_) {
      _rotationController.reset();
    });

    if (!_translationService.isTranslationEnabled) {
      // First tap enables translation and sets to Chinese
      await _translationService.toggleTranslation();
      await _translationService.setLanguage('zh');
      _showLanguageChangedSnackbar('zh');
    } else {
      // Cycle through languages
      final currentLang = _translationService.currentLanguage;
      String nextLang;
      
      switch (currentLang) {
        case 'en':
          nextLang = 'zh';
          break;
        case 'zh':
          nextLang = 'es';
          break;
        case 'es':
          // Complete the cycle - disable translation and return to English
          await _translationService.toggleTranslation();
          await _translationService.setLanguage('en');
          _showTranslationDisabledSnackbar();
          return;
        default:
          nextLang = 'zh';
      }
      
      await _translationService.setLanguage(nextLang);
      _showLanguageChangedSnackbar(nextLang);
    }
  }

  Widget _getCurrentLanguageDisplay() {
    if (!_translationService.isTranslationEnabled) {
      return const Icon(
        Icons.translate,
        color: Colors.white,
        size: 24,
      );
    }
    
    return _getLanguageFlag(_translationService.currentLanguage);
  }

  String _getCurrentLanguageCode() {
    if (!_translationService.isTranslationEnabled) {
      return 'OFF';
    }
    
    return _getShortLanguageName(_translationService.currentLanguage);
  }

  Widget _getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return const Text('🇺🇸', style: TextStyle(fontSize: 24));
      case 'zh':
        return const Text('🇨🇳', style: TextStyle(fontSize: 24));
      case 'es':
        return const Text('🇪🇸', style: TextStyle(fontSize: 24));
      default:
        return const Icon(Icons.language, color: Colors.white, size: 24);
    }
  }

  String _getShortLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'EN';
      case 'zh':
        return 'ZH';
      case 'es':
        return 'ES';
      default:
        return languageCode.toUpperCase();
    }
  }

  void _showTranslationEnabledSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.translate, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Translation ${_translationService.isTranslationEnabled ? 'enabled' : 'disabled'}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.lightBlue.shade500,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showLanguageChangedSnackbar(String languageCode) {
    final languageName = _translationService.getLanguageDisplayName(languageCode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            _getLanguageFlag(languageCode),
            const SizedBox(width: 8),
            Text(
              'Language: $languageName',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.lightBlue.shade400,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showTranslationDisabledSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.translate_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Translation disabled',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade600,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
