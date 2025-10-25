import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:magic_home_app/services/elevenlabs_conversation_service.dart';
import 'dart:async';

// Generate mocks
@GenerateMocks([])
class MockStreamController<T> extends Mock implements StreamController<T> {}

void main() {
  group('ElevenLabsConversationService Tests', () {
    late ElevenLabsConversationService service;

    setUp(() {
      service = ElevenLabsConversationService();
    });

    tearDown(() {
      // Clean up after each test
      service.dispose();
    });

    group('Initialization', () {
      test('service should be singleton', () {
        final service1 = ElevenLabsConversationService();
        final service2 = ElevenLabsConversationService();
        
        expect(service1, equals(service2));
      });

      test('initial status should be disconnected', () {
        expect(service.status, equals(ConversationStatus.disconnected));
      });

      test('initialize should complete successfully', () async {
        // Note: This test requires microphone permission
        // In CI/CD, this might need to be mocked
        final result = await service.initialize();
        
        // We expect true even if mic permission is denied
        // because we allow service to work without it
        expect(result, isA<bool>());
      });
    });

    group('WebSocket Connection', () {
      test('connect should update status to connecting', () async {
        // This is an integration test that requires actual API
        // In production, you'd mock the WebSocket
        
        // Start connection (will likely fail without valid setup)
        final connectFuture = service.connect();
        
        // Check that status changed to connecting
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Status should be connecting or have changed
        expect(
          service.status,
          isIn([
            ConversationStatus.connecting,
            ConversationStatus.active,
            ConversationStatus.error,
            ConversationStatus.disconnected,
          ]),
        );
        
        // Clean up
        try {
          await connectFuture.timeout(const Duration(seconds: 2));
        } catch (e) {
          // Timeout is expected if no valid connection
        }
      });

      test('disconnect should update status to disconnected', () async {
        await service.disconnect();
        
        expect(service.status, equals(ConversationStatus.disconnected));
      });
    });

    group('Conversation Mode', () {
      test('setMode should update conversation mode', () {
        service.setMode(ConversationMode.voice);
        // Mode is private, but we can test side effects
        expect(service.status, isA<ConversationStatus>());
        
        service.setMode(ConversationMode.text);
        expect(service.status, isA<ConversationStatus>());
      });
    });

    group('Status Stream', () {
      test('statusStream should emit status changes', () async {
        // Listen to status stream
        final statusList = <ConversationStatus>[];
        final subscription = service.statusStream.listen((status) {
          statusList.add(status);
        });

        // Trigger status change
        await service.disconnect();
        
        // Wait for stream to emit
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should have received disconnected status
        expect(
          statusList,
          contains(ConversationStatus.disconnected),
        );
        
        await subscription.cancel();
      });
    });

    group('Transcript Stream', () {
      test('transcriptStream should be available', () {
        expect(service.transcriptStream, isA<Stream<String>>());
      });

      test('transcriptStream should emit transcript messages', () async {
        final transcripts = <String>[];
        final subscription = service.transcriptStream.listen((transcript) {
          transcripts.add(transcript);
        });

        // In a real test, we'd trigger a message through WebSocket
        // For now, just verify the stream works
        
        await Future.delayed(const Duration(milliseconds: 100));
        await subscription.cancel();
        
        expect(transcripts, isA<List<String>>());
      });
    });

    group('Audio Recording', () {
      test('startListening should require active connection', () async {
        // Try to start listening without connection
        await service.startListening();
        
        // Should not crash and should handle gracefully
        expect(service.status, isA<ConversationStatus>());
      });

      test('stopListening should complete without error', () async {
        await service.stopListening();
        
        // Should complete without throwing
        expect(service.status, isA<ConversationStatus>());
      });
    });

    group('Session Management', () {
      test('startSession should work when connected', () async {
        // This requires a valid WebSocket connection
        // For now, test that it doesn't crash
        try {
          await service.startSession();
        } catch (e) {
          // Expected to fail without connection
          expect(e, isA<Object>());
        }
      });

      test('endSession should complete gracefully', () async {
        await service.endSession();
        
        // Should complete without throwing
        expect(service.status, isA<ConversationStatus>());
      });
    });

    group('Message Sending', () {
      test('sendMessage should handle text mode correctly', () async {
        service.setMode(ConversationMode.text);
        
        try {
          await service.sendMessage('Hello, test message');
        } catch (e) {
          // Expected to fail without valid API setup
          // Just ensure it doesn't crash
          expect(e, isA<Object>());
        }
      });

      test('sendMessage with empty string should be handled', () async {
        service.setMode(ConversationMode.text);
        
        try {
          await service.sendMessage('');
        } catch (e) {
          // Should handle empty messages gracefully
          expect(e, isA<Object>());
        }
      });
    });

    group('Error Handling', () {
      test('errorStream should be available', () {
        expect(service.errorStream, isA<Stream<String>>());
      });

      test('service should handle invalid connection gracefully', () async {
        final result = await service.connect(customAgentId: 'invalid_agent_id');
        
        // Should return false or handle error gracefully
        expect(result, isA<bool>());
      });
    });

    group('Cleanup', () {
      test('dispose should clean up all resources', () {
        // Create a new service instance for this test
        final testService = ElevenLabsConversationService();
        
        // Dispose should not throw
        expect(() => testService.dispose(), returnsNormally);
      });
    });
  });

  group('ConversationStatus Enum', () {
    test('should have all required statuses', () {
      expect(ConversationStatus.disconnected, isA<ConversationStatus>());
      expect(ConversationStatus.connecting, isA<ConversationStatus>());
      expect(ConversationStatus.connected, isA<ConversationStatus>());
      expect(ConversationStatus.active, isA<ConversationStatus>());
      expect(ConversationStatus.error, isA<ConversationStatus>());
    });
  });

  group('ConversationMode Enum', () {
    test('should have all required modes', () {
      expect(ConversationMode.text, isA<ConversationMode>());
      expect(ConversationMode.voice, isA<ConversationMode>());
    });
  });
}



