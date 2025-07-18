import 'package:flutter/foundation.dart';

@immutable
class CodeBlockState {
  final bool isCollapsed;
  final bool isCopied;

  const CodeBlockState({
    this.isCollapsed = false,
    this.isCopied = false,
  });


  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CodeBlockState &&
        other.isCollapsed == isCollapsed &&
        other.isCopied == isCopied;
  }

  @override
  int get hashCode => isCollapsed.hashCode ^ isCopied.hashCode;
}
