import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/services/api_service.dart';
import 'subunits/sidebar_popup.dart';

class SettingsButton extends StatefulWidget {
  const SettingsButton({Key? key}) : super(key: key);

  @override
  State<SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<SettingsButton> {
  bool _isHovered = false;

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      if (difference.inDays < 30)
        return '${(difference.inDays / 7).floor()}w ago';
      if (difference.inDays < 365)
        return '${(difference.inDays / 30).floor()}mo ago';
      return '${(difference.inDays / 365).floor()}y ago';
    } catch (e) {
      return timestamp.substring(0, 10);
    }
  }

  Future<void> _showLocalModels() async {
    final result = await ApiService.listLocalModels();
    final models = result.models;
    final runningModel = result.status.model;
    if (!mounted) return;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.3)),
        ),
        child: Container(
          width: 500,
          constraints: BoxConstraints(maxHeight: 600),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Iconsax.cpu,
                        size: 28, color: theme.colorScheme.primary),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Local Models',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Nunito',
                                color: theme.colorScheme.onSurface)),
                        SizedBox(height: 4),
                        Text('${models.length} models available',
                            style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              SizedBox(height: 16),
              Expanded(
                child: models.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.folder_open,
                                size: 48,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3)),
                            SizedBox(height: 16),
                            Text('No models found',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Nunito',
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5))),
                            SizedBox(height: 8),
                            Text('Add .gguf files to the models folder',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: models.length,
                        itemBuilder: (context, index) {
                          final model = models[index];
                          final modelName = model.name;
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Iconsax.document,
                                    size: 20, color: theme.colorScheme.primary),
                              ),
                              title: Text(modelName,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Nunito')),
                              subtitle: Text(
                                  model.humanReadableSize +
                                      (runningModel == modelName
                                          ? ' • Running'
                                          : ''),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6))),
                            ),
                          );
                        },
                      ),
              ),
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Close',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Nunito',
                          color: theme.colorScheme.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAgentMemory() async {
    try {
      var memory = await ApiService.getMemory();
      if (!mounted) return;
      final theme = Theme.of(context);

      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Container(
              width: 600,
              constraints: BoxConstraints(maxHeight: 700),
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Iconsax.archive_book,
                            size: 28, color: theme.colorScheme.primary),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Agent Memory',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Nunito',
                                    color: theme.colorScheme.onSurface)),
                            SizedBox(height: 4),
                            Text('${memory.length} memory entries stored',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                  SizedBox(height: 16),
                  Expanded(
                    child: memory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.archive_minus,
                                    size: 48,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3)),
                                SizedBox(height: 16),
                                Text('No memories stored yet',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Nunito',
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5))),
                                SizedBox(height: 8),
                                Text(
                                    'The agent will remember information as you interact',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4))),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: memory.length,
                            itemBuilder: (context, index) {
                              final entry = memory.entries.elementAt(index);
                              final categoryName = entry.key;
                              final facts = entry.value as List;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                        left: 8,
                                        bottom: 12,
                                        top: index == 0 ? 0 : 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(Iconsax.tag,
                                              size: 14,
                                              color: theme.colorScheme.primary),
                                        ),
                                        SizedBox(width: 10),
                                        Text(categoryName,
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Nunito',
                                                color:
                                                    theme.colorScheme.primary)),
                                      ],
                                    ),
                                  ),
                                  ...facts.map((fact) {
                                    final factText = fact['fact'] ?? '';
                                    final timestamp = fact['timestamp'] ?? '';
                                    final factId = fact['id'] ?? 0;
                                    final formattedTime =
                                        _formatTimestamp(timestamp);

                                    return Container(
                                      margin: EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(factText,
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontFamily: 'Nunito',
                                                          height: 1.4,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface)),
                                                ),
                                                SizedBox(width: 8),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme.primary
                                                        .withValues(
                                                            alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(formattedTime,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontFamily:
                                                              'FiraCode',
                                                          color: theme
                                                              .colorScheme
                                                              .primary)),
                                                ),
                                                SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () async {
                                                    final confirm =
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) =>
                                                          AlertDialog(
                                                        title: Text(
                                                            'Delete Memory'),
                                                        content: Text(
                                                            'Are you sure you want to delete this memory?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    false),
                                                            child:
                                                                Text('Cancel'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    true),
                                                            child: Text(
                                                                'Delete',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .red)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true) {
                                                      try {
                                                        await ApiService
                                                            .deleteMemoryFact(
                                                                categoryName,
                                                                factId);
                                                        final updatedMemory =
                                                            await ApiService
                                                                .getMemory();
                                                        setDialogState(() {
                                                          memory =
                                                              updatedMemory;
                                                        });
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                              content: Text(
                                                                  'Failed to delete memory')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Icon(
                                                      Iconsax.trash,
                                                      size: 18,
                                                      color: Colors.red
                                                          .withValues(
                                                              alpha: 0.7),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          ),
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Close',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Nunito',
                              color: theme.colorScheme.primary)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading memory: $e'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  void _showSettingsMenu() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;
    final theme = Theme.of(context);

    Navigator.of(context).push(
      SlideUpPopupRoute(
        position: buttonPosition,
        buttonSize: buttonSize,
        theme: theme,
        onLocalModels: _showLocalModels,
        onAgentMemory: _showAgentMemory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: _showSettingsMenu,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.transparent,
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Iconsax.setting,
                  size: 20, color: theme.colorScheme.onSurface),
              SizedBox(width: 12),
              Text('Settings',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Nunito',
                      color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
