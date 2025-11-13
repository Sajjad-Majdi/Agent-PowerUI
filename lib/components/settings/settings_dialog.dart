import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'sections/local_models_section.dart';
import 'sections/memory_instructions_section.dart';
import 'sections/general_section.dart';
import 'sections/mcp_agents_section.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({Key? key}) : super(key: key);

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  int _selectedIndex = 0; // Default to General tab

  final List<_SectionItem> _sections = [
    _SectionItem(
      icon: Iconsax.setting_2,
      label: 'General',
      widget: GeneralSection(),
    ),
    _SectionItem(
      icon: Iconsax.note,
      label: 'Personalization',
      widget: MemoryInstructionsSection(),
    ),
    _SectionItem(
      icon: Iconsax.cpu,
      label: 'Offline Models',
      widget: LocalModelsSection(),
    ),
    _SectionItem(
      icon: Iconsax.hierarchy_2,
      label: 'MCP Agents',
      widget: McpAgentsSection(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.85).clamp(700.0, 950.0);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Container(
        width: dialogWidth,
        height: 600,
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Iconsax.setting,
                              size: 20, color: theme.colorScheme.primary),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Nunito',
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                  // Navigation items
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      itemCount: _sections.length,
                      itemBuilder: (context, index) {
                        final section = _sections[index];
                        final isSelected = _selectedIndex == index;
                        return InkWell(
                          onTap: () => setState(() => _selectedIndex = index),
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.3),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  section.icon,
                                  size: 18,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    section.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontFamily: 'Nunito',
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Content area
            Expanded(
              child: Column(
                children: [
                  // Close button
                  Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.all(8),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  // Section content
                  Expanded(
                    child: _sections[_selectedIndex].widget,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionItem {
  final IconData icon;
  final String label;
  final Widget widget;

  _SectionItem({
    required this.icon,
    required this.label,
    required this.widget,
  });
}
