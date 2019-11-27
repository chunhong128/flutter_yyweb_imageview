import 'dart:async';

class YYWebImageCancellation {
  List<Completer> _completers = List<Completer>();
  bool hasCanceled = false;

  void reset() {
    hasCanceled = false;
  }

  void addCompleter(Completer completer) {
    if (hasCanceled) {
      completer.complete();
      return;
    }
    if (!_completers.contains(completer)) {
      _completers.add(completer);
    }
  }

  void removeCompleter(Completer completer) {
    _completers.remove(completer);
  }

  void execute() {
    hasCanceled = true;
    if (_completers.isNotEmpty) {
      _completers.forEach((e) => e.complete());
    }
  }
  
}