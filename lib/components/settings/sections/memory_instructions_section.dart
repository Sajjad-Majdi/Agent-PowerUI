import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/services/api_service.dart';
import '/components/subunits/status_message.dart';

class MemoryInstructionsSection extends StatefulWidget {
  const MemoryInstructionsSection({Key? key}) : super(key: key);

  @override
  State<MemoryInstructionsSection> createState() =>
      _MemoryInstructionsSectionState();
}

class _MemoryInstructionsSectionState extends State<MemoryInstructionsSection> {
  final TextEditingController _instructionsController = TextEditingController();
  Map<String, dynamic> _memory = {};
  bool _isLoading = true;
  bool _isSaving = false;
  final Set<String> _collapsedCategories = <String>{};
  String? _statusMessage;
  StatusType? _statusType;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final instructions = await ApiService.getInstructions();
      final memory = await ApiService.getMemory();

      if (mounted) {
        _instructionsController.text = instructions;
        setState(() {
          _memory = memory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Failed to load data: $e';
          _statusType = StatusType.error;
        });
      }
    }
  }

  Future<void> _saveInstructions() async {
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });
    try {
      await ApiService.setInstructions(_instructionsController.text);
      if (mounted) {
        setState(() {
          _statusMessage = 'Instructions saved successfully';
          _statusType = StatusType.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to save instructions: $e';
          _statusType = StatusType.error;
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteFact(String category, int factId) async {
    try {
      await ApiService.deleteMemoryFact(category, factId);
      await _loadData();
      if (mounted) {
        setState(() {
          _statusMessage = 'Memory deleted successfully';
          _statusType = StatusType.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to delete memory: $e';
          _statusType = StatusType.error;
        });
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Message
          if (_statusMessage != null) ...[
            StatusMessage(
              message: _statusMessage!,
              type: _statusType ?? StatusType.info,
              onDismiss: () => setState(() => _statusMessage = null),
            ),
            SizedBox(height: 16),
          ],

          // Instructions Section
          Row(
            children: [
              Icon(Iconsax.note_text,
                  size: 20, color: theme.colorScheme.primary),
              SizedBox(width: 10),
              Text(
                'Agent Instructions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Nunito',
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Custom instructions for the agent behavior',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: TextField(
              controller: _instructionsController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Enter custom instructions for the agent...',
                hintStyle: TextStyle(fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Nunito',
              ),
            ),
          ),
          SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveInstructions,
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Icon(Iconsax.tick_circle,
                      size: 18, color: theme.colorScheme.onPrimary),
              label: Text(_isSaving ? 'Saving...' : 'Save Instructions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                textStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Nunito',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          SizedBox(height: 24),

          // Memory Section
          Row(
            children: [
              Icon(Iconsax.archive_book,
                  size: 20, color: theme.colorScheme.primary),
              SizedBox(width: 10),
              Text(
                'Agent Memory',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Nunito',
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '${_memory.length} categories stored',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 16),

          if (_memory.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                child: Column(
                  children: [
                    Icon(Iconsax.archive_minus,
                        size: 46,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                    SizedBox(height: 14),
                    Text(
                      'No memories stored yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Nunito',
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._memory.entries.map((entry) {
              final categoryName = entry.key;
              final facts = entry.value as List;

              final isCollapsed = _collapsedCategories.contains(categoryName);
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          if (isCollapsed) {
                            _collapsedCategories.remove(categoryName);
                          } else {
                            _collapsedCategories.add(categoryName);
                          }
                        });
                      },
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Iconsax.tag,
                                  size: 14, color: theme.colorScheme.primary),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                categoryName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Nunito',
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: isCollapsed ? 0.25 : 0.0,
                              duration: Duration(milliseconds: 150),
                              child: Icon(Iconsax.arrow_down_1,
                                  size: 16,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: isCollapsed ? 0 : 1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: value,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Divider(
                              height: 1,
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.15)),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: facts.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.08),
                            ),
                            itemBuilder: (context, i) {
                              final fact = facts[i];
                              final factText = fact['fact'] ?? '';
                              final timestamp = fact['timestamp'] ?? '';
                              final factId = fact['id'] ?? 0;
                              final formattedTime = _formatTimestamp(timestamp);
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                title: Text(
                                  factText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Nunito',
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'FiraCode',
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                trailing: IconButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Delete Memory'),
                                        content: Text(
                                            'Are you sure you want to delete this memory?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      _deleteFact(categoryName, factId);
                                    }
                                  },
                                  icon: Icon(Iconsax.trash, size: 16),
                                  color: Colors.red.withValues(alpha: 0.7),
                                  padding: EdgeInsets.all(6),
                                  constraints: BoxConstraints(),
                                  tooltip: 'Delete',
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
