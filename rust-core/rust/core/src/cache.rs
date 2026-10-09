//! 本地缓存存储 —— 等价原 Preferences（`sosoci_school`）的键值语义。
//!
//! 原实现每个键写两份：`<key>.v`（值）与 `<key>.t`（写入时间 ms）。
//! 这里保持同样的键名与语义（`get` 空值返回 `None`，`saved_at` 缺失返回 0），
//! 换成平台无关的实现：文件 / 内存两种。

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use crate::error::{Error, Result};

/// 键值缓存（平台壳在启动时注入实现；Flutter 端用文件，测试用内存）。
pub trait CacheStore: Send + Sync {
    /// 写入值 + 时间戳。
    fn put(&self, key: &str, value: &str, at_ms: i64) -> Result<()>;
    /// 读值；不存在或空 → None。
    fn get(&self, key: &str) -> Option<String>;
    /// 读写入时间（ms）；不存在 → 0。
    fn saved_at(&self, key: &str) -> i64;
    /// 删除键（值 + 时间）。
    fn remove(&self, key: &str) -> Result<()>;
}

fn key_path_guard(key: &str) -> Result<()> {
    if key.is_empty() || key.contains(['/', '\\', ':']) || key.contains("..") {
        return Err(Error::Cache(format!("bad cache key: {key}")));
    }
    Ok(())
}

/// 文件实现：`<dir>/<key>.v` 存值，`<dir>/<key>.t` 存时间戳。
#[derive(Debug, Clone)]
pub struct FileCacheStore {
    dir: PathBuf,
}

impl FileCacheStore {
    pub fn new(dir: impl Into<PathBuf>) -> Self {
        Self { dir: dir.into() }
    }

    /// 目录路径（平台壳可能要展示 / 备份用）。
    pub fn dir(&self) -> &Path {
        &self.dir
    }

    fn value_path(&self, key: &str) -> PathBuf {
        self.dir.join(format!("{key}.v"))
    }

    fn time_path(&self, key: &str) -> PathBuf {
        self.dir.join(format!("{key}.t"))
    }
}

impl CacheStore for FileCacheStore {
    fn put(&self, key: &str, value: &str, at_ms: i64) -> Result<()> {
        key_path_guard(key)?;
        std::fs::create_dir_all(&self.dir)?;
        std::fs::write(self.value_path(key), value)?;
        std::fs::write(self.time_path(key), at_ms.to_string())?;
        Ok(())
    }

    fn get(&self, key: &str) -> Option<String> {
        if key_path_guard(key).is_err() {
            return None;
        }
        let raw = std::fs::read_to_string(self.value_path(key)).ok()?;
        if raw.is_empty() {
            None
        } else {
            Some(raw)
        }
    }

    fn saved_at(&self, key: &str) -> i64 {
        if key_path_guard(key).is_err() {
            return 0;
        }
        std::fs::read_to_string(self.time_path(key))
            .ok()
            .and_then(|s| s.trim().parse::<i64>().ok())
            .unwrap_or(0)
    }

    fn remove(&self, key: &str) -> Result<()> {
        key_path_guard(key)?;
        let _ = std::fs::remove_file(self.value_path(key));
        let _ = std::fs::remove_file(self.time_path(key));
        Ok(())
    }
}

/// 内存实现（单元测试 / 临时会话用）。
#[derive(Debug, Default)]
pub struct MemoryCacheStore {
    entries: Mutex<HashMap<String, (String, i64)>>,
}

impl MemoryCacheStore {
    pub fn new() -> Self {
        Self::default()
    }
}

impl CacheStore for MemoryCacheStore {
    fn put(&self, key: &str, value: &str, at_ms: i64) -> Result<()> {
        key_path_guard(key)?;
        self.entries
            .lock()
            .unwrap()
            .insert(key.to_string(), (value.to_string(), at_ms));
        Ok(())
    }

    fn get(&self, key: &str) -> Option<String> {
        if key_path_guard(key).is_err() {
            return None;
        }
        self.entries
            .lock()
            .unwrap()
            .get(key)
            .map(|(v, _)| v.clone())
            .filter(|v| !v.is_empty())
    }

    fn saved_at(&self, key: &str) -> i64 {
        if key_path_guard(key).is_err() {
            return 0;
        }
        self.entries
            .lock()
            .unwrap()
            .get(key)
            .map(|(_, t)| *t)
            .unwrap_or(0)
    }

    fn remove(&self, key: &str) -> Result<()> {
        key_path_guard(key)?;
        self.entries.lock().unwrap().remove(key);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn file_roundtrip() {
        let dir = tempfile::tempdir().unwrap();
        let store = FileCacheStore::new(dir.path());
        assert_eq!(store.get("schedule.today"), None);
        assert_eq!(store.saved_at("schedule.today"), 0);

        store
            .put("schedule.today", "[{\"name\":\"x\"}]", 1234567)
            .unwrap();
        assert_eq!(
            store.get("schedule.today").as_deref(),
            Some("[{\"name\":\"x\"}]")
        );
        assert_eq!(store.saved_at("schedule.today"), 1234567);

        // 空值读取 = None（对齐原 readCache 的 raw.length > 0）
        store.put("empty", "", 1).unwrap();
        assert_eq!(store.get("empty"), None);

        store.remove("schedule.today").unwrap();
        assert_eq!(store.get("schedule.today"), None);
    }

    #[test]
    fn memory_roundtrip() {
        let store = MemoryCacheStore::new();
        store.put("cookies", "[{\"n\":\"TGC\"}]", 42).unwrap();
        assert_eq!(store.get("cookies").as_deref(), Some("[{\"n\":\"TGC\"}]"));
        assert_eq!(store.saved_at("cookies"), 42);
        assert_eq!(store.get("nope"), None);
    }

    #[test]
    fn bad_keys_rejected() {
        let store = MemoryCacheStore::new();
        assert!(store.put("../evil", "x", 0).is_err());
        assert_eq!(store.get("../evil"), None);
    }
}
