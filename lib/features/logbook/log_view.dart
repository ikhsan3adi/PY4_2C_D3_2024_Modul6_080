import 'package:flutter/material.dart';
import 'package:logbook_app_080/features/logbook/log_controller.dart';
import 'package:logbook_app_080/features/logbook/log_detail_view.dart';
import 'package:logbook_app_080/features/logbook/log_editor_page.dart';
import 'package:logbook_app_080/features/logbook/models/log_model.dart';
import 'package:logbook_app_080/features/logbook/widgets/log_item_widget.dart';
import 'package:logbook_app_080/features/onboarding/onboarding_view.dart';
import 'package:logbook_app_080/features/vision/vision_view.dart';
import 'package:logbook_app_080/helpers/log_helper.dart';
import 'package:logbook_app_080/services/access_control_service.dart';
import 'package:logbook_app_080/services/connectivity_service.dart';
import 'package:logbook_app_080/services/mongo_service.dart';
import 'package:lottie/lottie.dart';

class LogView extends StatefulWidget {
  final Map<String, String> currentUser;
  const LogView({super.key, required this.currentUser});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final LogController _controller;
  late final ConnectivityService _connectivityService;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  String get _username => widget.currentUser['username'] ?? '';
  String get _role => widget.currentUser['role'] ?? 'Anggota';
  String get _authorId => widget.currentUser['authorId'] ?? '';

  @override
  void initState() {
    super.initState();
    _controller = LogController(
      username: _username,
      authorId: _authorId,
      teamId: widget.currentUser['teamId'] ?? 'no_team',
      userRole: _role,
    );

    _connectivityService = ConnectivityService(
      onReconnected: () async {
        if (mounted) {
          await _controller.loadLogs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Koneksi pulih. Data berhasil disinkronkan.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      },
    );
    _connectivityService.initialize();

    Future.microtask(() => _initDatabase());
  }

  Future<void> _initDatabase() async {
    setState(() => _isLoading = true);
    _controller.loadOfflineLogs();

    try {
      await LogHelper.writeLog(
        'UI: Memulai inisialisasi database...',
        source: 'log_view.dart',
      );

      await MongoService().connect().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Koneksi Cloud Timeout.'),
      );

      await _controller.loadLogs();

      await LogHelper.writeLog(
        'UI: Data berhasil dimuat ke Notifier.',
        source: 'log_view.dart',
      );
    } catch (e) {
      await LogHelper.writeLog(
        'UI: Error - $e',
        source: 'log_view.dart',
        level: 1,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sistem berjalan dalam mode offline (Gagal terhubung ke database)',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _connectivityService.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _goToEditor({LogModel? log, int? index}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(LogModel targetLog) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus catatan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _controller.removeLog(targetLog);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Catatan dihapus')),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logbook Proyek'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Smart Patrol Vision',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VisionView(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OnboardingView(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'Ya, Keluar',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $_username 👋',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            _role,
                            style: TextStyle(
                              fontSize: 11,
                              color: _role == 'Ketua'
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _role == 'Ketua'
                              ? Colors.indigo
                              : Colors.grey.shade200,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 12),
                        ValueListenableBuilder<bool>(
                          valueListenable: _connectivityService.isOnline,
                          builder: (context, online, _) {
                            return Tooltip(
                              message: online
                                  ? 'Tersinkron ke Cloud'
                                  : 'Mode Offline',
                              child: Row(
                                children: [
                                  Icon(
                                    online ? Icons.cloud_done : Icons.cloud_off,
                                    color: online
                                        ? Colors.green
                                        : Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    online ? 'Online' : 'Offline',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: online
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    _username.isNotEmpty
                        ? _username.substring(0, 2).toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (value) => _controller.searchLog(value),
              decoration: InputDecoration(
                labelText: 'Cari Catatan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: ValueListenableBuilder<List<LogModel>>(
                  valueListenable: _controller.filteredLogs,
                  builder: (context, _, child) {
                    if (_searchController.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _controller.searchLog('');
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<List<LogModel>>(
                valueListenable: _controller.filteredLogs,
                builder: (context, currentLogs, child) {
                  if (_isLoading) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Menghubungkan ke Database...'),
                        ],
                      ),
                    );
                  }

                  if (currentLogs.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => _controller.loadLogs(),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Lottie.asset(
                                    'assets/lottie/empty_state.json',
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada aktivitas hari ini?',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => _goToEditor(),
                                    child: const Text('Buat Catatan Pertama'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => _controller.loadLogs(),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 80),
                      itemCount: currentLogs.length,
                      itemBuilder: (context, index) {
                        final log = currentLogs[index];

                        final bool isOwner = log.authorId == _authorId;

                        final bool canEdit = AccessControlService.canPerform(
                          _role,
                          AccessControlService.actionUpdate,
                          isOwner: isOwner,
                        );
                        final bool canDelete = AccessControlService.canPerform(
                          _role,
                          AccessControlService.actionDelete,
                          isOwner: isOwner,
                        );

                        return LogItemWidget(
                          log: log,
                          canEdit: canEdit,
                          canDelete: canDelete,
                          onTapAction: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LogDetailView(
                                  log: log,
                                  canEdit: canEdit,
                                  onEditPressed: () async {
                                    final isSaved = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LogEditorPage(
                                          log: log,
                                          index: index,
                                          controller: _controller,
                                          currentUser: widget.currentUser,
                                        ),
                                      ),
                                    );

                                    if (isSaved == true && context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                          editAction: (log) =>
                              _goToEditor(log: log, index: index),
                          deleteAction: (_) => _showDeleteConfirmation(log),
                          swipeToLeftAction: () async {
                            _showDeleteConfirmation(log);
                            return null;
                          },
                          swipeToRightAction: () async {
                            _goToEditor(log: log, index: index);
                            return null;
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
