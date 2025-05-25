import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:bot/services/cmd_permission_check_service.dart';
import 'package:bot/models/permission_level.dart';

final ChatCommand ping = ChatCommand(
  'ping',
  'Checks the bot\'s latency',
  (ChatContext context) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.user)) return;
    final latency = context.client.gateway.latency;

    await context.respond(
      level: ResponseLevel(
          hideInteraction: false,
          isDm: false,
          mention: true,
          preserveComponentMessages: false),
      MessageBuilder(embeds: [
        EmbedBuilder(
            title: '🏓 Pong!',
            description: 'Latency: ${latency.inMilliseconds}ms',
            color: DiscordColor(0x00FF00),
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
