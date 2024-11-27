import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../utils/logger_util.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class DownloadUtil {
  static Future<String> downloadVideo(String url, {Function(double)? onProgress}) async {
    // 检查并请求权限
    if (!await _checkPermission()) {
      throw Exception('需要存储权限才能下载视频');
    }

    final client = http.Client();
    try {
      // 1. 创建请求
      final request = http.Request('GET', Uri.parse(url))
        ..followRedirects = false
        ..headers.addAll({
          'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Mobile Safari/537.36',
        });

      // 2. 获取重定向地址
      final streamedResponse = await client.send(request);
      final realUrl = streamedResponse.headers['location'] ?? url;
      
      // 3. 下载视频
      final response = await client.send(http.Request('GET', Uri.parse(realUrl)));
      final contentLength = response.contentLength ?? 0;
      
      // 4. 先下载到临时目录
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.mp4');
      
      try {
        // 5. 分块写入临时文件并报告进度
        final sink = tempFile.openWrite();
        int received = 0;
        
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength > 0 && onProgress != null) {
            onProgress(received / contentLength);
          }
        }
        
        await sink.close();
        
        // 6. 保存到相册
        final result = await ImageGallerySaver.saveFile(
          tempFile.path,
          name: 'douyin_${DateTime.now().millisecondsSinceEpoch}'
        );
        
        // 7. 删除临时文件
        await tempFile.delete();
        
        if (result['isSuccess']) {
          Log.i('视频已保存到相册');
          return '视频已保存到相册';
        } else {
          throw Exception('保存到相册失败');
        }
      } catch (e) {
        Log.e('保存视频失败: $e');
        // 清理临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        throw Exception('保存视频失败');
      }

    } catch (e) {
      Log.e('下载视频失败: $e');
      throw Exception('下载失败: $e');
    } finally {
      client.close();
    }
  }

  // 通知媒体库扫描新文件

  static Future<bool> _checkPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      Log.i('Android SDK Version: $sdkInt');
      
      if (sdkInt >= 33) { // Android 13 及以上
        final videos = await Permission.videos.request();
        Log.i('权限状态: videos=${videos.isGranted}');
        if (!videos.isGranted) {
          // 显示权限说明对话框
          final bool? result = await showDialog<bool>(
            context: navigatorKey.currentContext!,
            builder: (context) => AlertDialog(
              title: const Text('需要存储权限'),
              content: const Text('需要视频存储权限才能保存视频到相册。'),
              actions: [
                TextButton(
                  child: const Text('取消'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('去设置'),
                  onPressed: () async {
                    Navigator.of(context).pop(true);
                    await openAppSettings();
                  },
                ),
              ],
            ),
          );
          return result == true && await Permission.videos.isGranted;
        }
        return true;
      } else { // Android 13 以下
        final storage = await Permission.storage.request();
        Log.i('权限状态: storage=${storage.isGranted}');
        return storage.isGranted;
      }
    }
    return true;
  }
} 