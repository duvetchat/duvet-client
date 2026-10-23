import 'dart:io';

import 'package:duvet_client/gateway/manager.dart';
import 'package:duvet_client/models/types.dart';
import 'package:duvet_client/http/rest.dart';
import 'package:http/http.dart' as http;

late GatewayUser me;

Future<void> onMessageCreate(RestClient api, GatewayMessage message) async {
  if (message.content != null) defaultLog(0, message.content!);

  if (message.content == "hi") {
    await api.sendMessage(message.roomId, "hello");
  }
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    print('Usage: dart run example/duvet_example.dart <email> <password>');
    exit(1);
  }

  final api = RestClient(http.Client());

  // 1. Sign in. The tokens are secrets: don't print them.
  await api.logIn(arguments[0], arguments[1]);
  defaultLog(0, 'Logged in');

  // 2. Create the manager
  final manager = GatewayManager(api, log: defaultLog);

  // 3. Connect
  await manager.connectAll();
  defaultLog(0, 'Listening for gateway events...');

  // 4. wait for ready
  final GatewayReadyData(:user) = await manager.ready;
  me = user;
  defaultLog(0, 'Logged in as ${me.username} (${me.id})');

  manager.onMessageCreate.listen((MessageCreateEvent msg) {
    onMessageCreate(api, msg.data);
  });
}
