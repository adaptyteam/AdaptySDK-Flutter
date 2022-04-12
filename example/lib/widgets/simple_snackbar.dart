import 'package:flutter/material.dart';

SnackBar buildSimpleSnackbar(String message) {
  return SnackBar(
    content: Text(
      message,
      style: const TextStyle(fontSize: 17),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20),
  );
}
