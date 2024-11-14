import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adapty_flutter/adapty_flutter.dart';

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

class ListProductTile extends StatelessWidget {
  final AdaptyPaywallProduct product;
  final void Function()? onTap;
  const ListProductTile({Key? key, required this.product, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: CupertinoFormRow(
        prefix: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.localizedTitle,
                style: theme.actionTextStyle,
              ),
              Row(
                children: [
                  Text(
                    "Offer:",
                    style: theme.textStyle.copyWith(color: CupertinoColors.systemGrey2),
                  ),
                  const SizedBox(width: 10),
                  if (product.subscription?.offer != null)
                    Text(
                      product.subscription!.offer!.phases.map((e) => e.paymentMode).join(', '),
                      style: theme.textStyle.copyWith(color: CupertinoColors.systemGrey2),
                    ),
                  if (product.subscription?.offer == null)
                    Text(
                      'No offer',
                      style: theme.textStyle.copyWith(color: CupertinoColors.systemGrey2),
                    ),
                ],
              ),
            ],
          ),
        ),
        // helper: Text(title),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
          child: Text(
            product.price.localizedString ?? 'null',
            textAlign: TextAlign.right,
            style: theme.textStyle.copyWith(color: CupertinoColors.systemGrey2),
          ),
        ),
      ),
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

  final bool showProgress;

  final bool isActive;
  final void Function() onTap;

  const ListActionTile({
    Key? key,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.showProgress = false,
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
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textStyle.copyWith(color: CupertinoColors.systemGrey2),
            ),
          if (showProgress) const CupertinoActivityIndicator(),
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
