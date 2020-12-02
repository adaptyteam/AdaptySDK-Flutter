import 'package:flutter/material.dart';

SnackBar buildSimpleSnackbar(String message) {
  return SnackBar(
    content: Text(
      message,
      style: TextStyle(fontSize: 17),
    ),
    padding: EdgeInsets.symmetric(horizontal: 20),
  );
}
