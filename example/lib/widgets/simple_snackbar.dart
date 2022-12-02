import 'package:flutter/material.dart';

SnackBar buildSimpleSnackbar(String message) {
  return SnackBar(
    content: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Text(
        message,
        style: TextStyle(fontSize: 17),
      ),
    ),
    padding: EdgeInsets.symmetric(horizontal: 20),
  );
}
