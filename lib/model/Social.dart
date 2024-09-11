import 'package:rokwire_plugin/utils/utils.dart';

//TODO: make updates according to Social BB development as needed (just text messages for now)
class Message {
  final String id;
  final String content;
  final bool user;

  Message({this.id = '', required this.content, required this.user});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: JsonUtils.stringValue(json['id'])?.trim() ?? '',
      content: JsonUtils.stringValue(json['content'])?.trim() ?? '',
      user: JsonUtils.boolValue(json['user']) ?? false,
    );
  }
}