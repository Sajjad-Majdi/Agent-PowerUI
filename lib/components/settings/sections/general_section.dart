import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/services/api_service.dart';
import '/theme.dart';
import '/components/subunits/status_message.dart';

class GeneralSection extends StatefulWidget {
  const GeneralSection({Key? key}) : super(key: key);

  @override
  State<GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends State<GeneralSection> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasKey = false;
  String _maskedKey = '';
  bool _showApiKey = false;
  String? _statusMessage;
  StatusType? _statusType;

  @override
  void initState() {
    super.initState();
    _loadApiKeyStatus();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKeyStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final status = await ApiService.getGeminiApiKeyStatus();
      if (mounted) {
        setState(() {
          _hasKey = status['has_key'] ?? false;
          _maskedKey = status['masked_key'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Failed to load API key status: $e';
          _statusType = StatusType.error;
        });
      }
    }
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter an API key';
        _statusType = StatusType.warning;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });
    try {
      await ApiService.setGeminiApiKey(apiKey);
      _apiKeyController.clear();
      await _loadApiKeyStatus();
      if (mounted) {
        setState(() {
          _statusMessage = 'API key saved successfully';
          _statusType = StatusType.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to save API key: $e';
          _statusType = StatusType.error;
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

          // Gemini API Key Section
          Row(
            children: [
              Icon(Iconsax.key, size: 18, color: theme.colorScheme.primary),
              SizedBox(width: 8),
              Text(
                'Gemini API Key',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Nunito',
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Spacer(),
              if (_hasKey)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.tick_circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'The API key is required to communicate with Google\'s Gemini AI. You can get one from Google AI Studio.',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (_hasKey) ...[
            SizedBox(height: 8),
            Text(
              _maskedKey,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'FiraCode',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
          SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: !_showApiKey,
            decoration: InputDecoration(
              hintText: 'Paste your Gemini API key here',
              hintStyle: TextStyle(fontSize: 13),
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
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _showApiKey ? Iconsax.eye_slash : Iconsax.eye,
                      size: 16,
                    ),
                    onPressed: () {
                      setState(() => _showApiKey = !_showApiKey);
                    },
                  ),
                  if (_apiKeyController.text.isNotEmpty)
                    IconButton(
                      icon: _isSaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Iconsax.tick_circle, size: 16),
                      color: theme.colorScheme.primary,
                      onPressed: _isSaving ? null : _saveApiKey,
                      tooltip: 'Save',
                    ),
                ],
              ),
            ),
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'FiraCode',
            ),
            onSubmitted: (_) => _saveApiKey(),
          ),
          SizedBox(height: 8),
          Text(
            'Get your API key from Google AI Studio',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),

          SizedBox(height: 32),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          SizedBox(height: 24),

          // Privacy Mode Section
          Row(
            children: [
              Icon(
                AppTheme.isPrivacyMode
                    ? Iconsax.shield_tick
                    : Iconsax.shield_cross,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy Mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Nunito',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Use local models only',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: AppTheme.isPrivacyMode,
                onChanged: (value) {
                  AppTheme.setPrivacyMode(value);
                  setState(() {});
                },
                activeColor: theme.colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
