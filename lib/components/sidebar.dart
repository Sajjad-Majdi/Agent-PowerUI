import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/services/api_service.dart';
import '/theme.dart';
import 'settings_button.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final englishMedium = AppTheme.textStyles.englishMedium;
    // final persianMedium = AppTheme.textStyles.persianMedium;

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
                  style: englishMedium.copyWith(
                      fontSize: 15.0, color: theme.colorScheme.primary)),
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
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(5),
            child: SettingsButton(),
          )
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
