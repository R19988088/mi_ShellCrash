import 'package:flutter/material.dart';
import '../services/router_manager.dart';
import '../services/clash_config_manager.dart';

class ClashRulesScreen extends StatefulWidget {
  final RouterManager manager;

  const ClashRulesScreen({super.key, required this.manager});

  @override
  State<ClashRulesScreen> createState() => _ClashRulesScreenState();
}

class _ClashRulesScreenState extends State<ClashRulesScreen> with SingleTickerProviderStateMixin {
  late ClashConfigManager _clashManager;
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _configPath;
  
  List<ClashRule> _domainRules = [];
  List<ClashRule> _keywordRules = [];

  @override
  void initState() {
    super.initState();
    _clashManager = ClashConfigManager(widget.manager);
    _tabController = TabController(length: 2, vsync: this);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('开始查找配置文件...');
      final path = await _clashManager.findClashConfig();
      print('找到配置文件: $path');
      
      await _clashManager.loadConfig();
      print('配置文件加载成功');
      
      final allRules = _clashManager.getRules();
      print('解析到 ${allRules.length} 条规则');
      
      final domainRules = _clashManager.getDomainRules();
      final keywordRules = _clashManager.getKeywordRules();
      print('域名规则: ${domainRules.length}, 关键字规则: ${keywordRules.length}');
      
      setState(() {
        _configPath = path;
        _domainRules = domainRules;
        _keywordRules = keywordRules;
        _isLoading = false;
      });
      
      if (mounted && allRules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('配置文件已加载，但没有找到域名相关规则\n路径: $path'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('加载失败: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAndRestart() async {
    setState(() => _isSaving = true);

    try {
      await _clashManager.saveConfig();
      await _clashManager.restartClash();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存成功并已重启 Clash'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadConfig();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAddDomainDialog() {
    final controller = TextEditingController();
    String selectedType = 'DOMAIN-SUFFIX';
    String selectedPolicy = 'PROXY';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加域名规则'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '域名',
                  hintText: '例如: google.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: '规则类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'DOMAIN', child: Text('完整域名')),
                  DropdownMenuItem(value: 'DOMAIN-SUFFIX', child: Text('域名后缀')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedType = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPolicy,
                decoration: const InputDecoration(
                  labelText: '代理模式',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'DIRECT', child: Text('直连')),
                  DropdownMenuItem(value: 'PROXY', child: Text('代理')),
                  DropdownMenuItem(value: 'REJECT', child: Text('拒绝')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedPolicy = value!);
                },
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
                final domain = controller.text.trim();
                if (domain.isEmpty) return;

                Navigator.pop(context);

                final rule = ClashRule(
                  type: selectedType,
                  content: domain,
                  policy: selectedPolicy,
                );

                try {
                  await _clashManager.addRule(rule);
                  setState(() {
                    _domainRules = _clashManager.getDomainRules();
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('规则已添加，记得提交并重启')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('添加失败: $e')),
                    );
                  }
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddKeywordDialog() {
    final controller = TextEditingController();
    String selectedPolicy = 'PROXY';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加关键字规则'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '关键字',
                  hintText: '例如: google',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPolicy,
                decoration: const InputDecoration(
                  labelText: '代理模式',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'DIRECT', child: Text('直连')),
                  DropdownMenuItem(value: 'PROXY', child: Text('代理')),
                  DropdownMenuItem(value: 'REJECT', child: Text('拒绝')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedPolicy = value!);
                },
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
                final keyword = controller.text.trim();
                if (keyword.isEmpty) return;

                Navigator.pop(context);

                final rule = ClashRule(
                  type: 'DOMAIN-KEYWORD',
                  content: keyword,
                  policy: selectedPolicy,
                );

                try {
                  await _clashManager.addRule(rule);
                  setState(() {
                    _keywordRules = _clashManager.getKeywordRules();
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('规则已添加，记得提交并重启')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('添加失败: $e')),
                    );
                  }
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRule(ClashRule rule, bool isDomain) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除规则 "${rule.content}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _clashManager.deleteRule(rule);
      setState(() {
        if (isDomain) {
          _domainRules = _clashManager.getDomainRules();
        } else {
          _keywordRules = _clashManager.getKeywordRules();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('规则已删除，记得提交并重启')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  void _showManualPathDialog() {
    final controller = TextEditingController(text: _clashManager.configPath ?? '/etc/clash/config.yaml');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('指定配置文件路径'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '请输入 Clash 配置文件的完整路径',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '配置文件路径',
                hintText: '/etc/clash/config.yaml',
                border: OutlineInputBorder(),
              ),
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
              final path = controller.text.trim();
              Navigator.pop(context);
              
              if (path.isEmpty) return;

              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });

              try {
                _clashManager.configPath = path;
                await _clashManager.loadConfig();
                
                setState(() {
                  _configPath = path;
                  _domainRules = _clashManager.getDomainRules();
                  _keywordRules = _clashManager.getKeywordRules();
                  _isLoading = false;
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('配置文件加载成功'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  _errorMessage = '加载失败: $e';
                  _isLoading = false;
                });
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // PLACEHOLDER_FOR_MORE_METHODS

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clash 规则管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadConfig,
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'change_path') {
                _showManualPathDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_path',
                child: Row(
                  children: [
                    Icon(Icons.edit_location, size: 20),
                    SizedBox(width: 8),
                    Text('更改配置路径'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: _isLoading ? null : TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '域名规则 (${_domainRules.length})'),
            Tab(text: '关键字规则 (${_keywordRules.length})'),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _errorMessage != null ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadConfig,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showManualPathDialog,
                icon: const Icon(Icons.edit),
                label: const Text('手动指定路径'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '配置文件: $_configPath',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRulesList(_domainRules, true),
              _buildRulesList(_keywordRules, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRulesList(List<ClashRule> rules, bool isDomain) {
    if (rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有规则',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮添加',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: rules.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final rule = rules[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            rule.content,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 代理模式切换按钮
              InkWell(
                onTap: () => _cyclePolicyMode(rule, isDomain),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPolicyColor(rule.policy),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getPolicyName(rule.policy),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 删除按钮
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.red.shade400,
                onPressed: () => _deleteRule(rule, isDomain),
              ),
            ],
          ),
        );
      },
    );
  }

  // 循环切换代理模式：DIRECT -> PROXY -> REJECT -> DIRECT
  Future<void> _cyclePolicyMode(ClashRule rule, bool isDomain) async {
    String newPolicy;
    switch (rule.policy) {
      case 'DIRECT':
        newPolicy = 'PROXY';
        break;
      case 'PROXY':
        newPolicy = 'REJECT';
        break;
      default:
        newPolicy = 'DIRECT';
    }

    try {
      // 创建新规则
      final newRule = ClashRule(
        type: rule.type,
        content: rule.content,
        policy: newPolicy,
      );

      // 原地替换规则，保持位置不变
      await _clashManager.updateRule(rule, newRule);
      
      // 更新界面
      setState(() {
        if (isDomain) {
          _domainRules = _clashManager.getDomainRules();
        } else {
          _keywordRules = _clashManager.getKeywordRules();
        }
      });
    } catch (e) {
      print('切换模式失败: $e');
      // 失败时重新加载
      await _loadConfig();
    }
  }

  Color _getPolicyColor(String policy) {
    switch (policy) {
      case 'DIRECT':
        return Colors.green;
      case 'PROXY':
        return Colors.blue;
      case 'REJECT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_tabController.index == 0) {
                      _showAddDomainDialog();
                    } else {
                      _showAddKeywordDialog();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text(_tabController.index == 0 ? '添加域名规则' : '添加关键字规则'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAndRestart,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(
                _isSaving ? '提交中...' : '提交并重启 Clash',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPolicyName(String policy) {
    switch (policy) {
      case 'DIRECT':
        return '直连';
      case 'PROXY':
        return '代理';
      case 'REJECT':
        return '拒绝';
      default:
        return policy;
    }
  }

  // PLACEHOLDER_FOR_BUILD_METHODS
}
