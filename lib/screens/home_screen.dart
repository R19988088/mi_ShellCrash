import 'package:flutter/material.dart';
import '../services/router_manager.dart';
import 'file_browser_screen.dart';
import 'clash_rules_screen.dart';
import 'diagnostics_screen.dart';
import 'test_read_screen.dart';

class HomeScreen extends StatefulWidget {
  final RouterManager manager;

  const HomeScreen({super.key, required this.manager});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _statusMessage = '正在获取状态...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClashStatus();
  }

  Future<void> _loadClashStatus() async {
    try {
      final status = await widget.manager.getClashStatus();
      setState(() {
        _statusMessage = status;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '无法获取状态: $e';
      });
    }
  }

  Future<void> _executeClashCommand(
    String action,
    Future<String> Function() command,
  ) async {
    setState(() => _isLoading = true);

    try {
      final result = await command();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action成功: $result'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadClashStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openFileBrowser() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileBrowserScreen(
          manager: widget.manager,
          initialPath: '/data/ShellCrash/yamls',
        ),
      ),
    );
  }

  void _openDiagnostics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiagnosticsScreen(manager: widget.manager),
      ),
    );
  }

  void _openReadTest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestReadScreen(manager: widget.manager),
      ),
    );
  }

  void _disconnect() {
    widget.manager.disconnect();
    Navigator.of(context).pop();
  }

  PopupMenuButton<String> _buildToolsMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: '更多工具',
      onSelected: (value) {
        switch (value) {
          case 'files':
            _openFileBrowser();
            break;
          case 'command':
            _showCommandDialog();
            break;
          case 'diagnostics':
            _openDiagnostics();
            break;
          case 'test':
            _openReadTest();
            break;
          case 'disconnect':
            _disconnect();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'files',
          child: ListTile(leading: Icon(Icons.folder), title: Text('浏览配置文件')),
        ),
        PopupMenuItem(
          value: 'command',
          child: ListTile(
            leading: Icon(Icons.terminal),
            title: Text('执行自定义命令'),
          ),
        ),
        PopupMenuItem(
          value: 'diagnostics',
          child: ListTile(
            leading: Icon(Icons.medical_services),
            title: Text('系统诊断'),
          ),
        ),
        PopupMenuItem(
          value: 'test',
          child: ListTile(leading: Icon(Icons.bug_report), title: Text('读取测试')),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'disconnect',
          child: ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('断开连接', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clash 管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadClashStatus,
            tooltip: '刷新状态',
          ),
          _buildToolsMenu(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Clash 控制面板
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Clash 服务控制',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _executeClashCommand(
                                  '启动',
                                  widget.manager.startClash,
                                ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('启动', maxLines: 1, softWrap: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _executeClashCommand(
                                  '停止',
                                  widget.manager.stopClash,
                                ),
                          icon: const Icon(Icons.stop),
                          label: const Text('停止', maxLines: 1, softWrap: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _executeClashCommand(
                                  '重启',
                                  widget.manager.restartClash,
                                ),
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('重启', maxLines: 1, softWrap: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 状态显示
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        '服务状态',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 快速操作
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.rule, color: Colors.purple),
                  title: const Text('Clash 规则管理'),
                  subtitle: const Text('管理域名和关键字代理规则'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClashRulesScreen(manager: widget.manager),
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
  }

  void _showCommandDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('执行命令'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '输入命令...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final command = controller.text.trim();
              Navigator.pop(context);

              if (command.isEmpty) return;

              try {
                final result = await widget.manager.executeCommand(command);
                if (mounted) {
                  _showResultDialog('命令输出', result);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('执行失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('执行'),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            content,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
