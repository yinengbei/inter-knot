# 绳网 (Inter-Knot)

绳网是一个跨平台的游戏交流社区，基于 Flutter 构建，灵感来源于绝区零游戏世界观中的“绳网”。
本项目基于 [share121/inter-knot](https://github.com/share121/inter-knot) 二开，旨在提供一种基于后端服务器提供数据的方案。


## ✅ To Do

### 👤 用户系统

* [ ] **重构我的页面**
* [ ] **用户经验系统**
* [ ] **用户等级体系**

---

### 🎨 UI
* [ ] **前端整体风格向「绝区零 · 绳网」靠拢**

---

## 🛠️ 技术栈

### 前端

* **框架**: [Flutter](https://flutter.dev/)（Dart SDK ≥ 3.4.4）
* **状态管理 & 路由**: [GetX](https://pub.dev/packages/get)
* **网络层**: GetConnect（REST API 封装）
* **富文本**:

  * [flutter_quill](https://pub.dev/packages/flutter_quill)
  * [markdown](https://pub.dev/packages/markdown)
* **本地存储**: [get_storage](https://pub.dev/packages/get_storage)

### 后端

* **API 协议**: RESTful
* **无头 CMS**: Strapi v5

---

## 🚀 快速开始

### 1. 环境准备

* Flutter SDK
* Visual Studio Code 或 Android Studio

### 2. 拉取代码

```bash
git clone https://github.com/share121/inter_knot.git
cd inter-knot
```

### 3. 安装依赖

```bash
flutter pub get
```

### 4. 配置（可选）

默认连接到提瓦特 Strapi 服务器，如需使用自建后端，请修改：

```dart
class ApiConfig {
  static const String baseUrl = 'YOUR_SERVER_URL'; // e.g. http://localhost:1337
}
```

### 5. 运行项目

```bash
# Chrome
flutter run -d chrome

# Windows
flutter run -d windows

# Android
flutter run -d android
```

---

## 📂 目录结构概览

```
lib/
├── api/            # API 接口定义
├── components/     # 可复用 UI 组件
├── controllers/    # 业务逻辑控制器
├── gen/            # 自动生成资源
├── helpers/        # 工具函数
├── models/         # 数据模型
├── pages/          # 页面
└── main.dart       # 应用入口
```

---

## 🤝 贡献指南

欢迎提交 Issue 或 Pull Request，一起完善绳网。

---

> ⚠️ **注意**：本项目大部分代码由 AI 协助开发，使用前请自行评估。

---

## 📄 许可证

本项目基于 **MIT License** 开源。

```
Copyright (c) 2024 share121
Copyright (c) 2026 yinengbei
```
