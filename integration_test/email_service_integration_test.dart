import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_home_app/services/email_service.dart';

void main() {
  group('EmailService Integration Test', () {
    test('should send a real email via EmailJS and upload a file', () async {
      // Arrange
      final testFile = File('test/fixtures/test_image.jpg');
      if (!await testFile.exists()) {
        // Create a small dummy file if it doesn't exist
        await testFile.writeAsBytes(List.filled(1024, 0)); // 1KB
      }
      final providerData = {
        'uid': 'integration_test_user',
        'email': 'integration_test@example.com',
        'companyName': 'Integration Test Company',
        'legalRepresentativeName': 'Integration Tester',
        'phoneNumber': '0000000000',
        'address': 'Integration Test Address',
        'referralCode': 'INTEGRATION',
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
        print('Integration test: Email sent and files uploaded successfully.');
      } catch (e) {
        print('Integration test failed: $e');
        rethrow;
      }
    });
  });
} 