import 'package:flutter/material.dart';
import '../models/service_bid.dart';
import '../models/user_request.dart';
import '../widgets/translatable_text.dart';

class NewQuoteNotification extends StatefulWidget {
  final ServiceBid bid;
  final UserRequest userRequest;
  final VoidCallback onDismiss;

  const NewQuoteNotification({
    super.key,
    required this.bid,
    required this.userRequest,
    required this.onDismiss,
  });

  @override
  State<NewQuoteNotification> createState() => _NewQuoteNotificationState();
}

class _NewQuoteNotificationState extends State<NewQuoteNotification>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main slide animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // Pulse animation for bling effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Shimmer animation for extra bling
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _animationController.forward();
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: GestureDetector(
                onTap: _dismiss,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFBB04C),
                        const Color(0xFFFBB04C).withOpacity(0.8),
                        const Color(0xFFFBB04C),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBB04C).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Shimmer effect overlay
                          ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                  begin: Alignment(_shimmerAnimation.value - 1, 0),
                                  end: Alignment(_shimmerAnimation.value + 1, 0),
                                ),
                              ),
                            ),
                          ),
                          
                          // Main content - star emoji and text
                          const TranslatableText(
                            '🌟 New Service Quote Received!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
