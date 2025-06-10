import 'dart:io';
import 'package:bot/services/cmd_permission_check_service.dart';
import 'package:bot/models/permission_level.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

/// Chat command to restart the bot process.
final ChatCommand restart = ChatCommand(
  'restart',
  '[ADMIN] Restarts the bot process',
  (ChatContext context) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.admin)) return;
    await context.respond(
      level: ResponseLevel(
        hideInteraction: false,
        isDm: false,
        mention: true,
        preserveComponentMessages: false,
      ),
      MessageBuilder(embeds: [
        EmbedBuilder(
            title: '🔄 Restarting bot...',
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
    // Exit process to allow supervisor to restart
    exit(0);
  },
);
