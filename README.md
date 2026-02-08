# 绳网 (Inter-Knot)

绳网是一个跨平台的游戏交流社区，基于 Flutter 构建，灵感来源于绝区零游戏世界观中的“绳网”。本项目基于 [share121/inter-knot](https://github.com/share121/inter-knot) 二开，旨在提供一种基于后端服务器提供数据的方案。
绳网是一个游戏、技术交流平台

### 开发计划（如果你打算做一些东西，请在这里事先说明，避免多人开发一个任务，导致冲突。）

| <div style="width:100px">任务</div> | <div style="width:100px">负责人</div> | <div style="width:100px">进度</div> | 备注 |
|:----------:|:------:|:--------:|:--------|
| 创建讨论   | all | 待后续完善  | 希望能像GitHub那样，可通过拖动、复制等上传图片，上传图片后， <br> 在光标位置提示上传情况，上传完毕业后自动，自动构建语法，并调用图片链接。 <br> 除非指定图片，否则正文中的第一个图片就是封面  <br>  有基础的格式工具栏(这个或许有开源项目参考)|
| 创建、获取讨论图片   | 浩彬 | [PR等待验收](https://github.com/yinengbei/inter-knot/pull/23) | |
| 创建不同类别的讨论、投票讨论   | 负责人 | 进度     | |
| 举报讨论   | 负责人 | 进度     | |
| 用户经验、等级   | 负责人 | 进度     | |
| 修改前端让其更像绝区零绳网 | yiyi | 正在开发  | |


## 🛠️ 技术栈

### 前端 
- **框架**: [Flutter](https://flutter.dev/) (Dart SDK >=3.4.4)
- **状态管理 & 路由**: [GetX](https://pub.dev/packages/get) - 高效的状态管理和依赖注入。
- **网络层**: GetConnect - 统一的 REST API 请求封装。
- **富文本**: [flutter_quill](https://pub.dev/packages/flutter_quill) & [markdown](https://pub.dev/packages/markdown) - 内容编辑与渲染。
- **本地存储**: [get_storage](https://pub.dev/packages/get_storage) - 轻量级持久化存储。

### 后端
- **API 协议**: RESTful API
- **无头CMS**: Strapi v5 

## 🚀 快速开始

### 1. 环境准备

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 
- Visual Studio Code 或 Android Studio

### 2. 拉取代码

```bash
git clone https://github.com/share121/inter_knot.git
cd inter-knot
```

### 3. 安装依赖

```bash
flutter pub get
```

### 4. 配置 (可选)
默认连接到提瓦特Strapi服务器。如需连接自建后端，请修改 `lib/constants/api_config.dart`：

```dart
class ApiConfig {
  static const String baseUrl = 'YOUR_SERVER_URL'; // 例如 http://localhost:1337
  // ...
}
```

### 5. 运行项目

```bash
# Chrome 浏览器
flutter run -d chrome

# Windows 桌面
flutter run -d windows

# Android 模拟器/真机
flutter run -d android
```

## 📂 目录结构概览

```
lib/
├── api/            # API 接口定义
├── components/     # 可复用的UI组件
├── controllers/    # 业务逻辑控制器
├── gen/            # 自动生成的资源文件
├── helpers/        # 工具类与辅助函数
├── models/         # 数据模型
├── pages/          # 页面视图
└── main.dart       # 应用入口与初始化
```


## 🤝 贡献指南

欢迎提交 Issue 反馈 Bug 或 提交 Pull Request 贡献代码。

## 
> ⚠️ **注意**：本项目大部分代码由 AI 开发，使用前请斟酌。

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。

Copyright (c) 2024 share121
Copyright (c) 2026 yinengbei
