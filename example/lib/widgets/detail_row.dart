import 'package:flutter/material.dart';

class DetailRow extends StatefulWidget {
  final String title;
  final String value;
  DetailRow({@required this.title, this.value});

  @override
  _DetailRowState createState() => _DetailRowState();
}

class _DetailRowState extends State<DetailRow> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return ListTile(
      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
      title: Text(widget.title),
      trailing: SizedBox(
          width: width / 2,
          child: Text(
            widget.value,
            textAlign: TextAlign.right,
          )),
      // contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: -4),
      visualDensity: VisualDensity.compact.copyWith(vertical: -4),

      // children: [
      //   SizedBox(
      //     width: 200,
      //     child: Text(title),
      //   ),
      //   SizedBox(
      //     width: width - 238,
      //     child: Text(value ?? 'null', textAlign: TextAlign.end),
      //   ),
      // ],
    );
  }
}
