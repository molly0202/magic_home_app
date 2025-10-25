# Configuration Files

This directory contains configuration files for the Magic Home app.

## Setup Instructions

### ElevenLabs Configuration

1. **Copy the example secrets file:**
   ```bash
   cp elevenlabs_secrets.dart.example elevenlabs_secrets.dart
   ```

2. **Get your ElevenLabs credentials:**
   - Go to [ElevenLabs Conversational AI](https://elevenlabs.io/app/conversational-ai)
   - Create or select your agent
   - Copy your API Key and Agent ID

3. **Update `elevenlabs_secrets.dart`:**
   ```dart
   static const String apiKey = 'sk_your_actual_api_key_here';
   static const String agentId = 'agent_your_actual_agent_id_here';
   ```

4. **Never commit `elevenlabs_secrets.dart`** - it's already in `.gitignore`

### Other API Configurations

Update `api_config.dart` with your other API keys:
- Gemini API (for AI conversation)
- Google Maps API (for location services)
- Google Translate API (for translations)

## File Structure

```
lib/config/
├── api_config.dart                    # General API configurations
├── elevenlabs_config.dart            # ElevenLabs settings (non-sensitive)
├── elevenlabs_secrets.dart           # 🔒 ElevenLabs credentials (gitignored)
└── elevenlabs_secrets.dart.example   # Template for secrets file
```

## Security Notes

⚠️ **Never commit files containing:**
- API keys
- Secret tokens
- Agent IDs
- Any other sensitive credentials

✅ **Safe to commit:**
- Configuration constants (timeouts, URLs, etc.)
- Example/template files
- This README

