import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../data/services/base_api_service.dart';

/// Connection status for server configuration
enum ConnectionStatus {
  unknown,
  testing,
  connected,
  disconnected,
}

/// A widget that displays and allows editing of the backend server configuration.
/// Used on both the login screen and settings screen.
class ServerConfigWidget extends StatefulWidget {
  /// Called when the server configuration is successfully saved
  final VoidCallback? onConfigSaved;

  /// If true, validates the auth token after connection test (for logged-in users)
  final bool validateAuthToken;

  /// Auth token to validate (required if validateAuthToken is true)
  final String? authToken;

  /// Called when auth token validation fails on the new server
  final VoidCallback? onAuthTokenInvalid;

  /// Whether to show in compact mode (single line with edit icon)
  final bool compact;

  const ServerConfigWidget({
    super.key,
    this.onConfigSaved,
    this.validateAuthToken = false,
    this.authToken,
    this.onAuthTokenInvalid,
    this.compact = false,
  });

  @override
  State<ServerConfigWidget> createState() => _ServerConfigWidgetState();
}

class _ServerConfigWidgetState extends State<ServerConfigWidget> {
  ConnectionStatus _status = ConnectionStatus.unknown;

  @override
  void initState() {
    super.initState();
    // Test connection to current server on init
    _testCurrentConnection();
  }

  Future<void> _testCurrentConnection() async {
    setState(() => _status = ConnectionStatus.testing);
    final connected = await BaseApiService.testCurrentConnection();
    if (mounted) {
      setState(() => _status = connected
          ? ConnectionStatus.connected
          : ConnectionStatus.disconnected);
    }
  }

  void _showConfigDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ServerConfigDialog(
        validateAuthToken: widget.validateAuthToken,
        authToken: widget.authToken,
        onSaved: () {
          _testCurrentConnection();
          widget.onConfigSaved?.call();
        },
        onAuthTokenInvalid: widget.onAuthTokenInvalid,
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color color;
    String tooltip;

    switch (_status) {
      case ConnectionStatus.connected:
        color = AppTheme.successGreen;
        tooltip = 'Connected';
        break;
      case ConnectionStatus.disconnected:
        color = AppTheme.errorRed;
        tooltip = 'Disconnected';
        break;
      case ConnectionStatus.testing:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(AppTheme.primaryElectricBlue),
          ),
        );
      case ConnectionStatus.unknown:
        color = AppTheme.warningOrange;
        tooltip = 'Unknown';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = AppConfig.currentHost;
    final port = AppConfig.currentPort;

    if (widget.compact) {
      return InkWell(
        onTap: _showConfigDialog,
        borderRadius: AppTheme.borderRadiusSmall,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIndicator(),
              const SizedBox(width: 8),
              Text(
                '$host:$port',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit,
                size: 14,
                color: AppTheme.secondaryText.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      );
    }

    // Full card view for settings screen
    return ClipRRect(
      borderRadius: AppTheme.borderRadiusMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderColor: Colors.white.withValues(alpha: 0.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.dns_outlined, color: AppTheme.primaryElectricBlue),
                  SizedBox(width: 12),
                  Text('Server Configuration', style: AppTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Host: ', style: AppTheme.bodyMedium),
                            Text(host, style: AppTheme.bodyLarge),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Port: ', style: AppTheme.bodyMedium),
                            Text('$port', style: AppTheme.bodyLarge),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Status: ', style: AppTheme.bodyMedium),
                            const SizedBox(width: 8),
                            _buildStatusIndicator(),
                            const SizedBox(width: 8),
                            Text(
                              _status == ConnectionStatus.connected
                                  ? 'Connected'
                                  : _status == ConnectionStatus.disconnected
                                      ? 'Disconnected'
                                      : _status == ConnectionStatus.testing
                                          ? 'Testing...'
                                          : 'Unknown',
                              style: AppTheme.bodyMedium.copyWith(
                                color: _status == ConnectionStatus.connected
                                    ? AppTheme.successGreen
                                    : _status == ConnectionStatus.disconnected
                                        ? AppTheme.errorRed
                                        : AppTheme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        onPressed: _testCurrentConnection,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Test Connection',
                        color: AppTheme.primaryElectricBlue,
                      ),
                      IconButton(
                        onPressed: _showConfigDialog,
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit',
                        color: AppTheme.primaryElectricBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for editing server configuration
class _ServerConfigDialog extends StatefulWidget {
  final bool validateAuthToken;
  final String? authToken;
  final VoidCallback? onSaved;
  final VoidCallback? onAuthTokenInvalid;

  const _ServerConfigDialog({
    required this.validateAuthToken,
    this.authToken,
    this.onSaved,
    this.onAuthTokenInvalid,
  });

  @override
  State<_ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<_ServerConfigDialog> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _connectionTested = false;
  bool _connectionSuccessful = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: AppConfig.currentHost);
    _portController =
        TextEditingController(text: AppConfig.currentPort.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  bool _isValidHost(String host) {
    if (host.isEmpty) return false;
    // Basic IP address or hostname validation
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final hostnameRegex = RegExp(
        r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$');
    return ipRegex.hasMatch(host) || hostnameRegex.hasMatch(host);
  }

  bool _isValidPort(String portStr) {
    final port = int.tryParse(portStr);
    return port != null && port > 0 && port <= 65535;
  }

  Future<void> _testConnection() async {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();

    if (!_isValidHost(host)) {
      setState(() {
        _errorMessage = 'Invalid host address';
        _connectionTested = true;
        _connectionSuccessful = false;
      });
      return;
    }

    if (!_isValidPort(portStr)) {
      setState(() {
        _errorMessage = 'Invalid port (1-65535)';
        _connectionTested = true;
        _connectionSuccessful = false;
      });
      return;
    }

    final port = int.parse(portStr);

    setState(() {
      _isTesting = true;
      _errorMessage = null;
    });

    final connected = await BaseApiService.testConnection(host, port);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _connectionTested = true;
        _connectionSuccessful = connected;
        _errorMessage = connected ? null : 'Could not connect to server';
      });
    }
  }

  Future<void> _save() async {
    if (!_connectionSuccessful) return;

    final host = _hostController.text.trim();
    final port = int.parse(_portController.text.trim());

    setState(() => _isSaving = true);

    // If user is logged in, validate their token on the new server
    if (widget.validateAuthToken && widget.authToken != null) {
      final tokenValid = await BaseApiService.validateAuthToken(
        host,
        port,
        widget.authToken!,
      );

      if (!tokenValid) {
        if (mounted) {
          setState(() => _isSaving = false);
          // Show warning dialog
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.borderRadiusMedium,
              ),
              title: const Text('Session Invalid', style: AppTheme.titleLarge),
              content: const Text(
                'Your session is not valid on this server. You will need to log in again after changing the server.',
                style: AppTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          );

          if (proceed != true) return;

          widget.onAuthTokenInvalid?.call();
        }
      }
    }

    // Save the new configuration
    await AppConfig.setBackendHost(host);
    await AppConfig.setBackendPort(port);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      widget.onSaved?.call();
    }
  }

  Future<void> _resetToDefault() async {
    await AppConfig.clearBackendConfig();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.dns_outlined,
                    color: AppTheme.primaryElectricBlue),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Server Configuration',
                      style: AppTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: AppTheme.secondaryText,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Host input
            TextField(
              controller: _hostController,
              style: AppTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Host / IP Address',
                labelStyle: AppTheme.bodyMedium,
                hintText: '192.168.1.100',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.secondaryText.withValues(alpha: 0.5),
                ),
                prefixIcon: const Icon(Icons.computer,
                    color: AppTheme.primaryElectricBlue),
              ),
              onChanged: (_) {
                setState(() {
                  _connectionTested = false;
                  _connectionSuccessful = false;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Port input
            TextField(
              controller: _portController,
              style: AppTheme.bodyLarge,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Port',
                labelStyle: AppTheme.bodyMedium,
                hintText: '8000',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.secondaryText.withValues(alpha: 0.5),
                ),
                prefixIcon: const Icon(Icons.numbers,
                    color: AppTheme.primaryElectricBlue),
              ),
              onChanged: (_) {
                setState(() {
                  _connectionTested = false;
                  _connectionSuccessful = false;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.errorRed, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _errorMessage!,
                      style:
                          AppTheme.bodySmall.copyWith(color: AppTheme.errorRed),
                    ),
                  ],
                ),
              ),

            // Success message
            if (_connectionTested && _connectionSuccessful)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppTheme.successGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Connection successful!',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.successGreen),
                    ),
                  ],
                ),
              ),

            // Action buttons
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Reset button
                TextButton(
                  onPressed: _resetToDefault,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    'Reset',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.secondaryText),
                  ),
                ),
                // Test and Save buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Test button
                    OutlinedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering, size: 18),
                      label: Text(_isTesting ? 'Testing...' : 'Test'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryElectricBlue,
                        side:
                            const BorderSide(color: AppTheme.primaryElectricBlue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Save button
                    ElevatedButton(
                      onPressed:
                          (_connectionSuccessful && !_isSaving) ? _save : null,
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
