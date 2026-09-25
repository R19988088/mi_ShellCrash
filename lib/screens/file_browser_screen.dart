import 'package:flutter/material.dart';
import '../services/router_manager.dart';
import 'file_editor_screen.dart';

class FileBrowserScreen extends StatefulWidget {
  final RouterManager manager;
  final String initialPath;

  const FileBrowserScreen({
    super.key,
    required this.manager,
    required this.initialPath,
  });

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  late String _currentPath;
  List<RemoteFileEntry> _files = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final files = await widget.manager.listFiles(_currentPath);
      // 排序：目录在前，文件在后，按名称排序
      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.compareTo(b.name);
      });

      setState(() {
        _files = files.where((f) => !f.name.startsWith('.')).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToDirectory(String dirname) async {
    if (dirname == '..') {
      // 返回上级目录
      final parts = _currentPath.split('/');
      if (parts.length > 2) {
        parts.removeLast();
        _currentPath = parts.join('/');
      } else {
        _currentPath = '/';
      }
    } else {
      // 进入子目录
      if (_currentPath.endsWith('/')) {
        _currentPath = '$_currentPath$dirname';
      } else {
        _currentPath = '$_currentPath/$dirname';
      }
    }
    await _loadFiles();
  }

  Future<void> _openFile(String filename) async {
    final filePath = _currentPath.endsWith('/')
        ? '$_currentPath$filename'
        : '$_currentPath/$filename';

    // 导航到编辑器
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FileEditorScreen(manager: widget.manager, filePath: filePath),
      ),
    );

    // 如果文件被修改，刷新列表
    if (result == true) {
      await _loadFiles();
    }
  }

  Future<void> _deleteFile(String filename) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "$filename" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final filePath = _currentPath.endsWith('/')
          ? '$_currentPath$filename'
          : '$_currentPath/$filename';
      await widget.manager.deleteFile(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功'), backgroundColor: Colors.green),
        );
        await _loadFiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateDialog() {
    final controller = TextEditingController();
    bool isDirectory = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新建'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '输入名称...',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('创建目录'),
                value: isDirectory,
                onChanged: (value) {
                  setDialogState(() {
                    isDirectory = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
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
                final name = controller.text.trim();
                Navigator.pop(context);

                if (name.isEmpty) return;

                final path = _currentPath.endsWith('/')
                    ? '$_currentPath$name'
                    : '$_currentPath/$name';

                try {
                  if (isDirectory) {
                    await widget.manager.createDirectory(path);
                  } else {
                    await widget.manager.writeFile(path, '');
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${isDirectory ? "目录" : "文件"}创建成功'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _loadFiles();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('创建失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadFiles,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
            tooltip: '新建',
          ),
        ],
      ),
      body: Column(
        children: [
          // 当前路径
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                const Icon(Icons.folder_open, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPath,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 文件列表
          Expanded(child: _buildFileList()),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return const Center(
        child: Text('目录为空', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: _files.length + (_currentPath != '/' ? 1 : 0),
      itemBuilder: (context, index) {
        // 添加返回上级目录选项
        if (_currentPath != '/' && index == 0) {
          return ListTile(
            leading: const Icon(Icons.arrow_upward, color: Colors.blue),
            title: const Text('..'),
            subtitle: const Text('返回上级目录'),
            onTap: () => _navigateToDirectory('..'),
          );
        }

        final fileIndex = _currentPath != '/' ? index - 1 : index;
        final file = _files[fileIndex];
        final isDirectory = file.isDirectory;

        return ListTile(
          leading: Icon(
            isDirectory ? Icons.folder : Icons.insert_drive_file,
            color: isDirectory ? Colors.blue : Colors.grey,
          ),
          title: Text(file.name),
          subtitle: Text(isDirectory ? '目录' : _formatFileSize(file.size)),
          trailing: !isDirectory
              ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteFile(file.name);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('删除'),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
          onTap: () {
            if (isDirectory) {
              _navigateToDirectory(file.name);
            } else {
              _openFile(file.name);
            }
          },
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
