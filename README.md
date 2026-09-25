# ShellCrash 管理 - 小米路由器专用

<div align="center">
  <img src="app_icon.svg" width="128" height="128" alt="ShellCrash 管理图标"/>
  <h3>简洁高效的 ShellCrash 规则管理工具</h3>
  <p>专为小米路由器和 ShellCrash 优化</p>
</div>

## ✨ 功能特性

- 🚀 **快速连接** - SSH 连接小米路由器，自动识别 ShellCrash 配置
- 📝 **规则管理** - 可视化管理域名规则，点击切换代理模式
- 🔄 **一键切换** - 直连 ⇄ 代理 ⇄ 拒绝，无需弹窗确认
- 💾 **自动备份** - 每次修改自动备份，保留最近 5 个版本
- 🎨 **简洁界面** - 清晰的规则列表，彩色标签一目了然
- 🔧 **诊断工具** - 系统诊断、读取测试、自定义命令执行
- 📱 **数字键盘** - IP 地址输入使用九宫格数字键盘

## 📦 下载安装

**最新版本：v0.8 (v3.4)**

📥 [下载 ShellCrash管理-v3.4-完美版.apk](https://github.com/R19988088/mi_ShellCrash/releases)

- **包名：** `com.ddd.mi_shellcrash`
- **应用名：** ShellCrash管理
- **支持系统：** Android 5.0+
- **文件大小：** 54.8 MB

## 🚀 快速开始

### 1. 安装应用

下载并安装 APK 文件到你的 Android 设备。

### 2. 连接路由器

| 项目 | 值 |
|------|-----|
| **IP 地址** | 192.168.31.1 (小米路由器默认) |
| **端口** | 22 |
| **用户名** | root |
| **密码** | 你的路由器密码 |

### 3. 管理规则

进入 **Clash 规则管理**，应用会自动识别配置文件位置：
- `/data/ShellCrash/yamls/rules.yaml`

## 🎯 使用说明

### 规则管理界面

```
域名规则 (71)
━━━━━━━━━━━━━━━━━━━━━━━
apple.com          [直连] 🗑️
google.com         [代理] 🗑️
baidu.com          [直连] 🗑️
youtube.com        [拒绝] 🗑️
```

### 切换代理模式

**点击彩色标签即可切换：**

- 🟢 **直连 (DIRECT)** - 流量直接连接，不经过代理
- 🔵 **代理 (PROXY)** - 流量通过代理服务器
- 🔴 **拒绝 (REJECT)** - 阻止访问该域名

**循环切换：** 直连 → 代理 → 拒绝 → 直连

### 添加规则

1. 点击底部 **"添加域名规则"**
2. 输入域名（如 `google.com`）
3. 选择代理模式
4. 点击 **"提交并重启 Clash"** 保存

### 删除规则

点击规则右侧的 🗑️ 删除按钮即可删除规则。

## 🔧 高级功能

### 自动备份

每次保存配置时自动创建备份：

```
/data/ShellCrash/yamls/rules.yaml
/data/ShellCrash/yamls/rules.yaml.backup.2026-09-25T20-30-00
/data/ShellCrash/yamls/rules.yaml.backup.2026-09-25T20-25-00
...
```

自动保留最近 5 个备份，超过数量自动删除旧备份。

### 系统诊断

**主界面 → 系统诊断**

检查：
- ✅ 当前用户权限
- ✅ Clash 进程状态
- ✅ Clash 启动参数
- ✅ 搜索所有 YAML 配置
- ✅ 检查 /etc 目录

### 读取测试

**主界面 → 读取测试**

测试配置文件读取：
- 直接读取 `/data/ShellCrash/yamls/rules.yaml`
- 显示文件内容和规则统计
- 验证读取功能是否正常

### 执行自定义命令

**主界面 → 执行自定义命令**

在路由器上执行任意 Shell 命令，例如：
```bash
# 查看配置文件
cat /data/ShellCrash/yamls/rules.yaml

# 重启 ShellCrash
/data/ShellCrash/start.sh restart

# 查看网络连接
netstat -tunlp | grep clash
```

### 浏览配置文件

**主界面 → 浏览配置文件**

文件浏览器功能，可以：
- 浏览路由器目录
- 查看文件内容
- 编辑文本文件

## 🛠️ 技术说明

### 支持的配置格式

#### ShellCrash 格式（直接列表）
```yaml
- DOMAIN-SUFFIX,apple.com,DIRECT
- DOMAIN,api.example.com,PROXY
- DOMAIN-KEYWORD,google,PROXY
```

#### 标准 Clash 格式
```yaml
rules:
  - DOMAIN-SUFFIX,apple.com,DIRECT
  - DOMAIN,api.example.com,PROXY
  - DOMAIN-KEYWORD,google,PROXY
```

两种格式均支持！

### 为什么使用命令读写而不是 SFTP？

在测试中发现 SFTP 读取某些路由器上的文件会超时，因此改用 SSH 命令：

- **读取文件：** `cat /path/to/file`
- **写入文件：** `echo "content" > /path/to/file`

这种方式更快、更稳定，兼容性更好。

## 📋 版本历史

### v0.8 (v3.4) - 2024-09-25

**新功能：**
- ✅ 规则切换不改变位置（原地更新）
- ✅ IP 输入框使用数字键盘

### v0.7 (v3.3) - 2024-09-25

**新功能：**
- ✅ 修复 ShellCrash 格式添加规则逻辑
- ✅ 移除切换模式的弹窗提示

### v0.6 (v3.2) - 2024-09-25

**新功能：**
- ✅ 自定义应用图标（蓝色路由器 + Clash 闪电）
- ✅ 更改包名为 `com.ddd.mi_shellcrash`
- ✅ 应用名改为 "ShellCrash管理"

### v0.5 (v3.1) - 2024-09-25

**新功能：**
- ✅ 简化界面，只显示域名和代理模式
- ✅ 点击彩色标签切换模式
- ✅ 修复中文乱码（UTF-8 编码）
- ✅ 自动备份功能（保留 5 个）

### v0.4 (v3.0) - 2024-09-25

**重大修复：**
- ✅ 改用命令读写文件，解决 SFTP 超时问题
- ✅ 完整支持 ShellCrash 配置格式
- ✅ 自动识别 ShellCrash 路径

### v0.1-0.3 - 2024-09-25

早期开发版本，基础功能实现。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## ⚠️ 免责声明

本工具仅供学习交流使用，使用者需自行承担使用风险。

---

<div align="center">
  <p>Made with ❤️ for 小米路由器 & ShellCrash 用户</p>
</div>


This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
