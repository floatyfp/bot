import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:bot/services/permission_service.dart';
import 'package:bot/models/permission_level.dart';

// Check admin permissions and update username if needed
Future<bool> cmdPermissionCheck(
    ChatContext context, PermissionLevel requiredLevel) async {
  final permissionService = PermissionService();

  // First update the username if needed
  final userId = context.user.id.toString();
  final username = '${context.user.username}';
  permissionService.updateUsernameIfNeeded(userId, username);

  // Then check permissions
  if (!permissionService.hasPermission(requiredLevel, context.user)) {
    await context.respond(
      level: ResponseLevel(
        hideInteraction: true,
        isDm: false,
        mention: true,
        preserveComponentMessages: false,
      ),
      MessageBuilder(embeds: [
        EmbedBuilder(
            title: '403 Forbidden',
            description: 'You do not have permission to use this command.',
            image:
                EmbedImageBuilder(url: Uri.parse('https://http.cat/403.jpg')),
            color: DiscordColor(0xFF0000),
            author: EmbedAuthorBuilder(
                name: (await context.user.fetch()).username,
                iconUrl: (await context.user.fetch()).avatar.url),
            footer: EmbedFooterBuilder(
                text: (await context.client.user.fetch()).username,
                iconUrl: (await context.client.user.fetch()).avatar.url),
            timestamp: DateTime.now())
      ]),
    );
    return false;
  }
  return true;
}
