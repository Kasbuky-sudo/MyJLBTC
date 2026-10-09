//! 统一错误类型。
//!
//! 约定：核心内部所有可失败路径返回 [`Result`]；对外的"UI 友好"API（如登录、同步）
//! 再把错误折叠成 success/message（与原 ArkTS 行为一致，界面永不因异常崩溃）。

use thiserror::Error;

#[derive(Debug, Error)]
pub enum Error {
    /// 网络层失败（连接、超时、DNS、TLS…）
    #[error("network: {0}")]
    Network(String),

    /// 非预期 HTTP 状态（需要调用方判断 401/403 等语义时用）
    #[error("http status {status}")]
    Http { status: u16 },

    /// JSON 解析失败
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),

    /// 加解密失败（RSA 公钥损坏、PEM 解析失败…）
    #[error("crypto: {0}")]
    Crypto(String),

    /// 本地缓存读写失败
    #[error("cache: {0}")]
    Cache(String),

    /// 页面结构不符合预期（找不到令牌、错误面板…）
    #[error("html: {0}")]
    Html(String),

    /// 需要先登录 / 会话失效
    #[error("session: {0}")]
    Session(String),

    /// IO
    #[error("io: {0}")]
    Io(#[from] std::io::Error),

    /// 其他
    #[error("{0}")]
    Other(String),
}

pub type Result<T> = std::result::Result<T, Error>;
