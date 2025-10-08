import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class SlideUpPopupRoute extends PopupRoute {
  final Offset position;
  final Size buttonSize;
  final ThemeData theme;
  final VoidCallback onLocalModels;
  final VoidCallback onAgentMemory;

  SlideUpPopupRoute({
    required this.position,
    required this.buttonSize,
    required this.theme,
    required this.onLocalModels,
    required this.onAgentMemory,
  });

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => Duration(milliseconds: 250);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Positioned(
            left: position.dx,
            bottom: MediaQuery.of(context).size.height - position.dy + 10,
            child: GestureDetector(
              onTap: () {}, // Prevent dismissal when tapping menu
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 1),
                  end: Offset(0, 0),
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(
                  opacity: animation,
                  child: Material(
                    elevation: 8,
                    color: theme.colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                onLocalModels();
                              },
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                child: Row(
                                  children: [
                                    Icon(Iconsax.cpu,
                                        size: 20,
                                        color: theme.colorScheme.primary),
                                    SizedBox(width: 12),
                                    Text('Local Models',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Nunito')),
                                  ],
                                ),
                              ),
                            ),
                            Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.2)),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                onAgentMemory();
                              },
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                child: Row(
                                  children: [
                                    Icon(Iconsax.archive_book,
                                        size: 20,
                                        color: theme.colorScheme.primary),
                                    SizedBox(width: 12),
                                    Text('Agent Memory',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Nunito')),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
