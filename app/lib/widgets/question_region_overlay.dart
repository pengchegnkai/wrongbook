/// widgets/question_region_overlay.dart —— 图片分区叠加层（题目/作答框选显示）
import 'package:flutter/material.dart';

class QuestionRegionOverlay extends StatelessWidget {
  final Widget image;
  final List<RegionBox> regions;

  const QuestionRegionOverlay({super.key, required this.image, required this.regions});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        ...regions.map((r) => Positioned(
          left: r.rect.left, top: r.rect.top,
          width: r.rect.width, height: r.rect.height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: r.color, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(alignment: Alignment.topLeft, child: Container(
              color: r.color.withValues(alpha: 0.8),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(r.label, style: const TextStyle(color: Colors.white, fontSize: 10)),
            )),
          ),
        )),
      ],
    );
  }
}

class RegionBox {
  final Rect rect;
  final String label;
  final Color color;
  const RegionBox({required this.rect, required this.label, this.color = Colors.orange});
}
