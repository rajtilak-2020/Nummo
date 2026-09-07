import 'dart:js_interop';

@JS('window.scrollTo')
external void _windowScrollTo(num x, num y);

/// Resets the browser viewport scroll offset to (0, 0) on Web to avoid touch coordinate shift on iOS Safari.
void resetWebViewportScroll() {
  try {
    _windowScrollTo(0, 0);
  } catch (_) {}
}
