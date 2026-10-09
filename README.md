# MyJLBTC

吉林工商学院学生的校园随身助手：课表、成绩、考试安排、通知公告、学籍信息，用学校统一身份
认证账号登录。**非学校官方应用**，学生自用工具。

鸿蒙版（ArkTS / ArkUI）与 Android 版（Flutter + Rust 核心）的代码都在这个仓库里。

## 这个仓库包含什么

| 目录 | 内容 |
|---|---|
| `harmony-app/` | 鸿蒙版界面与展示层（页面、主题、卡片组件、模型） |
| `android-app/` | Android 版 Flutter 界面层（页面 / 组件 / 主题 / 状态 / 核心接口）、Android 系统集成（原生 Toast、上课提醒通知、桌面卡片、机型判断）、测试与**合成**演示数据 |
| `rust-core/` | Rust 核心的抽象层与数据模型（时钟 / 缓存 trait / 数据模型 / 演示数据） |

**不包含**（出于合规与安全考虑）：

- 与学校系统对接的实现细节：网关适配（隐藏 Web 视图、会话在 Web 与核心之间传递）、
  CAS / 教务接口对接、含教务字段名的解析模块、Rust 的传输层与 FFI 调度；
- 抓包样本（`fixtures/`）与由真实抓包生成的开发数据；
- 任何真实数据、账号信息与凭据。

因此**本仓库不保证能原样编译运行**（缺的正是上述模块）。部分文件（`main.dart`、
`MainActivity.kt`、`core_client.dart`）在发布前做过删减，鸿蒙侧的 `MainShell.ets`
（与网关验证绑定）未包含，演示数据里的身份字段都是占位值。
公开部分用于说明这个应用是怎么搭起来的（界面、分层、数据组织），而不是一份
「如何把学校系统接出来」的教程。

## 技术栈

- **鸿蒙版**：ArkTS / ArkUI（HarmonyOS 7.0+），沉浸式标题栏 + 悬浮胶囊底栏，桌面卡片用
  FormAbility。
- **Android 版**：Flutter（界面）+ Rust（核心数据层，经 dart:ffi 调用）。
  - Rust 侧：`reqwest` + `rustls`、`tokio`、`serde_json`、`rsa`、`regex`；
  - Flutter 侧：`liquid_glass_widgets`（玻璃外壳）、`dynamic_color`（Material You 取色）、
    `flutter_svg`、`share_plus`、`url_launcher`、`path_provider`；
  - Android 原生：上课提醒走 Android 16 实时通知（Live Updates），桌面卡片为 AppWidget。
- 数据只存在设备本地（离线优先），联网只发生在「登录账号」和「手动刷新」两处。

## 设计要点（可公开的部分）

- **离线优先**：教务数据拉取后写入本机缓存，之后所有页面只读缓存；缓存时间可查（"x月x日
  xx:xx 已同步"）。
- **核心与界面分离**：Rust 侧用 `Transport` / `CacheStore` / `Clock` 三个 trait 把网络、
  存储、时钟抽出来，界面侧只认一份 `Snapshot` JSON —— 测试用抓包回放（合成样本）驱动，
  不联网也能跑全套协议回归。
- **界面层薄**：所有页面都是「读快照 + 渲染」，没有自己的业务状态；主题是设计令牌表
  （与原版鸿蒙版的 `Theme.ets` 一一对应），深色 / Material You 取色都只换令牌。

## 许可证

尚未添加 LICENSE 文件（版权归开发者）。在补上之前，默认保留所有权利。

## 致谢

开发过程中使用了大语言模型辅助（组件写法、接口调用、协议排查），详见应用内
「关于 → AI 辅助编程公示」。使用的开源项目见应用内「关于 → 开源相关」。
