import 'dart:io';

import 'package:duvet/duvet.dart' as duvet;
import 'package:duvet/models/types.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: dart bin/duvet.dart <password>');
    exit(1);
  }

  // 1. Create the manager
  final manager = duvet.GatewayManager.withDefaultApi();

  // 2. Sign in
  final signIn = await manager.api.logIn('me+test@yuzucchii.xyz', arguments[0]);
  print('Logged in with token: ${signIn.token}');

  // 3. Connect
  await manager.connectAll();
  print('Listening for gateway events...');

  // 4. wait for ready
  final GatewayReadyData(:user) = await manager.ready;
  print('Logged in as ${user.username} (${user.id})');
}
