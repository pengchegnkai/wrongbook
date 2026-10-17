/// widgets/modern_card.dart —— 通用现代卡片与毛玻璃容器
/// 统一视觉：16 圆角 + 微阴影 + 表面色阶（配合主题层 cardTheme 的扁平卡片）。
import 'dart:ui';
import 'package:flutter/material.dart';

class ModernCard extends StatelessWidget {
  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 10),
    this.color,
    this.elevation = 1.5,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Card(
      color: color ?? scheme.surfaceContainerLowest,
      elevation: elevation,
      shadowColor: scheme.shadow.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      margin: margin,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

/// 毛玻璃容器：BackdropFilter 模糊 + 半透明表面色。
/// 性能注意（骁龙 845）：blurSigma ≤ 12，只用于 AppBar/底部导航等
/// 固定小面积区域，不要整页包裹，否则滚动掉帧。
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.opacity = 0.78,
    this.blurSigma = 10,
  });

  final Widget child;
  final double opacity;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          color: scheme.surface.withValues(alpha: opacity),
          child: child,
        ),
      ),
    );
  }
}
