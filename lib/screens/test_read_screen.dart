import 'package:flutter/material.dart';
import '../services/router_manager.dart';
import '../services/clash_config_manager.dart';

class TestReadScreen extends StatefulWidget {
  final RouterManager manager;

  const TestReadScreen({super.key, required this.manager});

  @override
  State<TestReadScreen> createState() => _TestReadScreenState();
}

class _TestReadScreenState extends State<TestReadScreen> {
  String _result = '准备测试...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testRead();
  }

  Future<void> _testRead() async {
    setState(() {
      _isLoading = true;
    });

    final testPath = '/data/ShellCrash/yamls/rules.yaml';
    final logs = <String>[];
    
    try {
      logs.add('测试路径: $testPath');
      logs.add('');
      
      // 测试 1: 使用 cat 命令读取（绕过 SFTP）
      logs.add('=== 测试 1: 使用 cat 命令读取 ===');
      final content = await widget.manager.executeCommand('cat $testPath').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('命令超时（10秒）');
        },
      );
      logs.add('✅ 读取成功！');
      logs.add('文件长度: ${content.length} 字符');
      
      final preview = content.length > 300 ? content.substring(0, 300) : content;
      logs.add('前 300 个字符:');
      logs.add(preview);
      logs.add('');
      
      // 测试 2: 解析规则
      logs.add('=== 测试 2: 解析规则 ===');
      final lines = content.split('\n');
      int totalRules = 0;
      int domainRules = 0;
      int domainSuffixRules = 0;
      int keywordRules = 0;
      final sampleRules = <String>[];
      
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        
        if (trimmed.startsWith('-')) {
          final ruleStr = trimmed.substring(1).trim();
          final parts = ruleStr.split(',');
          if (parts.length >= 3) {
            totalRules++;
            if (parts[0].trim() == 'DOMAIN') domainRules++;
            if (parts[0].trim() == 'DOMAIN-SUFFIX') domainSuffixRules++;
            if (parts[0].trim() == 'DOMAIN-KEYWORD') keywordRules++;
            
            if (sampleRules.length < 5) {
              sampleRules.add(ruleStr);
            }
          }
        }
      }
      
      logs.add('总规则数: $totalRules');
      logs.add('DOMAIN: $domainRules');
      logs.add('DOMAIN-SUFFIX: $domainSuffixRules');
      logs.add('DOMAIN-KEYWORD: $keywordRules');
      logs.add('');
      
      if (sampleRules.isNotEmpty) {
        logs.add('前 5 条规则示例:');
        for (var i = 0; i < sampleRules.length; i++) {
          logs.add('${i + 1}. ${sampleRules[i]}');
        }
        logs.add('');
      }
      
      logs.add('✅✅✅ 测试成功！ ✅✅✅');
      logs.add('');
      logs.add('结论: 使用命令读取可以成功，');
      logs.add('但 SFTP 读取会超时。');
      logs.add('需要改用命令方式读取配置文件。');
      
    } catch (e) {
      logs.add('');
      logs.add('❌ 测试失败: $e');
    }
    
    setState(() {
      _result = logs.join('\n');
      _isLoading = false;
    });
  }

  // 删除 _addLog 方法

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('读取测试'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _testRead,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SelectableText(
                _result,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}
