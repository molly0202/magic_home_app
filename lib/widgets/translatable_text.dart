import 'package:flutter/material.dart';
import '../services/translation_service.dart';
import 'dart:developer' as developer;

class TranslatableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final TextDirection? textDirection;

  const TranslatableText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.textDirection,
  });

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  final TranslationService _translationService = TranslationService();
  String _translatedText = '';
  bool _isTranslating = false;
  String _lastTranslatedLanguage = '';
  String _lastTranslationEnabled = '';

  @override
  void initState() {
    super.initState();
    _translatedText = widget.text;
    _translationService.addListener(_onTranslationServiceChanged);
    _translateIfNeeded();
  }

  @override
  void dispose() {
    _translationService.removeListener(_onTranslationServiceChanged);
    super.dispose();
  }

  void _onTranslationServiceChanged() {
    _translateIfNeeded();
  }

  @override
  void didUpdateWidget(TranslatableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translatedText = widget.text;
      _translateIfNeeded();
    }
  }



  Future<void> _translateIfNeeded() async {
    final currentEnabled = _translationService.isTranslationEnabled.toString();
    final currentLanguage = _translationService.currentLanguage;
    
    // Check if translation state changed
    final enabledChanged = _lastTranslationEnabled != currentEnabled;
    final languageChanged = _lastTranslatedLanguage != currentLanguage;
    
    if (!_translationService.isTranslationEnabled) {
      if (_translatedText != widget.text) {
        setState(() {
          _translatedText = widget.text;
        });
      }
      _lastTranslationEnabled = currentEnabled;
      _lastTranslatedLanguage = currentLanguage;
      return;
    }

    // Only translate if something changed and we're not already translating
    if ((enabledChanged || languageChanged) && !_isTranslating && widget.text.isNotEmpty) {
      _lastTranslatedLanguage = currentLanguage;
      _lastTranslationEnabled = currentEnabled;
      
      setState(() {
        _isTranslating = true;
      });

      try {
        developer.log('Translating "${widget.text}" to $currentLanguage');
        final translated = await _translationService.autoTranslate(widget.text);
        if (mounted) {
          setState(() {
            _translatedText = translated;
            _isTranslating = false;
          });
          developer.log('Translation result: "$translated"');
        }
      } catch (e) {
        developer.log('Translation error in TranslatableText: $e');
        if (mounted) {
          setState(() {
            _translatedText = widget.text;
            _isTranslating = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isTranslating
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.style?.color ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.text,
                  style: widget.style?.copyWith(color: widget.style?.color?.withOpacity(0.6)),
                  textAlign: widget.textAlign,
                  maxLines: widget.maxLines,
                  overflow: widget.overflow,
                  softWrap: widget.softWrap,
                  textDirection: widget.textDirection,
                ),
              ],
            )
          : Text(
              _translatedText,
              key: ValueKey(_translatedText),
              style: widget.style,
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
              overflow: widget.overflow,
              softWrap: widget.softWrap,
              textDirection: widget.textDirection,
            ),
    );
  }
}

// Extension to easily convert Text widgets to TranslatableText
extension TextTranslation on Text {
  TranslatableText get translatable {
    return TranslatableText(
      data ?? '',
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap ?? true,
      textDirection: textDirection,
    );
  }
}

// Helper function to create translatable text
TranslatableText t(String text, {TextStyle? style}) {
  return TranslatableText(text, style: style);
}
