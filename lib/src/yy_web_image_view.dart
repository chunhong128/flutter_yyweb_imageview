import 'yyweb_image_provider.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'yyweb_image_cancellation.dart';
import 'dart:async';


typedef DWImageDownloadProgress = void Function(int loadedBytes, int totalBytes);
typedef DWImageBeforeCacheCallback = Future<Uint8List> Function(Uint8List bytes);
typedef DWImageFinshCallback = void Function(ImageInfo imageInfo, Error error);

class YYWebImageView extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final double scale;
  final Widget placeHolder;
  final Widget errorWidget;
  final Color backgroundColor;
  final DWImageDownloadProgress progressCallback;
  final DWImageBeforeCacheCallback beforeCache;
  final DWImageFinshCallback finishCallback;
  final YYWebImageCancellation cancellation;

  YYWebImageView(
    this.url, {
      this.width,
      this.height,
      this.fit = BoxFit.contain,
      this.scale = 1.0, 
      this.backgroundColor,
      this.finishCallback, 
      this.progressCallback, 
      this.beforeCache, 
      this.cancellation,
      this.placeHolder,
      this.errorWidget,
      });
  @override
  State<StatefulWidget> createState() {
    return _YYWebImageViewState();
  }
}

class _YYWebImageViewState extends State<YYWebImageView> {
  ImageInfo _imageInfo;
  ImageStream _imageStream;
  YYWebImageProvider _provider;
  bool hasErrorOccur = false;
  bool hasCallFinishCb = false;
  Completer _cancelLoader;
  double downloadProgress = 0.0;

  @override
    void initState() {
      _provider = YYWebImageProvider(url: widget.url, scale: widget.scale);
      if (widget.cancellation != null) {
        _cancelLoader = Completer();
        _cancelLoader.future.then((value){
          cancelLoad();
        });
        widget.cancellation.addCompleter(_cancelLoader);
      }
      super.initState();
    }

  @override
    void dispose() {
      cancelLoad();
      if (widget.cancellation != null && _cancelLoader != null) {
        widget.cancellation.removeCompleter(_cancelLoader);
      }
      super.dispose();
    }

  @override
    void didChangeDependencies() {
      if (_imageInfo == null && widget.url != null) {
        _loadImage();
      }
      super.didChangeDependencies();
    }

  @override
    void didUpdateWidget(YYWebImageView oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (widget.url != oldWidget.url && widget.scale != oldWidget.scale) {
        _loadImage();
      }
    }

  @override
    void reassemble() {
      // print('======= reassemble ' + widget.url);
      super.reassemble();
      _loadImage();
    }

  void _loadImage() {
    hasErrorOccur = false;
    final ImageStream oldImageStream = _imageStream;
    _imageStream = _provider.resolve(createLocalImageConfiguration(context));
    if (_imageStream.key != oldImageStream?.key) {
      final ImageStreamListener listener = ImageStreamListener(_onImage, onChunk: _onChunk, onError: _onError);
      oldImageStream?.removeListener(listener);
      _imageStream.addListener(listener);
    }
  }

  void _onImage(ImageInfo image, bool synchronousCall) {
    setState(() {
          _imageInfo = image;
          downloadProgress = 1.0;
        });
    if (!hasCallFinishCb && widget.finishCallback != null) {
      hasCallFinishCb = true;
      widget.finishCallback(image, null);
    }
  }

  void _onChunk(ImageChunkEvent event) {
    if (widget.progressCallback != null) {
      widget.progressCallback(event.cumulativeBytesLoaded, event.expectedTotalBytes);
    }
    downloadProgress = event.cumulativeBytesLoaded / event.expectedTotalBytes;
    // print('YYWebImageView ===== progress:${ event.cumulativeBytesLoaded/event.expectedTotalBytes}');
  }

  void _onError(dynamic exception, StackTrace stackTrace) {
    setState(() {
          hasErrorOccur = true;
        });
    if (!hasCallFinishCb && widget.finishCallback != null) {
      hasCallFinishCb = true;
      widget.finishCallback(null, exception);
    }
    print('YYWebImageView loadImage ${widget.url} error: $exception');
    print('YYWebImageView loadImage ${widget.url} error: $stackTrace');
  }

  void cancelLoad() {
    // print('YYWebImageView cancelLoad: ' + widget.url);
    if (_imageStream != null) {
      final ImageStreamListener listener = ImageStreamListener(_onImage, onChunk: _onChunk, onError: _onError);
      _imageStream.removeListener(listener);
      _imageStream = null;
    }
  }

  @override
    Widget build(BuildContext context) {
      Widget currentWidget;
      if (_imageInfo != null) {
        currentWidget = RawImage(
          image: _imageInfo.image,
          scale: _imageInfo.scale ?? 1.0,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        );
        if (widget.backgroundColor != null) {
          return DecoratedBox(
            decoration: BoxDecoration(color: widget.backgroundColor),
            child: currentWidget,
          );
        }
        return currentWidget;
      }
      if (hasErrorOccur) {
        if (widget.errorWidget != null) {
          currentWidget = widget.errorWidget;
        } else {
          currentWidget = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.error_outline),
              Text('加载失败', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center,)
            ],
          );
        }
      } else if (widget.placeHolder != null) {
        currentWidget = widget.placeHolder;
      } else {
        currentWidget = CircularProgressIndicator(
          value: downloadProgress,
          backgroundColor: Colors.transparent,
        );
      }
      if (widget.width != null && widget.height != null) {
          currentWidget = Container (
            width: widget.width,
            height: widget.height,
            child: Align(
              alignment: Alignment.center,
              child: currentWidget,
            ),
            color: widget.backgroundColor,
          ); 
        }
      return currentWidget;
    }
}

