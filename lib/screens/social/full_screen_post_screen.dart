import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/translatable_text.dart';

class FullScreenPostScreen extends StatefulWidget {
  final Map<String, dynamic> review;
  final User? currentUser;

  const FullScreenPostScreen({
    Key? key,
    required this.review,
    this.currentUser,
  }) : super(key: key);

  @override
  State<FullScreenPostScreen> createState() => _FullScreenPostScreenState();
}

class _FullScreenPostScreenState extends State<FullScreenPostScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLiked = false;
  int _likeCount = 0;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPostData() async {
    setState(() => _isLoading = true);
    
    try {
      final reviewId = widget.review['reviewId'] ?? widget.review['id'];
      if (reviewId != null) {
        // Load likes
        await _loadLikes(reviewId);
        
        // Load comments
        await _loadComments(reviewId);
      }
    } catch (e) {
      print('Error loading post data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLikes(String reviewId) async {
    try {
      final likesQuery = await FirebaseFirestore.instance
          .collection('post_likes')
          .where('reviewId', isEqualTo: reviewId)
          .get();

      setState(() {
        _likeCount = likesQuery.docs.length;
        
        if (widget.currentUser != null) {
          _isLiked = likesQuery.docs.any((doc) => 
            doc.data()['userId'] == widget.currentUser!.uid
          );
        }
      });
    } catch (e) {
      print('Error loading likes: $e');
    }
  }

  Future<void> _loadComments(String reviewId) async {
    try {
      final commentsQuery = await FirebaseFirestore.instance
          .collection('post_comments')
          .where('reviewId', isEqualTo: reviewId)
          .orderBy('createdAt', descending: false)
          .get();

      setState(() {
        _comments = commentsQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (widget.currentUser == null) return;

    final reviewId = widget.review['reviewId'] ?? widget.review['id'];
    if (reviewId == null) return;

    setState(() => _isLoading = true);

    try {
      final likeRef = FirebaseFirestore.instance.collection('post_likes');
      
      if (_isLiked) {
        // Remove like
        final existingLike = await likeRef
            .where('reviewId', isEqualTo: reviewId)
            .where('userId', isEqualTo: widget.currentUser!.uid)
            .get();
        
        for (final doc in existingLike.docs) {
          await doc.reference.delete();
        }
        
        setState(() {
          _isLiked = false;
          _likeCount--;
        });
      } else {
        // Add like
        await likeRef.add({
          'reviewId': reviewId,
          'userId': widget.currentUser!.uid,
          'userName': widget.currentUser!.displayName ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _isLiked = true;
          _likeCount++;
        });

        // Send notification to post owner
        await _sendLikeNotification(reviewId);
      }
    } catch (e) {
      print('Error toggling like: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    if (widget.currentUser == null || _commentController.text.trim().isEmpty) return;

    final reviewId = widget.review['reviewId'] ?? widget.review['id'];
    if (reviewId == null) return;

    setState(() => _isLoading = true);

    try {
      final commentData = {
        'reviewId': reviewId,
        'userId': widget.currentUser!.uid,
        'userName': widget.currentUser!.displayName ?? 'User',
        'userAvatar': widget.currentUser!.photoURL,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('post_comments')
          .add(commentData);

      // Add to local list
      setState(() {
        _comments.add({
          ...commentData,
          'createdAt': Timestamp.now(),
        });
      });

      _commentController.clear();

      // Send notification to post owner
      await _sendCommentNotification(reviewId);
    } catch (e) {
      print('Error adding comment: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendLikeNotification(String reviewId) async {
    try {
      // Get post owner info
      final postOwnerId = widget.review['userId'];
      if (postOwnerId != null && postOwnerId != widget.currentUser!.uid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'post_like',
          'userId': postOwnerId,
          'fromUserId': widget.currentUser!.uid,
          'fromUserName': widget.currentUser!.displayName ?? 'Someone',
          'reviewId': reviewId,
          'message': '${widget.currentUser!.displayName ?? 'Someone'} liked your post',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error sending like notification: $e');
    }
  }

  Future<void> _sendCommentNotification(String reviewId) async {
    try {
      // Get post owner info
      final postOwnerId = widget.review['userId'];
      if (postOwnerId != null && postOwnerId != widget.currentUser!.uid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'post_comment',
          'userId': postOwnerId,
          'fromUserId': widget.currentUser!.uid,
          'fromUserName': widget.currentUser!.displayName ?? 'Someone',
          'reviewId': reviewId,
          'message': '${widget.currentUser!.displayName ?? 'Someone'} commented on your post',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error sending comment notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // Share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Full-screen image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              child: widget.review['photoUrls'] != null && 
                     (widget.review['photoUrls'] as List).isNotEmpty
                  ? InteractiveViewer(
                      child: Image.network(
                        (widget.review['photoUrls'] as List)[0],
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.image, size: 80, color: Colors.grey),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.image, size: 80, color: Colors.grey),
                    ),
            ),
          ),
          
          // Post details and interactions
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Post header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: widget.review['customerAvatar'] != null
                              ? NetworkImage(widget.review['customerAvatar'])
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: widget.review['customerAvatar'] == null
                              ? Icon(Icons.person, color: Colors.grey[600], size: 24)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.review['customerName'] ?? 'Anonymous',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Service by ${widget.review['providerName'] ?? 'Provider'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Like and comment actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleLike,
                          child: Row(
                            children: [
                              Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                color: _isLiked ? Colors.red : Colors.grey[600],
                                size: 24,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_likeCount',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Row(
                          children: [
                            Icon(Icons.comment_outlined, color: Colors.grey[600], size: 24),
                            const SizedBox(width: 4),
                            Text(
                              '${_comments.length}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Review text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.review['reviewText'] ?? widget.review['review'] ?? 'Great service!',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Comments section
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return _buildCommentItem(comment);
                      },
                    ),
                  ),
                  
                  // Comment input
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: widget.currentUser?.photoURL != null
                              ? NetworkImage(widget.currentUser!.photoURL!)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: widget.currentUser?.photoURL == null
                              ? Icon(Icons.person, color: Colors.grey[600], size: 18)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addComment,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFBB04C),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: comment['userAvatar'] != null
                ? NetworkImage(comment['userAvatar'])
                : null,
            backgroundColor: Colors.grey[300],
            child: comment['userAvatar'] == null
                ? Icon(Icons.person, color: Colors.grey[600], size: 16)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: comment['userName'] ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: comment['comment'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(comment['createdAt']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      final DateTime dateTime = timestamp is Timestamp 
          ? timestamp.toDate() 
          : DateTime.parse(timestamp.toString());
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h';
      } else {
        return '${difference.inDays}d';
      }
    } catch (e) {
      return 'Recently';
    }
  }
}
