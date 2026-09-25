import 'package:yaml/yaml.dart';
import 'router_manager.dart';

class ClashRule {
  final String type; // DOMAIN, DOMAIN-SUFFIX, DOMAIN-KEYWORD
  final String content; // 域名或关键字
  final String policy; // DIRECT, PROXY, REJECT

  ClashRule({
    required this.type,
    required this.content,
    required this.policy,
  });

  String toRuleString() {
    return '$type,$content,$policy';
  }

  static ClashRule? fromRuleString(String rule) {
    final parts = rule.split(',');
    if (parts.length >= 3) {
      return ClashRule(
        type: parts[0].trim(),
        content: parts[1].trim(),
        policy: parts[2].trim(),
      );
    }
    return null;
  }
}

class ClashConfigManager {
  final RouterManager routerManager;
  String? configPath;
  String? _configContent;

  ClashConfigManager(this.routerManager);

  // 自动查找 Clash 配置文件
  Future<String> findClashConfig() async {
    final possiblePaths = [
      // ShellCrash 路径（优先）
      '/data/ShellCrash/yamls/rules.yaml',
      '/data/ShellCrash/yamls/config.yaml',
      '/tmp/ShellCrash/config.yaml',
      // 标准 Clash 路径
      '/etc/clash/config.yaml',
      '/etc/clash/config.yml',
      '/etc/storage/clash/config.yaml',
      '/etc/storage/clash/config.yml',
      '/jffs/clash/config.yaml',
      '/jffs/clash/config.yml',
      '/opt/clash/config.yaml',
      '/opt/clash/config.yml',
      '/usr/local/clash/config.yaml',
      '/usr/local/clash/config.yml',
      '/root/.config/clash/config.yaml',
      '/root/.config/clash/config.yml',
    ];

    final List<String> triedPaths = [];
    final List<String> errors = [];
    
    // 尝试常见路径
    for (final path in possiblePaths) {
      try {
        triedPaths.add(path);
        print('尝试读取: $path');
        final content = await routerManager.readFile(path);
        print('成功读取: $path, 长度: ${content.length}');
        if (content.isNotEmpty) {
          configPath = path;
          print('✅ 找到配置文件: $path');
          return path;
        } else {
          print('⚠️ 文件为空: $path');
        }
      } catch (e) {
        final error = '❌ $path: ${e.toString()}';
        print(error);
        errors.add(error);
      }
    }

    print('所有常规路径都失败了，尝试搜索命令...');

    // 如果都找不到，尝试多种搜索方式
    final searchCommands = [
      'find /data -name "rules.yaml" 2>/dev/null | head -1',
      'find /etc /opt /usr /jffs /root -name "config.yaml" -o -name "config.yml" 2>/dev/null | grep clash | head -1',
      'find / -name "config.yaml" 2>/dev/null | grep clash | head -1',
      'ls /data/ShellCrash/yamls/*.yaml 2>/dev/null | head -1',
    ];

    for (final cmd in searchCommands) {
      try {
        print('执行搜索: $cmd');
        final result = await routerManager.executeCommand(cmd);
        final foundPath = result.trim().split('\n').first;
        print('搜索结果: $foundPath');
        if (foundPath.isNotEmpty && !foundPath.startsWith('find:') && !foundPath.startsWith('ls:')) {
          configPath = foundPath;
          print('✅ 通过搜索找到: $foundPath');
          return foundPath;
        }
      } catch (e) {
        print('搜索失败: $e');
      }
    }

    // 提供详细的诊断信息
    final errorMsg = '''
未找到 Clash 配置文件

已尝试的路径：
${triedPaths.take(8).join('\n')}
...等 ${triedPaths.length} 个路径

错误详情（前5个）：
${errors.take(5).join('\n')}

建议操作：
1. 如果使用 ShellCrash，配置文件通常在：
   /data/ShellCrash/yamls/rules.yaml
   
2. 使用"执行自定义命令"运行：
   ls -la /data/ShellCrash/yamls/
   
3. 找到配置文件后，点击"手动指定路径"''';

    print(errorMsg);
    throw Exception(errorMsg);
  }

  // 读取配置文件
  Future<void> loadConfig() async {
    if (configPath == null) {
      print('configPath 为空，调用 findClashConfig');
      await findClashConfig();
    }
    print('准备读取配置文件: $configPath');
    try {
      _configContent = await routerManager.readFile(configPath!);
      print('✅ 配置文件读取成功，内容长度: ${_configContent?.length ?? 0} 字节');
      if (_configContent != null && _configContent!.isNotEmpty) {
        print('配置文件前100个字符: ${_configContent!.substring(0, _configContent!.length > 100 ? 100 : _configContent!.length)}');
      }
    } catch (e) {
      print('❌ 读取配置文件失败: $e');
      throw Exception('无法读取配置文件 $configPath: $e');
    }
  }

  // 获取所有规则
  List<ClashRule> getRules() {
    if (_configContent == null) return [];

    final lines = _configContent!.split('\n');
    final rules = <ClashRule>[];
    bool inRulesSection = false;

    for (var line in lines) {
      final trimmed = line.trim();
      
      // 跳过空行和注释
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // 检查是否是 rules: 标记（标准 Clash 格式）
      if (trimmed.startsWith('rules:')) {
        inRulesSection = true;
        continue;
      }

      // 如果遇到不是列表项的行，说明 rules 部分结束（标准格式）
      if (inRulesSection && !trimmed.startsWith('-') && !trimmed.startsWith('#')) {
        break;
      }

      // 解析规则行（支持标准格式和 ShellCrash 格式）
      if (trimmed.startsWith('-')) {
        final ruleStr = trimmed.substring(1).trim();
        final rule = ClashRule.fromRuleString(ruleStr);
        if (rule != null && 
            (rule.type == 'DOMAIN' || 
             rule.type == 'DOMAIN-SUFFIX' || 
             rule.type == 'DOMAIN-KEYWORD')) {
          rules.add(rule);
        }
      }
    }

    return rules;
  }

  // 获取域名规则
  List<ClashRule> getDomainRules() {
    return getRules().where((rule) => 
      rule.type == 'DOMAIN' || rule.type == 'DOMAIN-SUFFIX'
    ).toList();
  }

  // 获取关键字规则
  List<ClashRule> getKeywordRules() {
    return getRules().where((rule) => 
      rule.type == 'DOMAIN-KEYWORD'
    ).toList();
  }

  // 添加规则
  Future<void> addRule(ClashRule rule) async {
    if (_configContent == null) {
      await loadConfig();
    }

    final lines = _configContent!.split('\n');
    final newLines = <String>[];
    bool rulesAdded = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // 在 rules: 部分的开头添加新规则（标准格式）
      if (line.trim().startsWith('rules:') && !rulesAdded) {
        newLines.add(line);
        newLines.add('  - ${rule.toRuleString()}');
        rulesAdded = true;
        continue;
      }
      
      // 如果没有 rules: 标记，在第一个规则行之前添加（ShellCrash 格式）
      if (!rulesAdded && line.trim().startsWith('-')) {
        newLines.add('- ${rule.toRuleString()}');
        rulesAdded = true;
      }
      
      newLines.add(line);
    }
    
    // 如果文件完全没有规则，直接追加
    if (!rulesAdded) {
      newLines.add('- ${rule.toRuleString()}');
    }

    _configContent = newLines.join('\n');
  }

  // 更新规则（替换规则，保持位置不变）
  Future<void> updateRule(ClashRule oldRule, ClashRule newRule) async {
    if (_configContent == null) {
      await loadConfig();
    }

    final oldRuleString = oldRule.toRuleString();
    final newRuleString = newRule.toRuleString();
    final lines = _configContent!.split('\n');
    final newLines = <String>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('-')) {
        final ruleStr = trimmed.substring(1).trim();
        if (ruleStr == oldRuleString) {
          // 替换规则，保持原来的缩进
          final indent = line.substring(0, line.indexOf('-'));
          newLines.add('$indent- $newRuleString');
        } else {
          newLines.add(line);
        }
      } else {
        newLines.add(line);
      }
    }

    _configContent = newLines.join('\n');
  }
  Future<void> deleteRule(ClashRule rule) async {
    if (_configContent == null) {
      await loadConfig();
    }

    final ruleString = rule.toRuleString();
    final lines = _configContent!.split('\n');
    final newLines = <String>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('-')) {
        final ruleStr = trimmed.substring(1).trim();
        if (ruleStr != ruleString) {
          newLines.add(line);
        }
      } else {
        newLines.add(line);
      }
    }

    _configContent = newLines.join('\n');
  }

  // 保存配置文件（带自动备份）
  Future<void> saveConfig() async {
    if (configPath == null || _configContent == null) {
      throw Exception('配置文件未加载');
    }
    
    // 1. 创建备份
    await _createBackup();
    
    // 2. 保存新配置
    await routerManager.writeFile(configPath!, _configContent!);
  }

  // 创建备份并管理备份数量
  Future<void> _createBackup() async {
    if (configPath == null) return;
    
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final backupPath = '$configPath.backup.$timestamp';
      
      // 复制当前文件到备份
      await routerManager.executeCommand('cp "$configPath" "$backupPath"');
      
      // 清理旧备份，只保留最近5个
      final backupDir = configPath!.substring(0, configPath!.lastIndexOf('/'));
      final fileName = configPath!.substring(configPath!.lastIndexOf('/') + 1);
      
      // 列出所有备份文件，按时间排序
      final listCmd = 'ls -t "$backupDir"/$fileName.backup.* 2>/dev/null || true';
      final backupList = await routerManager.executeCommand(listCmd);
      
      if (backupList.isNotEmpty) {
        final backups = backupList.split('\n').where((line) => line.trim().isNotEmpty).toList();
        
        // 如果超过5个，删除旧的
        if (backups.length > 5) {
          for (var i = 5; i < backups.length; i++) {
            await routerManager.executeCommand('rm "${backups[i]}"');
          }
        }
      }
    } catch (e) {
      // 备份失败不影响保存操作，只记录日志
      print('备份失败: $e');
    }
  }

  // 重启 Clash
  Future<String> restartClash() async {
    return await routerManager.restartClash();
  }
}
