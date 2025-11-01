import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/provider_post.dart';

class PostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new post
  static Future<String> createPost({
    required String providerId,
    required String providerName,
    String? providerPhotoUrl,
    required String city,
    String? state,
    required String serviceCategory,
    required String description,
    required List<File> images,
    Map<String, dynamic>? location,
  }) async {
    try {
      // Upload images to Firebase Storage
      final List<String> imageUrls = [];
      for (int i = 0; i < images.length; i++) {
        final storageRef = _storage
            .ref()
            .child('provider_posts')
            .child(providerId)
            .child('${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        
        final uploadTask = storageRef.putFile(images[i]);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      // Create post document
      final post = ProviderPost(
        providerId: providerId,
        providerName: providerName,
        providerPhotoUrl: providerPhotoUrl,
        city: city,
        state: state,
        serviceCategory: serviceCategory,
        description: description,
        imageUrls: imageUrls,
        location: location,
      );

      final docRef = await _firestore.collection('provider_posts').add(post.toFirestore());
      
      print('Post created successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating post: $e');
      throw Exception('Failed to create post: $e');
    }
  }

  // Get all posts (no city constraint)
  static Stream<List<ProviderPost>> getAllPosts({int limit = 50}) {
    return _firestore
        .collection('provider_posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ProviderPost.fromFirestore(doc)).toList();
    });
  }

  // Get posts by a specific provider
  static Stream<List<ProviderPost>> getProviderPosts(String providerId) {
    return _firestore
        .collection('provider_posts')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ProviderPost.fromFirestore(doc)).toList();
    });
  }

  // Delete a post
  static Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('provider_posts').doc(postId).delete();
      print('Post deleted successfully: $postId');
    } catch (e) {
      print('Error deleting post: $e');
      throw Exception('Failed to delete post: $e');
    }
  }

  // Like a post
  static Future<void> likePost(String postId) async {
    try {
      await _firestore.collection('provider_posts').doc(postId).update({
        'likesCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error liking post: $e');
    }
  }

  // Share a post (increment counter)
  static Future<void> sharePost(String postId) async {
    try {
      await _firestore.collection('provider_posts').doc(postId).update({
        'sharesCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error sharing post: $e');
    }
  }
}

