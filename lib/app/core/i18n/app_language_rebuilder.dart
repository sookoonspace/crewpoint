import 'package:flutter/widgets.dart';

/// Rebuilds everything below it when the app's language changes, keeping
/// every screen's state. `context.strings` reads the language without
/// subscribing (so screens may use it from `initState`), and this makes sure
/// they all show the new language anyway (Spec #233 Req 56). Sits in
/// `MaterialApp.router`'s `builder`, inside its `Localizations`.
class AppLanguageRebuilder extends StatefulWidget {
  const AppLanguageRebuilder({
    super.key,
    required this.locale,
    required this.child,
  });

  final Locale locale;
  final Widget child;

  @override
  State<AppLanguageRebuilder> createState() => _AppLanguageRebuilderState();
}

class _AppLanguageRebuilderState extends State<AppLanguageRebuilder> {
  @override
  void didUpdateWidget(AppLanguageRebuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale != widget.locale) {
      void rebuild(Element element) {
        element.markNeedsBuild();
        element.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
