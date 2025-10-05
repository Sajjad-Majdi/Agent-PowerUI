import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ToolsMenu extends StatelessWidget {
  final List<Map<String, dynamic>> tools;
  final bool isLoading;

  const ToolsMenu({
    Key? key,
    required this.tools,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final toolboxWidth = screenWidth < 600 ? screenWidth * 0.7 : 400.0;

    return Container(
      width: toolboxWidth,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(102),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(isDarkMode ? 153 : 76),
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(76),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.setting_4,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tool Box',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(128),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isLoading ? '...' : '${tools.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: isLoading
                ? _buildLoadingState(theme)
                : tools.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildToolsList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.setting_5,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 8),
            Text(
              'No tools',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsList(ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: tools.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: theme.colorScheme.outlineVariant.withAlpha(51),
        indent: 12,
        endIndent: 12,
      ),
      itemBuilder: (context, index) {
        final tool = tools[index];
        final isMcpGroup = tool['mcp'] == true;
        if (isMcpGroup) {
          final serverName = tool['name']?.toString() ?? 'MCP';
          final serverTools =
              (tool['tools'] as List?)?.cast<String>() ?? const [];
          return _buildMcpGroupItem(theme, serverName, serverTools);
        }
        return _buildToolItem(theme, tool);
      },
    );
  }

  IconData _getToolIcon(String toolName) {
    final lowerName = toolName.toLowerCase();
    if (lowerName.contains('search') || lowerName.contains('web')) {
      return Iconsax.search_normal;
    } else if (lowerName.contains('memory') || lowerName.contains('update')) {
      return Iconsax.save_2;
    }
    return Iconsax.code;
  }

  Widget _buildToolItem(ThemeData theme, Map<String, dynamic> tool) {
    final name = tool['name'] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(128),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              _getToolIcon(name),
              size: 16,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontFamily: 'Nunito',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMcpGroupItem(
      ThemeData theme, String serverName, List<String> serverTools) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(128),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Iconsax.hierarchy_2,
                  size: 16,
                  // color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                serverName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Nunito',
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (serverTools.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: serverTools.map((t) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withAlpha(64),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(64),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    t,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
