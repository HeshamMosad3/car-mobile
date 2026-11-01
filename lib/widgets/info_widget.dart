
import 'package:flutter/material.dart';

class InfoWidget extends StatelessWidget {
  const InfoWidget({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F), // أحمر تنبيه
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // أيقونة التنبيه: محاذاة لسطر النص الأول (ارتفاع السطر 15 × 1.6 = 24)
          // والقرص الأسود خلف الأيقونة يظهر من خلال حرف الـ i الشفاف فيصبح أسود
          SizedBox(
            height: 24,
            width: 30,
            child: OverflowBox(
              maxHeight: 30,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                  ),
                  const Icon(Icons.info, color: Color(0xFFFFD600), size: 30,),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // النص
           Expanded(
            child: Text(text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.6,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
