import 'dart:convert';
import 'dart:developer';

import 'package:web/web.dart' as web;

/// The public view `eventPageHtml` embedded as `#cp-event` when it is for
/// [slug], read once: the element goes, so a retry or a later visit asks
/// the server again. Null when the page has none, or for another event.
Map<String, dynamic>? takeEmbeddedEvent(String slug) {
  final element = web.document.getElementById('cp-event');
  if (element == null) return null;
  element.remove();
  try {
    final data = jsonDecode(element.textContent ?? '');
    if (data is! Map<String, dynamic>) return null;
    final embeddedSlug = data['slug'];
    if (embeddedSlug is! String || embeddedSlug.toLowerCase() != slug) {
      return null;
    }
    return data;
  } catch (e, st) {
    log('Unreadable #cp-event', error: e, stackTrace: st, name: 'eventPage');
    return null;
  }
}
