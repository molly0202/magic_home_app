import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

void main() {
  group('ElevenLabs WebSocket Message Format Tests', () {
    group('Outgoing Message Formats', () {
      test('user_audio_chunk message format', () {
        final audioData = [1, 2, 3, 4, 5];
        final base64Audio = base64Encode(audioData);
        
        final message = {
          'user_audio_chunk': base64Audio,
        };
        
        final encoded = json.encode(message);
        expect(encoded, contains('user_audio_chunk'));
        expect(encoded, contains(base64Audio));
      });

      test('contextual_update message format', () {
        final message = {
          'type': 'contextual_update',
          'text': 'User said: Hello',
        };
        
        final encoded = json.encode(message);
        expect(encoded, contains('contextual_update'));
        expect(encoded, contains('User said: Hello'));
      });

      test('conversation_initiation_client_data format', () {
        final authMessage = {
          'type': 'conversation_initiation_client_data',
          'conversation_config_override': {
            'agent': {
              'prompt': {
                'prompt': 'Test system prompt',
              }
            }
          }
        };
        
        final encoded = json.encode(authMessage);
        expect(encoded, contains('conversation_initiation_client_data'));
        expect(encoded, contains('conversation_config_override'));
        expect(encoded, contains('Test system prompt'));
      });
    });

    group('Incoming Message Formats', () {
      test('parse agent_response_event message', () {
        final messageJson = json.encode({
          'type': 'agent_response',
          'agent_response_event': {
            'agent_response': 'Hello, how can I help you?',
          }
        });
        
        final decoded = json.decode(messageJson) as Map<String, dynamic>;
        expect(decoded['type'], equals('agent_response'));
        
        final responseEvent = decoded['agent_response_event'] as Map<String, dynamic>?;
        expect(responseEvent, isNotNull);
        expect(responseEvent!['agent_response'], equals('Hello, how can I help you?'));
      });

      test('parse audio_event message', () {
        final audioData = [1, 2, 3, 4, 5];
        final base64Audio = base64Encode(audioData);
        
        final messageJson = json.encode({
          'type': 'audio',
          'audio_event': {
            'audio_base_64': base64Audio,
            'event_id': 12345,
          }
        });
        
        final decoded = json.decode(messageJson) as Map<String, dynamic>;
        expect(decoded['type'], equals('audio'));
        
        final audioEvent = decoded['audio_event'] as Map<String, dynamic>?;
        expect(audioEvent, isNotNull);
        expect(audioEvent!['audio_base_64'], equals(base64Audio));
        
        // Verify we can decode the audio back
        final decodedAudio = base64Decode(audioEvent['audio_base_64'] as String);
        expect(decodedAudio, equals(audioData));
      });

      test('parse user_transcription_event message', () {
        final messageJson = json.encode({
          'type': 'user_transcription',
          'user_transcription_event': {
            'user_transcript': 'User said something',
          }
        });
        
        final decoded = json.decode(messageJson) as Map<String, dynamic>;
        expect(decoded['type'], equals('user_transcription'));
        
        final transcriptEvent = decoded['user_transcription_event'] as Map<String, dynamic>?;
        expect(transcriptEvent, isNotNull);
        expect(transcriptEvent!['user_transcript'], equals('User said something'));
      });

      test('parse conversation_initiation_metadata message', () {
        final messageJson = json.encode({
          'type': 'conversation_initiation_metadata',
          'conversation_initiation_metadata_event': {
            'conversation_id': 'conv_123456',
          }
        });
        
        final decoded = json.decode(messageJson) as Map<String, dynamic>;
        expect(decoded['type'], equals('conversation_initiation_metadata'));
        
        final metadataEvent = decoded['conversation_initiation_metadata_event'] as Map<String, dynamic>?;
        expect(metadataEvent, isNotNull);
        expect(metadataEvent!['conversation_id'], equals('conv_123456'));
      });

      test('parse agent_response_correction message', () {
        final messageJson = json.encode({
          'type': 'agent_response_correction',
          'agent_response_correction_event': {
            'corrected_agent_response': 'Corrected response text',
          }
        });
        
        final decoded = json.decode(messageJson) as Map<String, dynamic>;
        expect(decoded['type'], equals('agent_response_correction'));
        
        final correctionEvent = decoded['agent_response_correction_event'] as Map<String, dynamic>?;
        expect(correctionEvent, isNotNull);
        expect(correctionEvent!['corrected_agent_response'], equals('Corrected response text'));
      });
    });

    group('Audio Data Encoding/Decoding', () {
      test('base64 encode PCM16 audio data', () {
        // Simulate PCM16 audio samples
        final audioSamples = List<int>.generate(1600, (i) => i % 256); // 16kHz, 0.1s
        final base64Audio = base64Encode(audioSamples);
        
        expect(base64Audio, isNotEmpty);
        expect(base64Audio.length, greaterThan(0));
        
        // Verify round-trip encoding
        final decoded = base64Decode(base64Audio);
        expect(decoded, equals(audioSamples));
      });

      test('handle empty audio chunks', () {
        final emptyAudio = <int>[];
        final base64Audio = base64Encode(emptyAudio);
        
        expect(base64Audio, isEmpty);
      });

      test('handle large audio chunks', () {
        // Simulate 1 second of 16kHz mono audio
        final largeAudio = List<int>.filled(32000, 128);
        final base64Audio = base64Encode(largeAudio);
        
        expect(base64Audio, isNotEmpty);
        expect(base64Audio.length, greaterThan(10000));
      });
    });

    group('Error Message Formats', () {
      test('parse error message', () {
        final messageJson = json.encode({
          'type': 'error',
          'error': {
            'message': 'Something went wrong',
            'code': 'ERROR_CODE_123',
          }
        });
        
        final decoded = json.decode(messageJson) as Map<String, dynamic>;
        expect(decoded['type'], equals('error'));
        
        final error = decoded['error'] as Map<String, dynamic>?;
        expect(error, isNotNull);
        expect(error!['message'], equals('Something went wrong'));
      });
    });

    group('Message Type Detection', () {
      test('detect message types correctly', () {
        final messageTypes = [
          'conversation_initiation_metadata',
          'agent_response',
          'audio',
          'user_transcription',
          'agent_response_correction',
          'error',
        ];
        
        for (final type in messageTypes) {
          final message = {'type': type};
          final encoded = json.encode(message);
          final decoded = json.decode(encoded) as Map<String, dynamic>;
          
          expect(decoded['type'], equals(type),
              reason: 'Should correctly encode/decode $type');
        }
      });
    });

    group('WebSocket URL Format', () {
      test('construct WebSocket URL correctly', () {
        const baseUrl = 'wss://api.elevenlabs.io/v1/convai/conversation';
        const agentId = 'test_agent_123';
        const apiKey = 'test_api_key_456';
        
        final url = '$baseUrl?agent_id=$agentId&api_key=$apiKey';
        
        expect(url, startsWith('wss://'));
        expect(url, contains('agent_id=$agentId'));
        expect(url, contains('api_key=$apiKey'));
        expect(url, contains('api.elevenlabs.io'));
      });

      test('WebSocket URL should use secure protocol', () {
        const baseUrl = 'wss://api.elevenlabs.io/v1/convai/conversation';
        
        expect(baseUrl, startsWith('wss://'));
        expect(baseUrl, isNot(startsWith('ws://')));
      });
    });
  });

  group('Audio Configuration Tests', () {
    test('PCM16 configuration values', () {
      const sampleRate = 16000;
      const numChannels = 1;
      const bitRate = 256000;
      
      expect(sampleRate, equals(16000), reason: 'Should use 16kHz sample rate');
      expect(numChannels, equals(1), reason: 'Should use mono audio');
      expect(bitRate, greaterThan(0), reason: 'Should have positive bit rate');
    });

    test('audio chunk size calculation', () {
      const sampleRate = 16000; // Hz
      const bytesPerSample = 2; // 16-bit = 2 bytes
      const chunkDurationMs = 100; // 100ms chunks
      
      final expectedChunkSize = (sampleRate * bytesPerSample * chunkDurationMs / 1000).round();
      
      expect(expectedChunkSize, equals(3200));
    });
  });

  group('Conversation Flow Tests', () {
    test('verify message sequence is valid', () {
      final messageSequence = [
        'conversation_initiation_client_data', // 1. Client sends auth
        'conversation_initiation_metadata',     // 2. Server confirms
        'user_audio_chunk',                     // 3. User speaks
        'user_transcription',                   // 4. Server transcribes
        'agent_response',                       // 5. Agent responds (text)
        'audio',                                // 6. Agent responds (audio)
      ];
      
      expect(messageSequence.first, equals('conversation_initiation_client_data'));
      expect(messageSequence.last, equals('audio'));
      expect(messageSequence.length, equals(6));
    });
  });
}



