import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_home_app/services/email_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks
@GenerateMocks([FirebaseStorage, Reference, UploadTask, TaskSnapshot, FirebaseFirestore])
import 'email_service_test.mocks.dart';

void main() {
  late MockFirebaseStorage mockStorage;
  late MockReference mockStorageRef;
  late MockUploadTask mockUploadTask;
  late MockTaskSnapshot mockTaskSnapshot;
  late MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockStorage = MockFirebaseStorage();
    mockStorageRef = MockReference();
    mockUploadTask = MockUploadTask();
    mockTaskSnapshot = MockTaskSnapshot();
    mockFirestore = MockFirebaseFirestore();

    // Setup default mock behavior
    when(mockStorage.ref()).thenReturn(mockStorageRef);
    when(mockStorageRef.child(any)).thenReturn(mockStorageRef);
    when(mockStorageRef.putFile(any, any)).thenReturn(mockUploadTask);
    when(mockUploadTask.timeout(any, onTimeout: anyNamed('onTimeout')))
        .thenAnswer((_) async => mockTaskSnapshot);
    when(mockTaskSnapshot.ref).thenReturn(mockStorageRef);
    when(mockStorageRef.getDownloadURL())
        .thenAnswer((_) async => 'https://example.com/test.jpg');
  });

  group('EmailService Tests', () {
    test('should successfully upload document and send email', () async {
      // Arrange
      final testFile = File('test/fixtures/test_image.jpg');
      final providerData = {
        'uid': 'test_user_123',
        'email': 'test@example.com',
        'companyName': 'Test Company',
        'legalRepresentativeName': 'John Doe',
        'phoneNumber': '1234567890',
        'address': '123 Test St',
        'referralCode': 'TEST123',
      };

      final documentFiles = {
        'governmentId': testFile,
        'businessLicense': testFile,
        'insurance': testFile,
      };

      // Act
      try {
        await EmailService.sendVerificationEmailWithAttachments(
          providerData: providerData,
          documentFiles: documentFiles,
        );

        // Assert
        verify(mockStorageRef.putFile(any, any)).called(3); // Called for each document
        verify(mockStorageRef.getDownloadURL()).called(3); // Called for each document
        verify(mockFirestore.collection('admin_emails').add(any)).called(1);
      } catch (e) {
        fail('Test failed with error: $e');
      }
    });

    test('should handle upload failure gracefully', () async {
      // Arrange
      final testFile = File('test/fixtures/test_image.jpg');
      final providerData = {
        'uid': 'test_user_123',
        'email': 'test@example.com',
        'companyName': 'Test Company',
      };

      final documentFiles = {
        'governmentId': testFile,
      };

      // Mock upload failure
      when(mockStorageRef.putFile(any, any))
          .thenThrow(FirebaseException(plugin: 'storage', code: 'test-error'));

      // Act & Assert
      expect(
        () => EmailService.sendVerificationEmailWithAttachments(
          providerData: providerData,
          documentFiles: documentFiles,
        ),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('should validate file size before upload', () async {
      // Arrange
      final largeFile = File('test/fixtures/large_image.jpg');
      // Create a large file (26MB)
      await largeFile.writeAsBytes(List.filled(26 * 1024 * 1024, 0));
      
      final providerData = {
        'uid': 'test_user_123',
        'email': 'test@example.com',
        'companyName': 'Test Company',
      };

      final documentFiles = {
        'governmentId': largeFile,
      };

      // Act & Assert
      expect(
        () => EmailService.sendVerificationEmailWithAttachments(
          providerData: providerData,
          documentFiles: documentFiles,
        ),
        throwsA(predicate((e) => e.toString().contains('File too large'))),
      );

      // Cleanup
      await largeFile.delete();
    });

    test('should handle empty file', () async {
      // Arrange
      final emptyFile = File('test/fixtures/empty.jpg');
      await emptyFile.create();
      
      final providerData = {
        'uid': 'test_user_123',
        'email': 'test@example.com',
        'companyName': 'Test Company',
      };

      final documentFiles = {
        'governmentId': emptyFile,
      };

      // Act & Assert
      expect(
        () => EmailService.sendVerificationEmailWithAttachments(
          providerData: providerData,
          documentFiles: documentFiles,
        ),
        throwsA(predicate((e) => e.toString().contains('File is empty'))),
      );

      // Cleanup
      await emptyFile.delete();
    });
  });
} 