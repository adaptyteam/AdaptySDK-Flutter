import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get usesCupertino => defaultTargetPlatform == TargetPlatform.iOS;

PageRoute<T> adaptivePageRoute<T>({required WidgetBuilder builder}) {
  if (usesCupertino) {
    return CupertinoPageRoute<T>(builder: builder);
  }

  return MaterialPageRoute<T>(builder: builder);
}

Widget adaptiveActivityIndicator() {
  if (usesCupertino) {
    return const CupertinoActivityIndicator();
  }

  return const CircularProgressIndicator();
}

class AdaptiveActionButton extends StatelessWidget {
  const AdaptiveActionButton({super.key, required this.label, required this.onPressed, this.destructive = false});

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    if (usesCupertino) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(color: destructive ? CupertinoColors.systemRed.resolveFrom(context) : null),
        ),
      );
    }

    return TextButton(onPressed: onPressed, child: Text(label));
  }
}

class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({super.key, required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = usesCupertino
        ? CupertinoColors.systemRed.resolveFrom(context).withAlpha(31)
        : Theme.of(context).colorScheme.errorContainer;
    final foregroundColor = usesCupertino
        ? CupertinoColors.systemRed.resolveFrom(context)
        : Theme.of(context).colorScheme.onErrorContainer;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(message, style: TextStyle(color: foregroundColor)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              usesCupertino ? CupertinoIcons.xmark_circle_fill : Icons.close,
              color: foregroundColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textStyle = usesCupertino
        ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )
        : Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: textStyle),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.title, this.subtitle, this.trailing, this.onTap});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: usesCupertino
                  ? CupertinoTheme.of(context).textTheme.textStyle
                  : Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (subtitle != null)
            Flexible(
              child: Text(
                subtitle!,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: usesCupertino
                      ? CupertinoColors.secondaryLabel.resolveFrom(context)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }

    if (usesCupertino) {
      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
    }

    return InkWell(onTap: onTap, child: row);
  }
}

class GroupedSection extends StatelessWidget {
  const GroupedSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = usesCupertino
        ? CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
        : Theme.of(context).colorScheme.surface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: usesCupertino ? null : Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            children[index],
          ],
        ],
      ),
    );
  }
}
