import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class PRCelebrationOverlay extends StatefulWidget {
  final Widget child;
  final bool isPlaying;

  const PRCelebrationOverlay({
    super.key,
    required this.child,
    required this.isPlaying,
  });

  @override
  State<PRCelebrationOverlay> createState() => _PRCelebrationOverlayState();
}

class _PRCelebrationOverlayState extends State<PRCelebrationOverlay> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 2));
    if (widget.isPlaying) {
      _controller.play();
    }
  }

  @override
  void didUpdateWidget(covariant PRCelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.play();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
          ),
        ),
      ],
    );
  }
}
