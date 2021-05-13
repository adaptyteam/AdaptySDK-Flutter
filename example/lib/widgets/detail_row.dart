import 'package:flutter/material.dart';

class DetailRow extends StatefulWidget {
  final String title;
  final String value;
  DetailRow({required this.title, required this.value});

  @override
  _DetailRowState createState() => _DetailRowState();
}

class _DetailRowState extends State<DetailRow> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ListTile(
      title: Text(widget.title),
      trailing: SizedBox(
          width: width / 2,
          child: Text(
            widget.value,
            textAlign: TextAlign.right,
          )),
      visualDensity: VisualDensity.compact.copyWith(vertical: -4),
    );
  }
}
