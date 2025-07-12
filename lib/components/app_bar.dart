import 'package:flutter/material.dart';
import 'dart:ui';

class StylishAppBar extends StatelessWidget {
  final title;
  final subtitle;

  const StylishAppBar({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          toolbarHeight: 80,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B263B).withValues(alpha: 0.95),
                  Color(0xFF0D1B2A).withValues(alpha: 0.9),
                  Color(0xFF415A77).withValues(alpha: 0.8),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF0D1B2A).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/textures/moroccan.png'),
                  repeat: ImageRepeat.repeat,
                  opacity: 0.15,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.25),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 28,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Color(0xFF415A77).withValues(alpha: 0.9),
                      offset: const Offset(0, 0),
                      blurRadius: 10,
                    ),
                    const Shadow(
                      color: Colors.black54,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      this.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Color(0xFF415A77).withValues(alpha: 0.9),
                            offset: const Offset(0, 0),
                            blurRadius: 12,
                          ),
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(2, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        this.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
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
    );
  }
}
