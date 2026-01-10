import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final int index;
  final double size;
  final bool showBorder;

  const AvatarWidget({
    super.key,
    required this.index,
    this.size = 64,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    // Files are named 5260_01.png to 5260_16.png
    // Index is 0 to 15
    final String avatarPath = 'assets/avatars/5260_${(index + 1).toString().padLeft(2, '0')}.png';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: Colors.white.withOpacity(0.2), width: 2) : null,
      ),
      child: ClipOval(
        child: Image.asset(
          avatarPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, size: size * 0.6, color: Colors.white);
          },
        ),
      ),
    );
  }
}
