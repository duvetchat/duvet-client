import 'dart:io';

import 'package:duvet_client/gateway/manager.dart';
import 'package:duvet_client/models/types.dart';
import 'package:duvet_client/http/router.dart';
import 'package:duvet_client/http/rest.dart';
import 'package:http/http.dart' as http;

late GatewayUser me;

Future<void> onMessageCreate(RestClient api, GatewayMessage message) async {
  if (message.content != null) defaultLog(0, message.content!);

  if (message.content == "hi") {
    await api.sendMessageWithFiles(message.roomId, List.empty(),
        content: "hello");
  }
}

/// router for my instance
final class MyRouter extends ApiRouter {
  @override
  String get api => "duvet-api.yuzucchii.xyz";

  @override
  String get ws => "duvet-gateway.yuzucchii.xyz";

  @override
  String get base => "duvet.yuzucchii.xyz";

  @override
  String get apiBasePath => '/api';
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    print('Usage: dart bin/duvet.dart <email> <password>');
    exit(1);
  }

  final api = RestClient(http.Client(), router: MyRouter());

  // 1. Sign in
  final signIn = await api.logIn(arguments[0], arguments[1]);
  defaultLog(0, 'Logged in with token: ${signIn.token}');

  // 2. Create the manager
  final manager = GatewayManager(api, log: defaultLog, router: MyRouter());

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
