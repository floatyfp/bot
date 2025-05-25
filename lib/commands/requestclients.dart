import 'package:bot/services/websocket_service.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:intl/intl.dart';
import 'package:bot/services/cmd_permission_check_service.dart';
import 'package:bot/models/permission_level.dart';

final ChatCommand requestClients = ChatCommand(
  'wsclients',
  '[ADMIN] Lists all connected WebSocket clients',
  (ChatContext context) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.admin)) return;
    if (!websocketService.isConnected) {
      await context.respond(
        level: ResponseLevel(
            hideInteraction: false,
            isDm: false,
            mention: true,
            preserveComponentMessages: false),
        MessageBuilder(
            content: 'WebSocket client is not connected', embeds: []),
      );
      return;
    }
    final clients =
        await websocketService.sendRequest({'type': 'list_clients'});

    await context.respond(
      level: ResponseLevel(
          hideInteraction: false,
          isDm: false,
          mention: true,
          preserveComponentMessages: false),
      MessageBuilder(embeds: [
        EmbedBuilder(
            title: 'WebSocket Clients',
            color: DiscordColor(0x00FF00),
            fields: [
              for (final client in clients['clients'])
                EmbedFieldBuilder(
                    name: client['name'],
                    value:
                        '${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(client['connectedTime']))} UTC',
                    isInline: true),
            ],
            author: EmbedAuthorBuilder(
                name: (await context.user.fetch()).username,
                iconUrl: (await context.user.fetch()).avatar.url),
            footer: EmbedFooterBuilder(
                text: (await context.client.user.fetch()).username,
                iconUrl: (await context.client.user.fetch()).avatar.url),
            timestamp: DateTime.now())
      ]),
    );
  },
);
