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
          SnackBar(
            content: Text('$action失败: $e'),
            backgroundColor: Colors.red,
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Clash 控制面板
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                          label: const Text('启动'),
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
                          label: const Text('停止'),
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
                          label: const Text('重启'),
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
                        builder: (context) => ClashRulesScreen(
                          manager: widget.manager,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder, color: Colors.blue),
                  title: const Text('浏览配置文件'),
                  subtitle: const Text('高级：直接编辑配置文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FileBrowserScreen(
                          manager: widget.manager,
                          initialPath: '/etc/clash',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.terminal, color: Colors.green),
                  title: const Text('执行自定义命令'),
                  subtitle: const Text('在路由器上执行命令'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCommandDialog(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.medical_services, color: Colors.orange),
                  title: const Text('系统诊断'),
                  subtitle: const Text('检查权限和配置文件位置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiagnosticsScreen(
                          manager: widget.manager,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.purple),
                  title: const Text('读取测试'),
                  subtitle: const Text('测试 ShellCrash 配置读取'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TestReadScreen(
                          manager: widget.manager,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('断开连接'),
                  subtitle: const Text('返回登录界面'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    widget.manager.disconnect();
                    Navigator.of(context).pop();
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
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
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
