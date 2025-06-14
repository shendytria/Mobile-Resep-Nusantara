import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  CustomAppBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title:
          Text(title, style:
               TextStyle(color:
                        Colors.black)),
      backgroundColor:
          Colors.white,
      iconTheme:
          IconThemeData(color:
                        Colors.black),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
