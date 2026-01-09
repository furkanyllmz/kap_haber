import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TickerLogo extends StatefulWidget {
  final String ticker;
  final double size;
  final double borderRadius;

  const TickerLogo({
    super.key,
    required this.ticker,
    this.size = 50,
    this.borderRadius = 12,
  });

  @override
  State<TickerLogo> createState() => _TickerLogoState();
}

class _TickerLogoState extends State<TickerLogo> {
  // Cache to store whether an asset exists or not to improve performance in lists
  static final Map<String, bool> _assetExistenceCache = {};
  late Future<bool> _existenceFuture;

  @override
  void initState() {
    super.initState();
    _checkAssetExistence();
  }

  @override
  void didUpdateWidget(TickerLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticker != widget.ticker) {
      _checkAssetExistence();
    }
  }

  void _checkAssetExistence() {
    final assetPath = 'assets/logos/${widget.ticker}.svg';
    
    if (_assetExistenceCache.containsKey(assetPath)) {
      _existenceFuture = Future.value(_assetExistenceCache[assetPath]);
    } else {
      _existenceFuture = rootBundle.load(assetPath).then((_) {
        _assetExistenceCache[assetPath] = true;
        return true;
      }).catchError((_) {
        _assetExistenceCache[assetPath] = false;
        return false;
      });
    }
  }

  Color _getTickerColor(String ticker) {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFF44336),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFF795548),
      const Color(0xFF607D8B),
    ];
    return colors[ticker.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<bool>(
        future: _existenceFuture,
        builder: (context, snapshot) {
          final exists = snapshot.data ?? false;

          Widget content;
          if (snapshot.connectionState == ConnectionState.done && exists) {
            content = SvgPicture.asset(
              'assets/logos/${widget.ticker}.svg',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
            );
          } else {
            // Placeholder / Fallback
            content = Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _getTickerColor(widget.ticker).withOpacity(0.15),
              ),
              child: Center(
                child: Text(
                  widget.ticker.length >= 2 ? widget.ticker.substring(0, 2) : widget.ticker,
                  style: TextStyle(
                    color: _getTickerColor(widget.ticker),
                    fontWeight: FontWeight.bold,
                    fontSize: widget.size * 0.4, // Responsive font size
                  ),
                ),
              ),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: content,
          );
        },
      ),
    );
  }
}
