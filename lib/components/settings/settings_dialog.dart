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
      label: 'MCP SubAgents',
      widget: McpAgentsSection(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Determine if mobile layout should be used
    // Switching to mobile layout if width is small or aspect ratio is portrait
    final isMobile = screenWidth < 750 || mediaQuery.size.aspectRatio < 1.0;

    final dialogWidth = isMobile
        ? (screenWidth * 0.95).clamp(300.0, 750.0)
        : (screenWidth * 0.85).clamp(750.0, 950.0);

    final dialogHeight = isMobile ? screenHeight * 0.85 : 600.0;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: isMobile
          ? EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        child: isMobile
            ? _buildMobileLayout(theme, dialogWidth)
            : _buildDesktopLayout(theme),
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
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
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
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
                        margin:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }

  Widget _buildMobileLayout(ThemeData theme, double dialogWidth) {
    // Calculate scaling factor based on dialog width
    // Mapping range: ~300 (min mobile) to ~750 (desktop breakpoint)
    final t = ((dialogWidth - 300) / (750 - 300)).clamp(0.0, 1.0);

    final double spacing = 2.0 + (4.0 * t);
    final double hPadding = 6.0 + (8.0 * t);
    final double vPadding = 6.0 + (4.0 * t);
    final double fontSize = 11.0 + (3.0 * t);
    final double iconSize = 14.0 + (4.0 * t);
    final double iconGap = 4.0 + (4.0 * t);

    return Column(
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 8, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Nunito',
                  color: theme.colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),

        // Tabs (Wrap)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing,
              runSpacing: 8.0,
              children: List.generate(_sections.length, (index) {
                final section = _sections[index];
                final isSelected = _selectedIndex == index;
                return InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: hPadding, vertical: vPadding),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.3),
                              width: 1,
                            )
                          : Border.all(
                              color: Colors.transparent,
                              width: 1,
                            ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Icon(
                            section.icon,
                            size: iconSize,
                            color: theme.colorScheme.primary,
                          ),
                          SizedBox(width: iconGap),
                        ],
                        Text(
                          section.label,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontFamily: 'Nunito',
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        Divider(
            height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.2)),

        // Content
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: _sections[_selectedIndex].widget,
          ),
        ),
      ],
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
