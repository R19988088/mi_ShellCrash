import 'package:flutter/material.dart';
import '../services/router_manager.dart';

class DiagnosticsScreen extends StatefulWidget {
  final RouterManager manager;

  const DiagnosticsScreen({super.key, required this.manager});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final List<Map<String, String>> _results = [];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    // 测试 1: 检查当前用户
    await _runTest('检查当前用户', 'whoami');

    // 测试 2: 检查用户权限
    await _runTest('检查用户 ID', 'id');

    // 测试 3: 查找 Clash 进程
    await _runTest('查找 Clash 进程', 'ps | grep -i clash | grep -v grep');

    // 测试 4: 查找 Clash 可执行文件
    await _runTest('查找 Clash 程序', 'which clash || find /usr /opt /bin /sbin -name clash -o -name "*clash*" 2>/dev/null | head -5');

    // 测试 5: 通过进程查找配置文件
    await _runTest('查看 Clash 启动参数', 'ps | grep clash | grep -v grep | head -1');

    // 测试 6: 搜索所有 yaml/yml 文件
    await _runTest('搜索所有 YAML 配置', 'find / -name "*.yaml" -o -name "*.yml" 2>/dev/null | head -10');

    // 测试 7: 检查常见目录
    await _runTest('检查 /etc 目录下的 clash 相关', 'ls -la /etc/ 2>&1 | grep -i clash');
    
    // 测试 8: 检查 /opt 目录
    await _runTest('检查 /opt 目录下的 clash 相关', 'ls -la /opt/ 2>&1 | grep -i clash');

    // 测试 9: 检查用户目录
    await _runTest('检查用户目录', 'ls -la ~/clash 2>&1 || ls -la ~/.config/clash 2>&1 || echo "用户目录下无 clash"');

    setState(() => _isRunning = false);
  }

  Future<void> _runTest(String name, String command) async {
    try {
      final result = await widget.manager.executeCommand(command);
      setState(() {
        _results.add({
          'name': name,
          'command': command,
          'result': result.isEmpty ? '(无输出)' : result,
          'status': 'success',
        });
      });
    } catch (e) {
      setState(() {
        _results.add({
          'name': name,
          'command': command,
          'result': e.toString(),
          'status': 'error',
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('诊断信息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runDiagnostics,
          ),
        ],
      ),
      body: _isRunning
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              result['status'] == 'success'
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: result['status'] == 'success'
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result['name']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '命令: ${result['command']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SelectableText(
                            result['result']!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
