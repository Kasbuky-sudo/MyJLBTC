//! MyJLBTC 共享核心（平台无关）—— 公开部分。
//!
//! 本仓库只放与学校系统**无关**的抽象层与纯逻辑：
//! - 本地缓存（键值 JSON 文件，等价原来 Preferences 的 `key.v` / `key.t` 结构）；
//! - 时钟抽象（真实时钟 / 测试用固定时钟）；
//! - 错误类型。
//!
//! 与学校系统对接的实现（统一身份认证与教务系统的请求、会话与 Cookie 维护、数据同步与解析、
//! 校园网关适配）**不在本仓库**，详见 README 的「不包含什么」一节；
//! Dart 侧的 `assets/test_snapshot.json` 提供与真实数据同构的演示数据，界面可以在没有后端的情况下跑起来。

pub mod cache;
pub mod clock;
pub mod error;

pub use cache::{CacheStore, FileCacheStore, MemoryCacheStore};
pub use clock::{Clock, FixedClock, SystemClock};
pub use error::{Error, Result};
