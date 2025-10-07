import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/services/api_service.dart';

class Sidebar extends StatefulWidget {
  final VoidCallback onNewChat;
  final Function(String) onSelectSession;

  const Sidebar({
    Key? key,
    required this.onNewChat,
    required this.onSelectSession,
  }) : super(key: key);

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  List<Map<String, String>> chatSessions = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) _loadChatSessions();
    });
  }

  Future<void> _loadChatSessions() async {
    setState(() => isLoading = true);
    try {
      final sessions = await ApiService.listChatSessions();
      setState(() => chatSessions = sessions
          .map((s) => {
                'id': (s['id'] ?? '').toString(),
                'name': (s['name'] ?? s['id'] ?? '').toString(),
              })
          .toList());
    } catch (e) {
      print('Error loading chat sessions: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void refresh() {
    _loadChatSessions();
  }

  Future<void> _deleteSession(String sessionId) async {
    setState(() {
      // Optimistic update: remove immediately for snappy UI
      chatSessions = chatSessions.where((s) => s['id'] != sessionId).toList();
    });
    try {
      await ApiService.deleteSession(sessionId);
    } catch (e) {
      // Re-sync from server on failure
      await _loadChatSessions();
    } finally {
      // Ensure list reflects backend state
      await _loadChatSessions();
    }
  }

  void _showSettingsMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset position =
        button.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy - 120,
        position.dx + button.size.width,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.storage),
            title: Text('Local Models'),
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () => _showLocalModels(),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.memory),
            title: Text('Agent Memory'),
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () => _showAgentMemory(),
        ),
      ],
    );
  }

  Future<void> _showLocalModels() async {
    final models = await ApiService.listLocalModels();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Available Local Models'),
        content: SizedBox(
          width: 400,
          child: models.isEmpty
              ? Text('No models found in models folder')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Icon(Icons.insert_drive_file),
                      title: Text(models[index]),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAgentMemory() async {
    try {
      final memory = await ApiService.getMemory();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Agent Memory'),
          content: SizedBox(
            width: 400,
            height: 500,
            child: SingleChildScrollView(
              child: Text(
                memory.entries.map((e) => '${e.key}: ${e.value}').join('\n\n'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading memory: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          SizedBox(height: 60),
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 13, bottom: 25, left: 15, right: 15),
            child: TextButton.icon(
              onPressed: widget.onNewChat,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 23),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
              label: Text('New Chat',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              icon: Icon(Iconsax.add, size: 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Iconsax.clock, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text('History',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : chatSessions.isEmpty
                    ? Center(
                        child: Text('No chat history',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: chatSessions.length,
                        itemBuilder: (context, index) {
                          final session = chatSessions[index];
                          final sessionId = session['id'] ?? '';
                          final sessionName = session['name'] ?? sessionId;
                          return _SessionItem(
                            sessionId: sessionId,
                            sessionName: sessionName,
                            onTap: () => widget.onSelectSession(sessionId),
                            onDelete: () => _deleteSession(sessionId),
                            theme: theme,
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                SizedBox(height: 8),
                Builder(
                  builder: (context) => InkWell(
                    onTap: () => _showSettingsMenu(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(Icons.settings, size: 18),
                          SizedBox(width: 8),
                          Text('Settings', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionItem extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ThemeData theme;

  const _SessionItem({
    required this.sessionId,
    required this.sessionName,
    required this.onTap,
    required this.onDelete,
    required this.theme,
  });

  @override
  State<_SessionItem> createState() => _SessionItemState();
}

class _SessionItemState extends State<_SessionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 15),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor:
                widget.theme.colorScheme.primary.withValues(alpha: 0.08),
            splashColor:
                widget.theme.colorScheme.primary.withValues(alpha: 0.12),
            highlightColor:
                widget.theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.sessionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 15,
                        // fontWeight: FontWeight.w600,
                        color: widget.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: _isHovered
                        ? IconButton(
                            icon: Icon(Iconsax.trash, size: 18),
                            onPressed: widget.onDelete,
                            color: widget.theme.colorScheme.error,
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            // splashRadius: 20,
                          )
                        : SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
