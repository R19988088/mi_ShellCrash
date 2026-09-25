import 'package:dartssh2/dartssh2.dart';
import 'dart:convert';
import '../models/router_config.dart';

class RemoteFileEntry {
  final String name;
  final bool isDirectory;
  final int size;

  const RemoteFileEntry({
    required this.name,
    required this.isDirectory,
    required this.size,
  });
}

class RouterManager {
  SSHClient? _client;
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
    } catch (e) {
      disconnect();
      // 提供更详细的错误信息
      if (e.toString().contains('timeout')) {
        throw Exception('连接超时，请检查 IP 地址和端口是否正确');
      } else if (e.toString().contains('Connection refused')) {
        throw Exception('连接被拒绝，请确认 SSH 服务已启动');
      } else if (e.toString().contains('AuthFail') ||
          e.toString().contains('authentication')) {
        throw Exception('认证失败，请检查用户名和密码是否正确');
      } else if (e.toString().contains('No route to host')) {
        throw Exception('无法连接到主机，请检查 IP 地址和网络连接');
      }
      rethrow;
    }
  }

  // 使用 BusyBox 兼容的 find/printf 列出目录，避免 SFTP 卡住。
  Future<List<RemoteFileEntry>> listFiles(String path) async {
    if (_client == null) throw Exception('未连接到路由器');
    final quotedPath = _shellQuote(path);
    final command =
        "for item in $quotedPath/* $quotedPath/.[!.]* $quotedPath/..?*; do [ -e \"\$item\" ] || continue; if [ -d \"\$item\" ]; then type=D; size=0; else type=F; size=\$(wc -c < \"\$item\" 2>/dev/null || echo 0); fi; printf \"%s\\t%s\\t%s\\n\" \"\$type\" \"\$size\" \"\$item\"; done";
    final output = await _runCheckedCommand(command);
    final files = <RemoteFileEntry>[];

    for (final line in output.split('\n')) {
      final parts = line.split('\t');
      if (parts.length < 3) continue;
      final fullPath = parts.sublist(2).join('\t');
      final name = fullPath.substring(fullPath.lastIndexOf('/') + 1);
      if (name.isEmpty || name == '.' || name == '..') continue;
      files.add(
        RemoteFileEntry(
          name: name,
          isDirectory: parts[0] == 'D',
          size: int.tryParse(parts[1].trim()) ?? 0,
        ),
      );
    }
    return files;
  }

  // 读取文件内容（使用 cat 命令，避免 SFTP 超时）
  Future<String> readFile(String remotePath) async {
    if (_client == null) throw Exception('未连接到路由器');
    try {
      // 使用 SSH 命令读取文件内容
      return await _runCheckedCommand('cat ${_shellQuote(remotePath)}');
    } catch (e) {
      throw Exception('无法读取文件: $e');
    }
  }

  // 写入文件内容。Base64 可避免中文、换行和 Shell 特殊字符被破坏。
  Future<void> writeFile(String remotePath, String content) async {
    if (_client == null) throw Exception('未连接到路由器');
    try {
      final encoded = base64Encode(utf8.encode(content));
      final tempPath =
          '$remotePath.shellcrash.tmp.${DateTime.now().microsecondsSinceEpoch}';
      final quotedTempPath = _shellQuote(tempPath);
      final quotedRemotePath = _shellQuote(remotePath);

      await _runCheckedCommand('rm -f $quotedTempPath');
      for (var offset = 0; offset < encoded.length; offset += 24000) {
        final end = offset + 24000 < encoded.length
            ? offset + 24000
            : encoded.length;
        final chunk = encoded.substring(offset, end);
        await _runCheckedCommand("printf '%s' '$chunk' >> $quotedTempPath");
      }

      await _runCheckedCommand('base64 -d $quotedTempPath > $quotedRemotePath');
      await _runCheckedCommand('rm -f $quotedTempPath');
    } catch (e) {
      throw Exception('无法写入文件: $e');
    }
  }

  // 删除文件
  Future<void> deleteFile(String remotePath) async {
    await _runCheckedCommand('rm -f ${_shellQuote(remotePath)}');
  }

  // 创建目录
  Future<void> createDirectory(String remotePath) async {
    await _runCheckedCommand('mkdir -p ${_shellQuote(remotePath)}');
  }

  // 执行命令
  Future<String> executeCommand(String command) async {
    if (_client == null) throw Exception('未连接到路由器');
    try {
      final session = await _client!.execute(command);
      final stdoutFuture = session.stdout.expand((data) => data).toList();
      final stderrFuture = session.stderr.expand((data) => data).toList();
      final results = await Future.wait([stdoutFuture, stderrFuture]);
      await session.done;
      final output = utf8.decode(results[0], allowMalformed: true);
      final error = utf8.decode(results[1], allowMalformed: true);
      return output.isNotEmpty ? output : error;
    } catch (e) {
      throw Exception('命令执行失败: $e');
    }
  }

  Future<String> _runCheckedCommand(String command) async {
    final output = await executeCommand(
      '$command; printf "\\n__SHELLCRASH_EXIT__:\$?\\n"',
    );
    final marker = '\n__SHELLCRASH_EXIT__:';
    final markerIndex = output.lastIndexOf(marker);
    if (markerIndex < 0) throw Exception('命令没有返回状态: $output');
    final exitCode = int.tryParse(
      output.substring(markerIndex + marker.length).trim(),
    );
    if (exitCode != 0) {
      throw Exception(output.substring(0, markerIndex).trim());
    }
    return output.substring(0, markerIndex).trim();
  }

  String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\\\"'\\\"'")}'";

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
    _client?.close();
    _client = null;
  }
}
