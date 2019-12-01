import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart' as crypto;


enum LocalFilePath {
  documets,
  tmp,
}

const int kCachePolicyNonMemory = 1 << 1;
const int kCachePolicyMemory = 1 << 2;
const int kCachePolicyNonDisk = 1 << 3;
const int kCachePolicyDisk = 1 << 4;
const String kImageDicrectory = '/DWImages';
typedef ProgressCallback = void Function(String url, int didLoad, int total);

class YYWebImageCacheManager {
  static YYWebImageCacheManager get instance {
    if (_instance == null) {
      _instance = YYWebImageCacheManager();
    }
    return _instance;
  }
  static YYWebImageCacheManager _instance;
  List<VoidCallback> listeners;
  Directory defaultSavePath; 
 
  static String fileNameForUrl(String url) {
    crypto.Digest digest = crypto.md5.convert(utf8.encode(url));
    String result = digest.toString();
    return result;
    // if (url != null && url.length > 0) {
    //   var urlBytes = utf8.encode(url);
    //   String encodedUrl = base64Encode(urlBytes);
    //   encodedUrl.replaceAll(RegExp(r'/'), '_');
    //   return encodedUrl;
    // }
    // return url;
  }

  static Future<Directory> makeDirectory(Directory parentDir, String subDir) async {
    if (parentDir != null && subDir != null) {
      try {
        Directory result = Directory(parentDir.path + subDir);
        bool isExist = await result.exists();
        if (isExist) return result;
        Directory dir = await result.create(recursive: true);
        return dir;
      } catch (e) {
        print('exp occur when makeDirectory $e');
      }
    }
    return Future.value(null);
  }

  static Future<Directory> getDirectory(LocalFilePath path) async {
    switch (path) {
      case LocalFilePath.documets:
        return getApplicationDocumentsDirectory();
      case LocalFilePath.tmp:
        return getTemporaryDirectory();
      default:
        return Future.value(null);
    }
  }

  Future<bool> setImagesDefaultSavePathType(LocalFilePath path) async {
    switch (path) {
      case LocalFilePath.documets:
        return setImagesDefaultSavePath(await getApplicationDocumentsDirectory());
      case LocalFilePath.tmp:
        return setImagesDefaultSavePath(await getTemporaryDirectory());
      default:
        break;
    }
    return setImagesDefaultSavePath(await getTemporaryDirectory());
  }
  
  Future<bool> setImagesDefaultSavePath(Directory path) async {
    if (path != null) {
      Directory defaultDir = await makeDirectory(path, kImageDicrectory);
      if (defaultDir != null) {
        defaultSavePath = defaultDir;
        return true;
      }
    }
    return Future.value(false);
  }

  Future<File> getFile(String fileName, {Directory directory}) async {
    if (fileName.length == 0) {
      return null;
    }
    if (directory == null) {
      if (defaultSavePath == null) {
        await setImagesDefaultSavePathType(LocalFilePath.tmp);
      }
      directory = defaultSavePath;
    }
    return File(directory.path + '/' + fileName);
  }

  Future<bool> saveFileToDisk(List<int> bytes, String fileName, {Directory directory}) async {
    try {
      File file = await getFile(fileName, directory: directory);
      file.writeAsBytes(bytes);
      return true;
    } catch(e) {
      print('exp occour when yyweb_imageview saveFileToDisk $e');
    }
    return false;
  }

  Future<Uint8List> loadFileFromDisk(String fileName, {Directory directory}) async {
    try {
      File file = await getFile(fileName, directory: directory);
      bool exist = await file.exists();
      if (exist) {
        return file.readAsBytesSync();
      } else {
        return null;
      }
    } catch (e) {
      print('exp occour when yyweb_imageview loadFileFromDisk $e');
      return null;
    }
  }

  Future<bool> clearDiskCacheeImage() async {
    if (defaultSavePath == null) {
      return Future.value(true);
    }
    FileSystemEntity entity = await defaultSavePath.delete(recursive: true);
    if (entity != null) {
      return true;
    }
    return false;
  }

  void clearMemoryCachedImage() {
    PaintingBinding.instance.imageCache.clear();
  }

  
  void downloadAndCacheImages(List<String> urls, {
    double timeout, 
    Map<String, String> headers, 
    int tryTimes = 1, 
    ProgressCallback progress, 
    int cachePolicy = (kCachePolicyDisk | kCachePolicyNonMemory),
    }) async {
    if (urls != null) {
      urls.forEach((String urlString) async {
        // print('download start ' + urlString);
        await downloadImage(urlString, tryTimes: tryTimes, headers: headers, timeout: timeout, progress: progress, cachePolicy: cachePolicy);
        // print('download end ' + urlString);
      });
    }
  }
  
  Future<Uint8List> downloadImage(String url, {
    Map<String, String> headers, 
    int tryTimes = 1, 
    double timeout = 30, 
    ProgressCallback progress,
    bool checkCacheFirst = true,
    int cachePolicy = kCachePolicyDisk,
    }) async {
      if (checkCacheFirst) {
        final md5Url = fileNameForUrl(url);
        Uint8List bytes = await loadFileFromDisk(md5Url);
        if (bytes != null && bytes.length > 0) {
          return bytes;
        }
      }
      Uint8List bytes = await _tryDownloadWithUrl(url, tryTimes, headers: headers, timeout: timeout, progress: progress);
      if (cachePolicy & kCachePolicyMemory > 0) {
        final codecResult = PaintingBinding.instance.instantiateImageCodec(bytes);
        final loader = MultiFrameImageStreamCompleter(
          codec: Future.value(codecResult),
          scale: 1.0, 
        );
        PaintingBinding.instance.imageCache.putIfAbsent(NetworkImage(url), () => loader);
      }
      if (cachePolicy & kCachePolicyDisk > 0) {
        saveFileToDisk(bytes, fileNameForUrl(url));
      }
      return bytes;
  }

  Future<Uint8List> _tryDownloadWithUrl(String url, int tryCount, {
    Map<String, String> headers, 
    double timeout = 30, 
    ProgressCallback progress,
    }) async {
    bool shouldRetry = false;
    tryCount = tryCount > 0 ? (tryCount - 1) : 0;
    try {
      Uri resolved = Uri.base.resolve(url);
      HttpClient _downloader = HttpClient();
      if (timeout != null && timeout > 0) {
        int seconds = timeout.floor();
        int milliSeconds = ((timeout - seconds) * 1000).toInt();
        _downloader.connectionTimeout = Duration(seconds: seconds, milliseconds: milliSeconds);
      }
      HttpClientRequest request = await _downloader.getUrl(resolved);
      headers?.forEach((String name, String value) {
          request.headers.add(name, value);
        });
      HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
          throw Exception('request image url $resolved failed');
        }
      Uint8List bytes = await consolidateHttpClientResponseBytes(
          response, 
          onBytesReceived: (int cumulative, int total) { 
            if (progress != null) {
              progress(url, cumulative, total);
            }
          },
        );
      if (bytes !=null && bytes.lengthInBytes == 0)
         throw Exception('NetworkImage is an empty file: $resolved');
      _downloader.close();
      _downloader = null;
      return bytes;
    } catch(e) {
      print('exp occur: yyweb_imageview _tryDownloadWithUrl $e');
      shouldRetry = true;
    }
    if (shouldRetry == true && tryCount > 0) {
      print('yyweb_imageview _tryDownloadWithUrl download fail with zero bytes');
      return _tryDownloadWithUrl(url, tryCount, timeout: timeout, headers: headers, progress: progress);
    }
    return null;
  }
}