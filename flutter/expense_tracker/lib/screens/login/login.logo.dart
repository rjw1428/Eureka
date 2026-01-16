import 'package:flutter/material.dart';

class LoginLogo extends StatefulWidget {
  const LoginLogo({super.key});

  @override
  State<LoginLogo> createState() {
    return _LoginLogoState();
  }
}

class _LoginLogoState extends State<LoginLogo>
    with SingleTickerProviderStateMixin {
  bool visible = false;
  final slideDuration = const Duration(milliseconds: 1000);
  final fadeDuration = const Duration(milliseconds: 500);
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    _controller = AnimationController(
      duration: slideDuration,
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, .5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
    Future.delayed(
      const Duration(milliseconds: 500),
      () {
        if (!mounted) return;
        return setState(() => visible = true);
      },
    );
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: SlideTransition(
        position: _offsetAnimation,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          curve: Curves.easeInOut,
          duration: fadeDuration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(200.0),
            child: Image.asset(
              'assets/images/logo.png',
              height: 300,
              width: 300,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
