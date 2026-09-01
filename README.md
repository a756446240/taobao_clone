# taobao_clone — 1:1 复刻淘宝 App

参考开源项目 [GZXTaoBaoAppFlutter](https://github.com/GanZhiXiong/GZXTaoBaoAppFlutter)（2019 年的老项目），用**全新架构**重新实现，界面与功能高度还原。

> ⚠️ 本项目仅用于学习练习，请勿商用，不要使用淘宝真实 Logo 与商标素材。

## ✨ 全新架构的改进点

| 维度 | 老项目（2019） | 本项目（全新） |
|---|---|---|
| Dart SDK | `>=2.1.0 <3.0.0` | `>=3.0.0` |
| 状态管理 | 无（setState 满天飞） | Provider（购物车 / 搜索历史） |
| 目录结构 | `common/ui/page` 混杂 | 清晰的 `core / models / data / providers / screens / widgets` 分层 |
| 轮播 | flutter_swiper（已停维护） | 原生 PageView + 指示器 |
| 依赖 | dio 2.x 等一堆旧库 | provider 6、cached_network_image 3、shared_preferences 2 |
| Android 仓库 | jcenter（已停服） | 由 flutter create 生成新版（google/mavenCentral） |
| ABI | 仅 32 位（现代手机闪退） | flutter create 默认含 arm64-v8a |
| 数据 | 依赖已失效的淘宝/京东 API | 本地 Mock 数据，离线可跑 |

## 📁 目录结构

```
lib/
├── main.dart                 # 入口（初始化 + Provider 注入）
├── app.dart                  # MaterialApp + 主题 + 路由
├── core/
│   └── theme/                # 颜色 / 字体样式 / 图标
├── models/models.dart        # 全部数据模型（不可变）
├── data/mock_data.dart       # Mock 数据（首页/购物车/消息/微淘）
├── providers/                # 状态管理（购物车、搜索历史）
├── screens/
│   ├── main/                 # 底部导航 5 Tab 容器
│   ├── home/                 # 首页 + 搜索 + 搜索结果
│   ├── weitao/               # 微淘
│   ├── message/              # 消息 + 聊天
│   ├── cart/                 # 购物车
│   └── mine/                 # 我的
└── widgets/                  # 通用组件（图片、商品卡片）
```

## 🚀 运行

```bash
# 1. 安装 Flutter SDK（最新稳定版）
#    https://docs.flutter.cn/get-started/install

# 2. 生成平台目录（android / ios / web）
cd taobao_clone
flutter create .

# 3. 拉取依赖
flutter pub get

# 4. 运行
flutter run

# 5. 打包 Android APK
flutter build apk --release
```

## 📱 已实现功能

- **首页**：搜索栏、热搜滚动条、轮播图、金刚区（20 入口分页）、新品推荐、头条滚动、猜你喜欢 Tab + 商品流
- **搜索**：搜索历史（本地持久化）、热搜推荐、实时建议、结果页（列表/网格切换 + 排序栏）
- **微淘**：分类 Tab、帖子流（图文 + 点赞交互）
- **消息**：通知入口、会话列表（未读角标）、聊天页（发送消息）
- **购物车**：店铺分组、全选/单选、数量加减、合计、结算提示
- **我的**：个人信息、收藏/足迹/卡券、订单入口、功能宫格、工具卡片
