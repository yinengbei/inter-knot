import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

web.EventListener? _pasteEventListener;

void setupPasteListener(
    void Function(String filename, Uint8List bytes, String mimeType)
        onImagePasted) {
  _pasteEventListener = (web.Event event) {
    final e = event as web.ClipboardEvent;
    final items = e.clipboardData?.items;
    if (items == null || items.length == 0) return;

    final length = items.length;
    for (var i = 0; i < length; i++) {
      final item = items[i];
      final mimeType = item.type;

      if (mimeType.startsWith('image/')) {
        e.preventDefault();
        final file = item.getAsFile();
        if (file == null) continue;

        final reader = web.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onloadend = (web.Event _) {
          final result = reader.result;
          if (result != null) {
            final bytes = (result as JSArrayBuffer).toDart.asUint8List();
            onImagePasted(file.name, bytes, mimeType);
          }
        }.toJS;
      }
    }
  }.toJS;
  web.window.addEventListener('paste', _pasteEventListener);
}

void removePasteListener() {
  if (_pasteEventListener != null) {
    web.window.removeEventListener('paste', _pasteEventListener);
    _pasteEventListener = null;
  }
}
