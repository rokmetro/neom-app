import 'package:flutter/cupertino.dart';

class MessagesDirectoryPanel extends StatefulWidget {
  final bool? unread;
  final void Function()? onTapBanner;
  MessagesDirectoryPanel({Key? key, this.unread, this.onTapBanner}) : super(key: key);

  _MessagesDirectoryPanelState createState() => _MessagesDirectoryPanelState();
}

class _MessagesDirectoryPanelState extends State<MessagesDirectoryPanel> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container();
  }
}