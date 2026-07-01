import 'package:flutter/material.dart';

class CustomSnackbar {
  static void show(BuildContext context, SnackBar snackBar) {
    final newSnackBar = SnackBar(
      content: snackBar.content,
      backgroundColor: snackBar.backgroundColor,
      action: snackBar.action,
      duration: snackBar.duration,
      animation: snackBar.animation,
      onVisible: snackBar.onVisible,
      shape: snackBar.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.up,
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height - 150 > 0 ? MediaQuery.of(context).size.height - 150 : 0,
        left: 20,
        right: 20,
      ),
    );
    
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(newSnackBar);
  }
}
