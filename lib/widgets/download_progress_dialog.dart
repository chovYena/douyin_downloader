import 'package:flutter/material.dart';

class DownloadProgressDialog extends StatefulWidget {
  final String title;
  final Future<void> Function(Function(double)) onDownload;

  const DownloadProgressDialog({
    Key? key,
    required this.title,
    required this.onDownload,
  }) : super(key: key);

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    widget.onDownload((progress) {
      setState(() {
        _progress = progress;
      });
      if (progress >= 1) {
        Navigator.of(context).pop();
      }
    }).catchError((error) {
      Navigator.of(context).pop(error);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                // 外层容器
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                ),
                // 旋转的外圈
                SizedBox(
                  width: 140,
                  height: 140,
                  child: RotationTransition(
                    turns: _controller,
                    child: CircularProgressIndicator(
                      value: null,
                      strokeWidth: 2,
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                ),
                // 进度条
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 8,
                    color: Colors.red,
                    backgroundColor: Colors.red.withOpacity(0.2),
                  ),
                ),
                // 进度文字
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const Text(
                      '下载中',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
} 