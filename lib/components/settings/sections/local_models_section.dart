import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:dotted_border/dotted_border.dart';
import '/services/api_service.dart';
import '/components/subunits/status_message.dart';
import '/theme.dart';

class LocalModelsSection extends StatefulWidget {
  const LocalModelsSection({Key? key}) : super(key: key);

  @override
  State<LocalModelsSection> createState() => _LocalModelsSectionState();
}

class _LocalModelsSectionState extends State<LocalModelsSection> {
  List<LocalModelInfo> _models = [];
  LocalAgentStatus _status = const LocalAgentStatus(running: false);
  bool _isLoading = true;
  bool _isImporting = false;
  bool _dragging = false;
  String? _modelsFolder;
  final TextEditingController _modelsPathController = TextEditingController();
  final TextEditingController _llamaPathController = TextEditingController();
  bool _isSavingPaths = false;
  String? _statusMessage;
  StatusType? _statusType;

  @override
  void initState() {
    super.initState();
    _loadPathConfig();
    _loadModels();
  }

  @override
  void dispose() {
    _modelsPathController.dispose();
    _llamaPathController.dispose();
    super.dispose();
  }

  Future<void> _loadPathConfig() async {
    try {
      final config = await ApiService.getPathConfig();
      if (!mounted) return;
      setState(() {
        _modelsFolder = config['models_folder']?.toString();
        _modelsPathController.text = _modelsFolder ?? '';
        _llamaPathController.text =
            config['llama_server_path']?.toString() ?? '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to load paths: $e';
          _statusType = StatusType.error;
        });
      }
    }
  }

  Future<void> _savePaths() async {
    setState(() {
      _isSavingPaths = true;
      _statusMessage = null;
    });
    try {
      await ApiService.setPathConfig(
        modelsFolder: _modelsPathController.text.trim().isEmpty
            ? null
            : _modelsPathController.text.trim(),
        llamaServerPath: _llamaPathController.text.trim().isEmpty
            ? null
            : _llamaPathController.text.trim(),
      );
      await _loadPathConfig();
      if (mounted) {
        setState(() {
          _statusMessage = 'Paths saved successfully';
          _statusType = StatusType.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to save paths: $e';
          _statusType = StatusType.error;
        });
      }
    } finally {
      if (mounted) setState(() => _isSavingPaths = false);
    }
  }

  Future<void> _pickModelsFolder() async {
    final path = await getDirectoryPath();
    if (path != null && mounted) {
      setState(() => _modelsPathController.text = path);
    }
  }

  Future<void> _pickLlamaBinary() async {
    const typeGroup = XTypeGroup(
      label: 'Executables',
      extensions: ['exe'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null && mounted) {
      setState(() => _llamaPathController.text = file.path);
    }
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final result = await ApiService.listLocalModels();
      if (mounted) {
        setState(() {
          _models = result.models;
          _status = result.status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Failed to load models: $e';
          _statusType = StatusType.error;
        });
      }
    }
  }

  Future<void> _pickFiles() async {
    if (kIsWeb) {
      setState(() {
        _statusMessage = 'File import is not supported in the web build';
        _statusType = StatusType.warning;
      });
      return;
    }
    if (_isImporting) return;

    final typeGroup = XTypeGroup(label: 'GGUF files', extensions: ['gguf']);
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (files.isEmpty) return;
    await _importFiles(files);
  }

  Future<void> _importFiles(List<XFile> files) async {
    if (!mounted || files.isEmpty) return;
    setState(() => _isImporting = true);

    final List<String> imported = [];
    final List<String> skipped = [];
    final List<String> failed = [];
    String? lastError;

    for (final file in files) {
      String path = file.path;
      final name = file.name;

      print('[LocalModels] Processing file: $name');
      print('[LocalModels] File path from XFile: $path');
      print('[LocalModels] File path type: ${path.runtimeType}');
      print('[LocalModels] File path length: ${path.length}');

      // Handle file:// URI on Windows
      if (path.startsWith('file:///')) {
        path = Uri.parse(path).toFilePath();
        print('[LocalModels] Converted from URI to: $path');
      } else if (path.startsWith('file://')) {
        path = Uri.parse(path).toFilePath();
        print('[LocalModels] Converted from URI to: $path');
      }

      if (path.isEmpty) {
        failed.add(name);
        lastError = 'Missing file path';
        print('[LocalModels] Error: Missing file path for $name');
        continue;
      }

      if (!path.toLowerCase().endsWith('.gguf')) {
        skipped.add(name);
        print('[LocalModels] Skipped non-GGUF file: $name');
        continue;
      }

      try {
        print('[LocalModels] Calling API with path: $path');
        final result = await ApiService.importLocalModel(path: path);
        imported.add(name);
        print(
            '[LocalModels] Successfully imported: $name -> ${result['destination']}');
      } catch (e) {
        failed.add(name);
        lastError = e.toString();
        print('[LocalModels] Failed to import $name: $e');
      }
    }

    await _loadModels();

    if (!mounted) return;

    setState(() => _isImporting = false);

    final List<String> messages = [];
    if (imported.isNotEmpty) {
      messages.add('Imported ${imported.length} file(s).');
    }
    if (skipped.isNotEmpty) {
      messages.add('Skipped ${skipped.length} non-GGUF file(s).');
    }
    if (failed.isNotEmpty) {
      final errorSuffix = lastError != null ? ' ($lastError)' : '';
      messages.add('Failed ${failed.length} file(s)$errorSuffix');
    }

    if (messages.isNotEmpty) {
      setState(() {
        _statusMessage = messages.join(' ');
        _statusType = failed.isNotEmpty
            ? StatusType.error
            : imported.isNotEmpty
                ? StatusType.success
                : StatusType.info;
      });
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    if (_isImporting || details.files.isEmpty) return;
    await _importFiles(details.files);
  }

  Future<void> _deleteModel(String modelName) async {
    // Check if model is running
    if (_status.running && _status.model == modelName) {
      setState(() {
        _statusMessage = 'Cannot delete a running model';
        _statusType = StatusType.error;
      });
      return;
    }

    try {
      await ApiService.deleteLocalModel(name: modelName);
      await _loadModels();
      if (mounted) {
        setState(() {
          _statusMessage = 'Model deleted successfully';
          _statusType = StatusType.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to delete model: $e';
          _statusType = StatusType.error;
        });
      }
    }
  }

  Widget _buildImportSection(ThemeData theme) {
    final borderColor = _dragging
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withValues(alpha: 0.3);

    if (kIsWeb) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.information,
                    color: theme.colorScheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Local import unavailable on web builds',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'Run the desktop app to drag and drop .gguf models directly into your models folder.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _handleDrop,
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: Radius.circular(12),
        color: borderColor,
        strokeWidth: 1.6,
        dashPattern: [6, 4],
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _dragging
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surface.withValues(alpha: 0.9),
          ),
          child: Row(
            children: [
              Icon(
                Iconsax.cloud_add,
                size: 24,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import New Models',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Nunito',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Drag & drop .gguf files here to add to your library',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isImporting ? null : _pickFiles,
                    icon: Icon(Iconsax.folder_add, size: 16),
                    label: Text('Browse'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  if (_isImporting) ...[
                    SizedBox(width: 12),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

          // Header
          Row(
            children: [
              Icon(Iconsax.folder, size: 20, color: theme.colorScheme.primary),
              SizedBox(width: 10),
              Text(
                "Offline models",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Nunito',
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Run AI models locally on your device without an internet connection.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

          SizedBox(height: 20),

          // Import Section
          _buildImportSection(theme),

          SizedBox(height: 20),

          // Available Models
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Models',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Nunito',
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${_models.length} found',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          if (_models.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Iconsax.folder_open,
                      size: 40,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  SizedBox(height: 12),
                  Text(
                    'No models found',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._models.map((model) {
              final isRunning = _status.running && _status.model == model.name;
              return _ModelItem(
                model: model,
                isRunning: isRunning,
                theme: theme,
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.colors.messageBubbleColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: AppTheme.colors.primaryColor
                              .withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      title: const Text(
                        'Delete Model',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      content: Text(
                          'Are you sure you want to delete "${model.name}"?\n\nThis action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
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
                    await _deleteModel(model.name);
                  }
                },
              );
            }).toList(),

          SizedBox(height: 24),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          SizedBox(height: 20),

          // Resource Paths Section
          Text(
            'System Paths Configuration',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Nunito',
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Configure where your models are located.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactPathField(
                  label: 'Models Directory',
                  controller: _modelsPathController,
                  icon: Iconsax.folder,
                  onBrowse: _pickModelsFolder,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildCompactPathField(
                  label: 'Llama Server Executable',
                  controller: _llamaPathController,
                  icon: Iconsax.cpu,
                  onBrowse: _pickLlamaBinary,
                ),
              ),
              SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _isSavingPaths ? null : _savePaths,
                    icon: _isSavingPaths
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : Icon(Iconsax.tick_square, size: 40),
                    tooltip: 'Save',
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: EdgeInsets.all(0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPathField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onBrowse,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Default',
                  hintStyle: TextStyle(fontSize: 12),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 12, fontFamily: 'FiraCode'),
              ),
            ),
            SizedBox(width: 4),
            IconButton(
              onPressed: onBrowse,
              icon: Icon(Iconsax.folder_open, size: 16),
              tooltip: 'Browse',
              style: IconButton.styleFrom(
                padding: EdgeInsets.all(8),
                minimumSize: Size(32, 32),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModelItem extends StatefulWidget {
  final LocalModelInfo model;
  final bool isRunning;
  final ThemeData theme;
  final VoidCallback onDelete;

  const _ModelItem({
    required this.model,
    required this.isRunning,
    required this.theme,
    required this.onDelete,
  });

  @override
  State<_ModelItem> createState() => _ModelItemState();
}

class _ModelItemState extends State<_ModelItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isRunning
              ? widget.theme.colorScheme.primary.withValues(alpha: 0.1)
              : widget.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isRunning
                ? widget.theme.colorScheme.primary.withValues(alpha: 0.3)
                : widget.theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.isRunning ? Iconsax.cpu5 : Iconsax.document,
              size: 18,
              color: widget.isRunning
                  ? widget.theme.colorScheme.primary
                  : widget.theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.model.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Nunito',
                      color: widget.theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    widget.model.humanReadableSize,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isRunning)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      widget.theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Running',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.theme.colorScheme.primary,
                  ),
                ),
              ),
            SizedBox(width: 8),
            if (_isHovered && !widget.isRunning)
              IconButton(
                icon: Icon(Iconsax.trash, size: 20),
                onPressed: widget.onDelete,
                color: Colors.red.withValues(alpha: 0.8),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.all(10),
                  minimumSize: Size(35, 35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
