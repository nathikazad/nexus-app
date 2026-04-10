import 'package:flutter/material.dart';

class ExpandingFabMenu extends StatefulWidget {
  final VoidCallback? onModelTypeTap;
  final VoidCallback? onModelTap;

  const ExpandingFabMenu({
    super.key,
    this.onModelTypeTap,
    this.onModelTap,
  });

  @override
  State<ExpandingFabMenu> createState() => _ExpandingFabMenuState();
}

class _ExpandingFabMenuState extends State<ExpandingFabMenu> with TickerProviderStateMixin {
  // Animation controllers for FAB menu
  late AnimationController _fabAnimationController;
  late AnimationController _spiralAnimationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    
    // Controller for rotation animation (swivel) - same duration as spiral
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Controller for spiral animation
    _spiralAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Rotation animation: 0 to 1 full turn (360 degrees)
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0, // Full rotation (360 degrees)
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Scale animation for spiral effect
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _spiralAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _spiralAnimationController.dispose();
    super.dispose();
  }

  void _toggleFabMenu() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimationController.forward();
        _spiralAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
        _spiralAnimationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fabAnimationController, _spiralAnimationController]),
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Spiral in options - always rendered but controlled by opacity/scale
            // Model Type option
            Opacity(
              opacity: _spiralAnimationController.value,
              child: IgnorePointer(
                ignoring: _spiralAnimationController.value < 0.5,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: _spiralAnimationController.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Model Type',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Transform.rotate(
                          angle: _spiralAnimationController.value * 2 * 3.14159, // Full rotation
                          child: FloatingActionButton(
                            heroTag: "model-type-fab",
                            mini: true,
                            onPressed: () {
                              // _toggleFabMenu();
                              widget.onModelTypeTap?.call();
                            },
                            child: const Icon(Icons.category),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Model option
            Opacity(
              opacity: _spiralAnimationController.value,
              child: IgnorePointer(
                ignoring: _spiralAnimationController.value < 0.5,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: _spiralAnimationController.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Model',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Transform.rotate(
                          angle: _spiralAnimationController.value * 3.14159, // Full rotation (same as Model Type)
                          child: FloatingActionButton(
                            heroTag: "model-fab",
                            mini: true,
                            onPressed: () {
                              // _toggleFabMenu();
                              widget.onModelTap?.call();
                            },
                            child: const Icon(Icons.add_box),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Main FAB with swivel animation
            RotationTransition(
              turns: _rotationAnimation,
              child: FloatingActionButton(
                heroTag: "main-fab",
                onPressed: _toggleFabMenu,
                child: Icon(_isFabExpanded ? Icons.close : Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

