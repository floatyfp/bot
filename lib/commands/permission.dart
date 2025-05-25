import 'package:bot/services/cmd_permission_check_service.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import '../models/permission_level.dart';
import '../services/permission_service.dart';

final permissionService = PermissionService();

// Command group for all permission-related commands
final permissionGroup = ChatGroup(
  'permission',
  'Manage user permissions',
  children: [
    permissionSetCommand,
    permissionRemoveCommand,
    permissionListCommand,
  ],
);

// Command to set a user's permission level
final permissionSetCommand = ChatCommand(
  'set',
  '[ADMIN] Set a user\'s permission level',
  (ChatContext context, @Name('user') User user,
      @Name('level') String level) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.admin)) return;
    final permissionLevel = PermissionLevelExtension.fromString(level);
    final currentUserLevel =
        permissionService.getUserPermissionLevel(context.user.id.toString());

    // Prevent users from modifying users with equal or higher permissions
    final targetUserLevel =
        permissionService.getUserPermissionLevel(user.id.toString());
    if (targetUserLevel.index >= currentUserLevel.index &&
        currentUserLevel != PermissionLevel.owner) {
      context.respond(
        MessageBuilder(embeds: [
          EmbedBuilder(
              title: 'Error',
              description:
                  'You cannot modify users with equal or higher permissions.',
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
      return;
    }

    // Prevent setting owner permission unless you're already an owner
    if (permissionLevel == PermissionLevel.owner &&
        currentUserLevel != PermissionLevel.owner) {
      context.respond(
        MessageBuilder(embeds: [
          EmbedBuilder(
              title: 'Error',
              description: 'Only owners can assign the owner permission level.',
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
      return;
    }

    permissionService.setUserPermission(
      UserPermission(
        userId: user.id.toString(),
        level: permissionLevel,
        username: user.username,
      ),
    );

    context.respond(
      MessageBuilder(embeds: [
        EmbedBuilder(
            title: 'Updated Permissions',
            description:
                'Updated <@${user.id.toString()}> permissions to **${permissionLevel.name}**',
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

// Command to remove a user's special permissions
final permissionRemoveCommand = ChatCommand(
  'remove',
  '[ADMIN] Remove a user\'s special permissions',
  (ChatContext context, @Name('user') User user) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.admin)) return;
    final currentUserLevel =
        permissionService.getUserPermissionLevel(context.user.id.toString());
    final targetUserLevel =
        permissionService.getUserPermissionLevel(user.id.toString());

    // Prevent users from modifying users with equal or higher permissions
    if (targetUserLevel.index >= currentUserLevel.index &&
        currentUserLevel != PermissionLevel.owner) {
      context.respond(
        MessageBuilder(
          embeds: [
            EmbedBuilder(
                title: 'Error',
                description:
                    'You cannot modify users with equal or higher permissions.',
                color: DiscordColor(0xFF0000),
                author: EmbedAuthorBuilder(
                    name: (await context.user.fetch()).username,
                    iconUrl: (await context.user.fetch()).avatar.url),
                footer: EmbedFooterBuilder(
                    text: (await context.client.user.fetch()).username,
                    iconUrl: (await context.client.user.fetch()).avatar.url),
                timestamp: DateTime.now())
          ],
        ),
      );
      return;
    }

    permissionService.removeUserPermission(user.id.toString());

    context.respond(
      MessageBuilder(embeds: [
        EmbedBuilder(
            title: 'Removed Special Permission',
            description:
                'Removed special permissions from <@${user.id.toString()}>',
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

// Command to list all users with special permissions
final permissionListCommand = ChatCommand(
  'list',
  '[ADMIN] List all users with special permissions',
  (ChatContext context) async {
    // Check permissions
    if (!await cmdPermissionCheck(context, PermissionLevel.admin)) return;
    final permissions = permissionService.getAllPermissions();

    if (permissions.isEmpty) {
      context.respond(
        MessageBuilder(embeds: [
          EmbedBuilder(
              title: 'No users with special permissions found',
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
      return;
    }

    final buffer = StringBuffer('');

    // Group by permission level
    final grouped = <PermissionLevel, List<UserPermission>>{};
    for (final perm in permissions) {
      grouped.putIfAbsent(perm.level, () => []).add(perm);
    }

    // Sort by permission level (highest first)
    final sortedLevels = grouped.keys.toList()
      ..sort((a, b) => b.index.compareTo(a.index));

    for (final level in sortedLevels) {
      final users = grouped[level]!;
      buffer.writeln(
          '**${level.name[0].toUpperCase()}${level.name.substring(1)}** (${users.length}):');
      buffer.writeln(users.map((u) => '• ${u.username}').join('\n'));
      buffer.writeln();
    }

    context.respond(
      MessageBuilder(embeds: [
        EmbedBuilder(
            color: DiscordColor(0x00FF00),
            author: EmbedAuthorBuilder(
                name: (await context.user.fetch()).username,
                iconUrl: (await context.user.fetch()).avatar.url),
            footer: EmbedFooterBuilder(
                text: (await context.client.user.fetch()).username,
                iconUrl: (await context.client.user.fetch()).avatar.url),
            timestamp: DateTime.now(),
            title: 'Permission Levels',
            description: buffer.toString())
      ]),
    );
  },
);
