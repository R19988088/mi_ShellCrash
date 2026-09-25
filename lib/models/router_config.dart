class SSHConfig {
  final String host;
  final int port;
  final String username;
  final String password;

  SSHConfig({
    required this.host,
    this.port = 22,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
      };

  factory SSHConfig.fromJson(Map<String, dynamic> json) => SSHConfig(
        host: json['host'] as String,
        port: json['port'] as int? ?? 22,
        username: json['username'] as String,
        password: json['password'] as String,
      );
}
