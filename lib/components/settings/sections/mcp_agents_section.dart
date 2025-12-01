import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/components/subunits/status_message.dart';
import '/services/api_service.dart';
import '/theme.dart';

class McpAgentsSection extends StatefulWidget {
  const McpAgentsSection({Key? key}) : super(key: key);

  @override
  State<McpAgentsSection> createState() => _McpAgentsSectionState();
}

class _McpAgentsSectionState extends State<McpAgentsSection> {
  bool _isLoading = true;
  bool _isBusy = false;
  List<McpAgentInfo> _agents = [];
  String? _statusMessage;
  StatusType? _statusType;
  final Set<String> _expandedAgents = {};

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final agents = await ApiService.listMcpAgents();
      if (!mounted) return;
      setState(() {
        _agents = agents;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Failed to load MCP agents: $e';
        _statusType = StatusType.error;
      });
    }
  }

  Future<void> _showAddAgentDialog() async {
    final serverNameController = TextEditingController();
    final jsonConfigController = TextEditingController();

    McpAgentCreationResult? creationResult;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSubmitting = false;
        String? error;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> handleSubmit() async {
              final serverName = serverNameController.text.trim();
              final jsonText = jsonConfigController.text.trim();

              if (serverName.isEmpty) {
                setLocalState(() {
                  error = 'Server name is required.';
                });
                return;
              }

              if (jsonText.isEmpty) {
                setLocalState(() {
                  error = 'Server configuration JSON is required.';
                });
                return;
              }

              setLocalState(() {
                isSubmitting = true;
                error = null;
              });

              try {
                // Parse JSON configuration
                final dynamic parsed = jsonDecode(jsonText);
                if (parsed is! Map<String, dynamic>) {
                  throw 'Configuration must be a JSON object';
                }

                final config = parsed;

                creationResult = await ApiService.addMcpAgent(
                  serverName: serverName,
                  config: config,
                );
                if (!mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                setLocalState(() {
                  isSubmitting = false;
                  error = 'Failed to add agent: $e';
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.colors.messageBubbleColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppTheme.colors.primaryColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              title: const Text(
                'Add MCP Agent',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.red.withAlpha(100)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: serverNameController,
                        decoration: InputDecoration(
                          labelText: 'Name for this agent',
                          hintText: 'e.g., web_browser',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: AppTheme.colors.inputBarColor,
                        ),
                        enabled: !isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: jsonConfigController,
                        decoration: InputDecoration(
                          labelText: 'Configuration for the MCP server (JSON)',
                          hintText:
                              '{\n  "command": "npx",\n  "args": ["@playwright/mcp@latest"],\n  "transport": "stdio"\n}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor,
                              width: 2,
                            ),
                          ),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: AppTheme.colors.inputBarColor,
                        ),
                        maxLines: 12,
                        enabled: !isSubmitting,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withAlpha(60),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withAlpha(40),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Accepted config formats:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha(8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Local (stdio):',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Text(
                                            '{',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                    color: Colors.grey[400],
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: '"command"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .amber[300]),
                                                    ),
                                                    const TextSpan(text: ': '),
                                                    TextSpan(
                                                      text: '"python"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .green[300]),
                                                    ),
                                                    const TextSpan(text: ','),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              RichText(
                                                text: TextSpan(
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                    color: Colors.grey[400],
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: '"args"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .amber[300]),
                                                    ),
                                                    const TextSpan(text: ': ['),
                                                    TextSpan(
                                                      text:
                                                          '"/path/to/server.py"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .green[300]),
                                                    ),
                                                    const TextSpan(text: '],'),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              RichText(
                                                text: TextSpan(
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                    color: Colors.grey[400],
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: '"transport"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .amber[300]),
                                                    ),
                                                    const TextSpan(text: ': '),
                                                    TextSpan(
                                                      text: '"stdio"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .green[300]),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Text(
                                            '}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha(8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Remote (streamable_http):',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Text(
                                            '{',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                    color: Colors.grey[400],
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: '"url"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .amber[300]),
                                                    ),
                                                    const TextSpan(text: ': '),
                                                    TextSpan(
                                                      text:
                                                          '"http://localhost:8000/mcp"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .green[300]),
                                                    ),
                                                    const TextSpan(text: ','),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              RichText(
                                                text: TextSpan(
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                    color: Colors.grey[400],
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: '"transport"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .amber[300]),
                                                    ),
                                                    const TextSpan(text: ': '),
                                                    TextSpan(
                                                      text: '"streamable_http"',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .green[300]),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Text(
                                            '}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : handleSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (creationResult != null) {
      await _loadAgents();
      final requiresManual = creationResult!.requiresManualMetadata;
      await _showMetadataDialog(
        creationResult!.agent,
        requiresManual: requiresManual,
      );
      await _loadAgents();
      if (!mounted) return;
      setState(() {
        _statusMessage = requiresManual
            ? 'MCP agent added. Metadata requires manual completion.'
            : 'MCP agent added successfully.';
        _statusType = requiresManual ? StatusType.warning : StatusType.success;
      });
    }
  }

  Future<void> _showMetadataDialog(
    McpAgentInfo agent, {
    bool requiresManual = false,
  }) async {
    McpAgentInfo currentAgent = agent;
    final nameController = TextEditingController(
        text: currentAgent.metadata['name']?.toString() ?? '');
    final descriptionController = TextEditingController(
        text: currentAgent.metadata['description']?.toString() ?? '');
    final promptController = TextEditingController(
        text: currentAgent.metadata['system_prompt']?.toString() ?? '');

    bool isSaving = false;
    bool isRegenerating = false;
    String? error;

    Future<void> refreshFromServer() async {
      final updated =
          await ApiService.regenerateMcpAgentMetadata(currentAgent.serverName);
      currentAgent = updated;
      nameController.text =
          updated.metadata['name']?.toString() ?? nameController.text;
      descriptionController.text =
          updated.metadata['description']?.toString() ??
              descriptionController.text;
      promptController.text = updated.metadata['system_prompt']?.toString() ??
          promptController.text;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !requiresManual,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> handleSave() async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();
              final prompt = promptController.text.trim();

              if (name.isEmpty || description.isEmpty || prompt.isEmpty) {
                setLocalState(() {
                  error =
                      'Name, description, and system prompt must not be empty.';
                });
                return;
              }

              setLocalState(() {
                isSaving = true;
                error = null;
              });

              try {
                final updated = await ApiService.updateMcpAgentMetadata(
                  serverName: currentAgent.serverName,
                  name: name,
                  description: description,
                  systemPrompt: prompt,
                );
                currentAgent = updated;
                if (!mounted) return;
                Navigator.of(context).pop(true);
              } catch (e) {
                setLocalState(() {
                  isSaving = false;
                  error = e.toString();
                });
              }
            }

            Future<void> handleRegenerate() async {
              setLocalState(() {
                isRegenerating = true;
                error = null;
              });
              try {
                await refreshFromServer();
                setLocalState(() {
                  isRegenerating = false;
                });
              } catch (e) {
                setLocalState(() {
                  isRegenerating = false;
                  error = e.toString();
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.colors.messageBubbleColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppTheme.colors.primaryColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              title: Text(
                'MCP Agent Metadata',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (requiresManual) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Iconsax.warning_2,
                                  size: 18, color: Colors.amber),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Gemini could not generate metadata automatically. Please complete the fields manually.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Display name',
                          helperText:
                              'Short and memorable label shown in the tool box.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: AppTheme.colors.inputBarColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          helperText:
                              'One sentence that helps the primary agent decide when to call this MCP agent.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: AppTheme.colors.inputBarColor,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: promptController,
                        decoration: InputDecoration(
                          labelText: 'System prompt',
                          helperText:
                              'Detailed operating instructions for the MCP agent (will be sent verbatim).',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppTheme.colors.primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: AppTheme.colors.inputBarColor,
                        ),
                        maxLines: 8,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('Close'),
                ),
                TextButton.icon(
                  onPressed:
                      isSaving || isRegenerating ? null : handleRegenerate,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.colors.primaryColor,
                  ),
                  icon: isRegenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Iconsax.refresh, size: 16),
                  label: const Text('Regenerate'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : handleSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _loadAgents();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'MCP agent metadata saved.';
        _statusType = StatusType.success;
      });
      return;
    }

    await _loadAgents();
  }

  Future<void> _deleteAgent(McpAgentInfo agent) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.colors.messageBubbleColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.colors.primaryColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        title: const Text(
          'Delete MCP agent',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
          ),
        ),
        content: Text(
            'Are you sure you want to delete "${agent.displayName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteMcpAgent(agent.serverName);
        await _loadAgents();
        if (!mounted) return;
        setState(() {
          _statusMessage = 'MCP agent deleted.';
          _statusType = StatusType.success;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Failed to delete MCP agent: $e';
          _statusType = StatusType.error;
        });
      }
    }
  }

  Future<void> _regenerateAgent(McpAgentInfo agent) async {
    setState(() {
      _isBusy = true;
    });
    try {
      await ApiService.regenerateMcpAgentMetadata(agent.serverName);
      await _loadAgents();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Metadata regenerated for ${agent.displayName}.';
        _statusType = StatusType.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to regenerate metadata: $e';
        _statusType = StatusType.error;
      });
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Widget _buildAgentCard(McpAgentInfo agent) {
    final theme = Theme.of(context);
    final isReady = agent.isReady;
    final status = agent.status;
    final statusLabel = status
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : part.substring(0, 1).toUpperCase() + part.substring(1))
        .join(' ');

    final Color statusColor;
    if (isReady) {
      statusColor = Colors.green.shade400;
    } else if (status == 'pending_metadata') {
      statusColor = Colors.orange;
    } else {
      statusColor = theme.colorScheme.error;
    }

    final toolNames = agent.tools
        .map((tool) =>
            tool is Map ? (tool['name']?.toString() ?? '') : tool.toString())
        .where((name) => name.isNotEmpty)
        .toList();

    final description = agent.description;
    final promptPreview = agent.systemPrompt.length > 180
        ? '${agent.systemPrompt.substring(0, 180)}...'
        : agent.systemPrompt;

    final isExpanded = _expandedAgents.contains(agent.serverName);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady
              ? theme.colorScheme.outline.withAlpha(64)
              : theme.colorScheme.primary.withAlpha(120),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedAgents.remove(agent.serverName);
                } else {
                  _expandedAgents.add(agent.serverName);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(32),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Iconsax.hierarchy_2,
                        color: theme.colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent.displayName,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          agent.serverName,
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(32),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: isExpanded ? 1 : 0),
            duration: const Duration(milliseconds: 300),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(210),
                      ),
                    ),
                  ],
                  if (toolNames.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: toolNames.take(6).map((toolName) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withAlpha(64),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            toolName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (promptPreview.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'System prompt preview',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      promptPreview,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'FiraCode',
                        color:
                            theme.colorScheme.onSurfaceVariant.withAlpha(220),
                      ),
                    ),
                  ],
                  if ((agent.lastError ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withAlpha(24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Iconsax.danger,
                              size: 18, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              agent.lastError!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed:
                            _isBusy ? null : () => _regenerateAgent(agent),
                        icon: const Icon(Iconsax.refresh, size: 16),
                        label: const Text('Regenerate'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _showMetadataDialog(agent,
                            requiresManual: !agent.isReady),
                        icon: const Icon(Iconsax.edit_2, size: 16),
                        label: const Text('Edit metadata'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isBusy ? null : () => _deleteAgent(agent),
                        tooltip: 'Delete agent',
                        icon: const Icon(Iconsax.trash),
                        color: Colors.red.withAlpha(200),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_statusMessage != null) ...[
            StatusMessage(
              message: _statusMessage!,
              type: _statusType ?? StatusType.info,
              onDismiss: () => setState(() => _statusMessage = null),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Icon(Iconsax.hierarchy_2,
                  size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                'MCP SubAgents',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isBusy ? null : _showAddAgentDialog,
                icon: const Icon(Iconsax.add, size: 16),
                label: const Text('Add Agent'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Model Context Protocol (MCP) connects your AI to external tools and data. You can extend the main agent\'s capabilities by adding sub-agents. simply provide the MCP server configuration (JSON) for any compatible toolset.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_agents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(64),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.box,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(160)),
                  const SizedBox(height: 12),
                  Text(
                    'No MCP agents yet',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first MCP configuration to unlock additional tools.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(200),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._agents.map(_buildAgentCard),
        ],
      ),
    );
  }
}
