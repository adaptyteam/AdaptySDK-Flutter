import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ListSection extends StatelessWidget {
  final String? headerText;
  final String? footerText;
  final List<Widget> children;

  const ListSection({Key? key, this.headerText, this.footerText, this.children = const <Widget>[]}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoFormSection.insetGrouped(
      header: this.headerText != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(headerText!.toUpperCase()),
            )
          : null,
      footer: this.footerText != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(footerText!),
            )
          : null,
      children: children,
    );
  }
}

class ListTextTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? subtitleColor;

  const ListTextTile({Key? key, required this.title, this.subtitle, this.subtitleColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context).textTheme;
    return CupertinoFormRow(
      prefix: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Text(title),
      ),
      // helper: Text(title),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
        child: Text(
          this.subtitle ?? '',
          textAlign: TextAlign.right,
          style: theme.textStyle.copyWith(color: subtitleColor ?? CupertinoColors.systemGrey2),
        ),
      ),
    );
  }
}

class ListActionTile extends StatelessWidget {
  final titleLengthLimit = 30;

  final String title;
  final Color? titleColor;

  final String? subtitle;

  final bool isActive;
  final void Function() onTap;

  const ListActionTile({
    Key? key,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.isActive = true,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context).textTheme;

    return CupertinoButton(
      onPressed: isActive ? onTap : null,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: titleColor != null ? theme.actionTextStyle.copyWith(color: titleColor) : null,
            ),
          ),
          Spacer(),
          if (subtitle != null)
            Expanded(
              child: Text(
                subtitle!,
                textAlign: TextAlign.right,
                style: theme.textStyle.copyWith(
                  color: CupertinoColors.systemGrey2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ListTextFieldTile extends StatelessWidget {
  final String? placeholder;
  final Color? textColor;
  final Color? placeholderColor;

  final void Function(String?)? onChanged;
  final void Function(String?)? onSubmitted;

  const ListTextFieldTile({
    Key? key,
    this.placeholder,
    this.textColor,
    this.placeholderColor,
    this.onChanged,
    this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      placeholder: placeholder,
      placeholderStyle: TextStyle(color: placeholderColor ?? Colors.black26),
      decoration: BoxDecoration(),
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      clearButtonMode: OverlayVisibilityMode.editing,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
