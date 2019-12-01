import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:core';
import 'dart:ui' as ui show Codec;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'yyweb_image_cache_manager.dart';


class YYWebImageProvider extends ImageProvider <NetworkImage> {
  final String url;
  final double scale;
  final double timeout;  //以秒为单位
  final int tryTimes;
  final Map<String, String> headers;
  HttpClient _downloader;

  YYWebImageProvider({@required this.url, this.scale = 1.0, this.timeout = 30, this.tryTimes = 3, this.headers});

  @override
    ImageStreamCompleter load(NetworkImage key) {
      final StreamController<ImageChunkEvent> chunkEvents = StreamController<ImageChunkEvent>();
      return MultiFrameImageStreamCompleter(
        codec: _loadImgageAsync(key, chunkEvents),
        chunkEvents:  chunkEvents.stream,
        scale: key.scale,
        informationCollector: () sync* {
          yield DiagnosticsProperty<ImageProvider>('Image provider', this);
          yield DiagnosticsProperty<NetworkImage>('Image key', key, defaultValue: null);
        },
      );
    }

  Future<ui.Codec> _loadImgageAsync(NetworkImage key, StreamController<ImageChunkEvent> chunkEvents) async {
    // 先从本地取，本地没有再从网络请求
    String encodedUrl = YYWebImageCacheManager.fileNameForUrl(key.url);
    Uint8List localBytes = await loadImageFromDisk(encodedUrl);
    if (localBytes != null && localBytes.length > 0) {
      return PaintingBinding.instance.instantiateImageCodec(localBytes);
    }
    //下载图片
    // final Uri resolved = Uri.base.resolve(key.url);
    // Uint8List bytes = await _tryDownloadUri(resolved, chunkEvents, this.retryTimes);
    final policy = kCachePolicyMemory | kCachePolicyDisk;
    Uint8List bytes = await YYWebImageCacheManager.instance.downloadImage(key.url, tryTimes: this.tryTimes, cachePolicy: policy, progress: (String url,int didLoad, int total){
      chunkEvents.add(ImageChunkEvent(cumulativeBytesLoaded: didLoad, expectedTotalBytes: total));
    });
    if (bytes != null) {
      // 把图片保存到本地
      saveImageToDisk(bytes, encodedUrl);
      // 对图片数据进行解码
      return PaintingBinding.instance.instantiateImageCodec(bytes);
    }
    return Future.error('download fail url: ${key.url}');
  }

  Future<Uint8List> loadImageFromDisk(String base64Url) async {
    if (base64Url.length == 0) {
      return null;
    }
    return YYWebImageCacheManager.instance.loadFileFromDisk(base64Url);
 }

  Future<void> saveImageToDisk(Uint8List bytes, String base64Url) async {
    if (base64Url.length == 0) {
      return;
    }
    YYWebImageCacheManager.instance.saveFileToDisk(bytes, base64Url);
  }

  // 处理下载和获取缓存的key: 由url和scale来决定是不是同一个
  @override
    Future<NetworkImage> obtainKey(ImageConfiguration configuration) {
      final NetworkImage _image = NetworkImage(this.url, scale: this.scale);
      return SynchronousFuture(_image);
    }

  @override
  int get hashCode => hashValues(url, scale);

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    final YYWebImageProvider typedOther = other;
    return url == typedOther.url && scale == typedOther.scale;
  }

  void cancelDownload() {
    _downloader?.close();
    _downloader = null;
  }

  // cancel & resume
  void cancel() {

  }

  void resume() {
    
  }
}