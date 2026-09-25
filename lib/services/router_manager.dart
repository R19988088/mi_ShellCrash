import 'package:dartssh2/dartssh2.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../models/router_config.dart';

class RouterManager {
  SSHClient? _client;
  SftpClient? _sftp;
  final SSHConfig config;

  RouterManager(this.config);

  bool get isConnected => _client != null;

  // 连接到路由器
  Future<void> connect() async {
    try {
      final socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 10),
      );
      _client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => config.password,
      );
      _sftp = await _client!.sftp();
    } catch (e) {
      disconnect();
      // 提供更详细的错误信息
      if (e.toString().contains('timeout')) {
        throw Exception('连接超时，请检查 IP 地址和端口是否正确');
      } else if (e.toString().contains('Connection refused')) {
        throw Exception('连接被拒绝，请确认 SSH 服务已启动');
      } else if (e.toString().contains('AuthFail') || e.toString().contains('authentication')) {
        throw Exception('认证失败，请检查用户名和密码是否正确');
      } else if (e.toString().contains('No route to host')) {
        throw Exception('无法连接到主机，请检查 IP 地址和网络连接');
      }
      rethrow;
    }
  }

  // 列出目录内容
  Future<List<SftpName>> listFiles(String path) async {
    if (_sftp == null) throw Exception('未连接到路由器');
    try {
      return await _sftp!.listdir(path);
    } catch (e) {
      throw Exception('无法列出目录: $e');
    }
  }

  // 读取文件内容（使用 cat 命令，避免 SFTP 超时）
  Future<String> readFile(String remotePath) async {
    if (_client == null) throw Exception('未连接到路由器');
    try {
      // 使用 cat 命令读取文件内容
      final result = await executeCommand('cat "$remotePath"');
      return result;
    } catch (e) {
      throw Exception('无法读取文件: $e');
    }
  }

  // 写入文件内容（使用命令，避免 SFTP 超时）
  Future<void> writeFile(String remotePath, String content) async {
    if (_client == null) throw Exception('未连接到路由器');
    try {
      // 转义内容中的特殊字符
      final escapedContent = content
          .replaceAll('\\', '\\\\')
          .replaceAll('\$', '\\\$')
          .replaceAll('"', '\\"')
          .replaceAll('`', '\\`');
      
      // 使用 echo 写入文件（对于小文件）
      // 如果文件很大，分块写入
      if (content.length < 50000) {
        await executeCommand('echo "$escapedContent" > "$remotePath"');
      } else {
        // 大文件：先清空，然后追加
        await executeCommand('> "$remotePath"');
        final lines = content.split('\n');
        final buffer = StringBuffer();
        
        for (var i = 0; i < lines.length; i++) {
          buffer.writeln(lines[i]);
          
          // 每1000行或最后一批写入一次
          if ((i + 1) % 1000 == 0 || i == lines.length - 1) {
            final chunk = buffer.toString()
                .replaceAll('\\', '\\\\')
                .replaceAll('\$', '\\\$')
                .replaceAll('"', '\\"')
                .replaceAll('`', '\\`');
            await executeCommand('echo "$chunk" >> "$remotePath"');
            buffer.clear();
          }
        }
      }
    } catch (e) {
      throw Exception('无法写入文件: $e');
    }
  }

  // 删除文件
  Future<void> deleteFile(String remotePath) async {
    if (_sftp == null) throw Exception('未连接到路由器');
    try {
      await _sftp!.remove(remotePath);
    } catch (e) {
      throw Exception('无法删除文件: $e');
    }
  }

  // 创建目录
  Future<void> createDirectory(String remotePath) async {
    if (_sftp == null) throw Exception('未连接到路由器');
    try {
      await _sftp!.mkdir(remotePath);
    } catch (e) {
      throw Exception('无法创建目录: $e');
    }
  }

  // 执行命令
  Future<String> executeCommand(String command) async {
    if (_client == null) throw Exception('未连接到路由器');
    try {
      final session = await _client!.execute(command);
      final output = await session.stdout.map((data) => String.fromCharCodes(data)).join();
      final error = await session.stderr.map((data) => String.fromCharCodes(data)).join();
      return output.isNotEmpty ? output : error;
    } catch (e) {
      throw Exception('命令执行失败: $e');
    }
  }

  // 重启 Clash
  Future<String> restartClash() async {
    try {
      // 尝试多种重启方式
      var result = await executeCommand('systemctl restart clash');
      if (result.contains('not found') || result.contains('Failed')) {
        result = await executeCommand('/etc/init.d/clash restart');
      }
      if (result.contains('not found') || result.contains('Failed')) {
        result = await executeCommand('service clash restart');
      }
      return result;
    } catch (e) {
      throw Exception('重启 Clash 失败: $e');
    }
  }

  // 停止 Clash
  Future<String> stopClash() async {
    try {
      var result = await executeCommand('systemctl stop clash');
      if (result.contains('not found') || result.contains('Failed')) {
        result = await executeCommand('/etc/init.d/clash stop');
      }
      if (result.contains('not found') || result.contains('Failed')) {
        result = await executeCommand('service clash stop');
      }
      return result;
    } catch (e) {
      throw Exception('停止 Clash 失败: $e');
    }
  }

  // 启动 Clash
  Future<String> startClash() async {
    try {
      var result = await executeCommand('systemctl start clash');
      if (result.contains('not found') || result.contains('Failed')) {
        result = await executeCommand('/etc/init.d/clash start');
      }
      if (result.contains('not found') || result.contains('Failed')) {
        result = await executeCommand('service clash start');
      }
      return result;
    } catch (e) {
      throw Exception('启动 Clash 失败: $e');
    }
  }

  // 查看 Clash 状态
  Future<String> getClashStatus() async {
    try {
      var result = await executeCommand('systemctl status clash');
      if (result.contains('not found')) {
        result = await executeCommand('/etc/init.d/clash status');
      }
      if (result.contains('not found')) {
        result = await executeCommand('ps | grep clash');
      }
      return result;
    } catch (e) {
      throw Exception('获取状态失败: $e');
    }
  }

  // 断开连接
  void disconnect() {
    _sftp?.close();
    _client?.close();
    _sftp = null;
    _client = null;
  }
}
