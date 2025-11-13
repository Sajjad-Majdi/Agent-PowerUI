import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/theme.dart';
import '/services/api_service.dart' show McpAgentInfo;

class ToolBox extends StatefulWidget {
  final List<Map<String, dynamic>> tools;
  final List<McpAgentInfo> mcpAgents;
  final bool isLoading;
  final VoidCallback onRefresh;

  const ToolBox({
    Key? key,
    required this.tools,
    required this.mcpAgents,
    required this.isLoading,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<ToolBox> createState() => _ToolBoxState();
}

class _ToolBoxState extends State<ToolBox> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final toolboxWidth = screenWidth < 600 ? screenWidth * 0.6 : 400.0;

    return Container(
      width: toolboxWidth,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: AppTheme.colors.inputBarColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(102),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(76),
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
              ],
            ),
          ),
          // Content
          Flexible(
            child: widget.isLoading
                ? _buildLoadingState(theme)
                : (widget.tools.isEmpty && widget.mcpAgents.isEmpty)
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
    final List<Widget> children = [];

    // Show core tools (non-MCP)
    final coreTools =
        widget.tools.where((tool) => tool['mcp'] != true).toList();

    for (int i = 0; i < coreTools.length; i++) {
      children.add(_buildToolItem(theme, coreTools[i]));
      if (i != coreTools.length - 1) {
        children.add(Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withAlpha(51),
          indent: 12,
          endIndent: 12,
        ));
      }
    }

    // Show MCP tools (from tools list marked with mcp flag)
    final mcpTools = widget.tools.where((tool) => tool['mcp'] == true).toList();

    // Also show MCP agents that might not have tools yet
    if (mcpTools.isNotEmpty || widget.mcpAgents.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: 12));
      }
      children.add(_buildSectionHeader(theme, 'MCP Agents'));

      // Show MCP tools from registry (these are active/ready)
      for (int i = 0; i < mcpTools.length; i++) {
        final tool = mcpTools[i];
        final displayName = tool['display_name'] ?? tool['name'] ?? 'Unknown';
        children.add(_buildToolItem(theme, {'name': displayName}));
        if (i != mcpTools.length - 1 || widget.mcpAgents.isNotEmpty) {
          children.add(Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant.withAlpha(51),
            indent: 12,
            endIndent: 12,
          ));
        }
      }

      // Show additional MCP agents that aren't in tools yet (pending metadata)
      final mcpServerNames = mcpTools
          .map((t) => t['server_name'])
          .where((name) => name != null)
          .toSet();
      final pendingAgents = widget.mcpAgents
          .where((agent) => !mcpServerNames.contains(agent.serverName))
          .toList();

      for (int i = 0; i < pendingAgents.length; i++) {
        final agent = pendingAgents[i];
        children.add(_buildToolItem(theme, {'name': agent.displayName}));
        if (i != pendingAgents.length - 1) {
          children.add(Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant.withAlpha(51),
            indent: 12,
            endIndent: 12,
          ));
        }
      }
    }

    if (children.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: children,
    );
  }

  IconData _getToolIcon(String toolName) {
    final lowerName = toolName.toLowerCase();
    if (lowerName.contains('file_explorer') || lowerName.contains('explorer')) {
      return Iconsax.folder;
    } else if (lowerName.contains('search') || lowerName.contains('web')) {
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

  Widget _buildSectionHeader(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(Iconsax.hierarchy_2, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withAlpha(204),
            ),
          ),
        ],
      ),
    );
  }
}
