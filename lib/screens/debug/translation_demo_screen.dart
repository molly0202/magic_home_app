import 'package:flutter/material.dart';
import '../../widgets/translatable_text.dart';
import '../../services/translation_service.dart';

class TranslationDemoScreen extends StatefulWidget {
  const TranslationDemoScreen({super.key});

  @override
  State<TranslationDemoScreen> createState() => _TranslationDemoScreenState();
}

class _TranslationDemoScreenState extends State<TranslationDemoScreen> {
  final TranslationService _translationService = TranslationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatableText('Translation Demo'),
        backgroundColor: const Color(0xFFFBB04C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const TranslatableText(
              'Real-Time Translation Demo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Instructions
            const TranslatableText(
              'Use the floating translation button to switch languages and see the text below translate in real-time.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            
            // Demo content
            _buildDemoContent(),
            
            const Spacer(),
            
            // Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TranslatableText(
                    'Translation Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const TranslatableText('Status: '),
                      Text(
                        _translationService.isTranslationEnabled ? 'Enabled' : 'Disabled',
                        style: TextStyle(
                          color: _translationService.isTranslationEnabled 
                              ? Colors.green 
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const TranslatableText('Language: '),
                      Text(
                        _translationService.getLanguageDisplayName(
                          _translationService.currentLanguage
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoContent() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service categories
            _buildSection(
              'Service Categories',
              [
                'Plumbing',
                'Electrical',
                'Handyman',
                'Cleaning',
                'Gardening',
                'Painting',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Common phrases
            _buildSection(
              'Common Phrases',
              [
                'Welcome to Magic Home',
                'How can we help you today?',
                'Your service request has been submitted',
                'Provider is on the way',
                'Service completed successfully',
                'Please rate your experience',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Sample conversation
            _buildConversationSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatableText(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFBB04C),
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              const Icon(
                Icons.circle,
                size: 6,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TranslatableText(
                  item,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildConversationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TranslatableText(
          'Sample Conversation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFBB04C),
          ),
        ),
        const SizedBox(height: 12),
        
        _buildChatBubble(
          'Hello! I need help with my kitchen faucet. It\'s been leaking for days.',
          isUser: true,
        ),
        
        _buildChatBubble(
          'I can help you with that plumbing issue. Can you describe the type of leak?',
          isUser: false,
        ),
        
        _buildChatBubble(
          'Water is dripping from the base of the faucet handle.',
          isUser: true,
        ),
        
        _buildChatBubble(
          'That sounds like a common issue. I\'ll send a qualified plumber to your location.',
          isUser: false,
        ),
      ],
    );
  }

  Widget _buildChatBubble(String message, {required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFFBB04C),
              child: Icon(Icons.support_agent, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFFFBB04C) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TranslatableText(
                message,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
