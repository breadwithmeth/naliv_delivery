import 'dart:ui';
import 'package:flutter/cupertino.dart';

class LoadingScrenn extends StatelessWidget {
  const LoadingScrenn({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.black.withOpacity(0.4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(
                  radius: 16,
                ),
                const SizedBox(height: 16),
                Text(
                  'Загрузка...',
                  style: TextStyle(
                    color: CupertinoColors.label,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
