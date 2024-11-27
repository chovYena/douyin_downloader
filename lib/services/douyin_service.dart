import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import '../utils/logger_util.dart';

class DouyinService {
  static void _log(String message, Function(String) logCallback) {
    Log.i(message);
    logCallback(message);
  }

  static Future<VideoInfo> parseShareLink(String shareText, {Function(String)? onLog}) async {
    onLog ??= (String _) {};
    
    _log('开始解析分享文本: $shareText', onLog);

    // 1. 从分享文本中提取短链接
    final urlRegex = RegExp(r'http[s]?://v\.douyin\.com/\S+/');
    final urlMatch = urlRegex.firstMatch(shareText);
    if (urlMatch == null) {
      _log('未找到链接，尝试其他格式...', onLog);
      final secondRegex = RegExp(r'v\.douyin\.com/\S+/');
      final secondMatch = secondRegex.firstMatch(shareText);
      if (secondMatch == null) {
        throw Exception('无法从分享文本中找到链接');
      }
      return parseShareLink('https://' + secondMatch.group(0)!, onLog: onLog);
    }
    
    final shortUrl = urlMatch.group(0)!;
    _log('提取到的短链接: $shortUrl', onLog);

    try {
      // 2. 创建client
      final client = http.Client();
      
      // 3. 获取第一次重定向的地址
      final request = http.Request('GET', Uri.parse(shortUrl))
        ..followRedirects = false  // 不自动跟随重定向
        ..headers.addAll({
          'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Mobile Safari/537.36',
        });

      final streamedResponse = await client.send(request);
      
      // 获取重定向地址
      final location = streamedResponse.headers['location'];
      if (location == null) {
        throw Exception('无法获取重定向地址');
      }
      
      _log('获取到重定向地址: $location', onLog);

      // 直接请求重定向后的地址
      final pageResponse = await client.get(
        Uri.parse(location),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Mobile Safari/537.36',
        },
      );

      final responseData = pageResponse.body;
      Log.d('响应内容长度: ${responseData.length}');
      Log.d('完整响应内容:');
      Log.d(responseData);

      String? jsonData;
      
      // 使用正则表达式匹配 window._ROUTER_DATA = 和 </script> 之间的内容
      final regex = RegExp(r'window\._ROUTER_DATA = (.*?)</script>', dotAll: true);
      final match = regex.firstMatch(responseData);

      if (match != null) {
        jsonData = match.group(1);
        _log('提取到的JSON数据: $jsonData', onLog);
      } else {
        _log('未找到JSON数据', onLog);
        throw Exception('无法找到视频数据');
      }

      // 5. 解析JSON数据
      final data = json.decode(jsonData!);
      _log('解析后的数据结构: ${data.toString()}', onLog);

      // 6. 从数据中提取视频信息
      final loaderData = data['loaderData'];
      if (loaderData == null) {
        throw Exception('无法找到loaderData数据');
      }

      // 查找 video_(id)/page 格式的key
      String? videoPageKey;
      for (var key in loaderData.keys) {
        if (key.toString().startsWith('video_') && key.toString().endsWith('/page')) {
          videoPageKey = key;
          break;
        }
      }

      if (videoPageKey == null) {
        throw Exception('无法找到video page数据');
      }

      final videoPage = loaderData[videoPageKey];
      if (videoPage == null) {
        throw Exception('无法找到video page数据');
      }

      final videoInfoRes = videoPage['videoInfoRes'];
      if (videoInfoRes == null) {
        throw Exception('无法找到videoInfoRes数据');
      }

      final itemList = videoInfoRes['item_list'];
      if (itemList == null || itemList.isEmpty) {
        throw Exception('无法找到item_list数据');
      }

      final firstItem = itemList[0];
      if (firstItem == null) {
        throw Exception('无法找到视频数据');
      }

      final video = firstItem['video'];
      if (video == null) {
        throw Exception('无法找到video数据');
      }

      final playAddr = video['play_addr'];
      if (playAddr == null) {
        throw Exception('无法找到play_addr数据');
      }

      final videoUri = playAddr['uri'];
      if (videoUri == null) {
        throw Exception('无法找到uri数据');
      }

      _log('提取到的视频URI: $videoUri', onLog);

      // 7. 构建最终视频地址并获取重定向链接
      final videoUrl = 'https://www.douyin.com/aweme/v1/play/?ratio=4k&video_id=$videoUri';
      final finalRequest = http.Request('GET', Uri.parse(videoUrl))
        ..followRedirects = false  // 不自动跟随重定向
        ..headers.addAll({
          'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Mobile Safari/537.36',
        });

      final finalStreamedResponse = await client.send(finalRequest);

      // 获取第一次重定向的地址作为真实视频地址
      final realVideoUrl = finalStreamedResponse.headers['location'];
      if (realVideoUrl == null) {
        throw Exception('无法获取视频真实地址');
      }

      _log('获取到最终视频地址: $realVideoUrl', onLog);

      // 8. 提取视频信息
      try {
        return VideoInfo(
          title: firstItem['desc'] ?? '',
          author: firstItem['author']?['nickname'] ?? '',
          coverUrl: video['cover']?['url_list']?[0] ?? '',
          videoUrl: realVideoUrl,
          duration: 0,
        );
      } catch (e) {
        _log('提取视频信息时出错: $e', onLog);
        throw Exception('提取视频信息失败');
      } finally {
        client.close();  // 记得关闭client
      }

    } catch (e, stackTrace) {
      _log('解析过程出错: $e', onLog);
      _log('错误堆栈: $stackTrace', onLog);
      throw Exception('解析失败: $e');
    }
  }
}

// 添加用于字符串截取的辅助函数
int min(int a, int b) {
  return a < b ? a : b;
}

class VideoInfo {
  final String title;
  final String author;
  final String coverUrl;
  final String videoUrl;
  final int duration;

  VideoInfo({
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.videoUrl,
    required this.duration,
  });
} 