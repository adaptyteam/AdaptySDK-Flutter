import 'package:flutter/material.dart';

class ListSection extends StatelessWidget {
  final String? headerText;
  final String? footerText;
  final List<Widget> children;

  const ListSection({Key? key, this.headerText, this.footerText, this.children = const <Widget>[]}) : super(key: key);

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: Colors.black45),
      ),
    );
  }

  Widget _sectionFooter(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 4.0),
      child: Text(
        title,
        style: TextStyle(color: Colors.black45),
      ),
    );
  }

  Widget _separator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Divider(height: 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    var childrenWithSeparators = <Widget>[];

    for (var i = 0; i < this.children.length; i++) {
      childrenWithSeparators.add(this.children[i]);
      if (i < this.children.length - 1) {
        childrenWithSeparators.add(_separator());
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (this.headerText != null) _sectionHeader(this.headerText!),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
                color: Colors.white,
              ),
              child: Column(
                children: childrenWithSeparators,
              ),
            ),
          ),
          if (this.footerText != null) _sectionFooter(this.footerText!),
        ],
      ),
    );
  }
}

class ListTextTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? titleColor;

  final void Function()? onTap;

  const ListTextTile({Key? key, required this.title, this.subtitle, this.titleColor, this.onTap}) : super(key: key);

  Widget _tileText(String title, {Color? color}) {
    return Text(
      title,
      style: TextStyle(color: color ?? Colors.black87),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          _tileText(title, color: titleColor),
          Spacer(),
          if (this.subtitle != null) _tileText(this.subtitle!),
        ],
      ),
    );

    return this.onTap != null
        ? GestureDetector(
            child: child,
            onTap: onTap!,
          )
        : child;
  }
}
