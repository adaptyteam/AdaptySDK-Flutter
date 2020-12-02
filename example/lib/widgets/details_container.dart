import 'package:adapty_flutter_example/widgets/detail_row.dart';
import 'package:flutter/material.dart';

class DetailsContainer extends StatelessWidget {
  final Map<String, String> details;
  final Widget bottomWidget;
  final Map<String, VoidCallback> detailPages;
  DetailsContainer({this.details, this.bottomWidget, this.detailPages});

  @override
  Widget build(BuildContext context) {
    final detailsKeys = details?.keys;
    final detailPagesKeys = detailPages?.keys;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (details != null)
            ...detailsKeys.map((key) {
              return DetailRow(
                title: key,
                value: details[key],
              );
            }).toList(),
          if (detailPages != null)
            ...detailPagesKeys.map((key) {
              return ListTile(
                title: Text(key),
                trailing: Icon(Icons.arrow_forward_ios_outlined, color: Colors.blueAccent),
                visualDensity: VisualDensity.compact.copyWith(vertical: -4),
                onTap: detailPages[key],
              );
            }).toList(),
          if (bottomWidget != null) SizedBox(height: 4),
          if (bottomWidget != null) bottomWidget,
        ],
      ),
    );
  }
}
