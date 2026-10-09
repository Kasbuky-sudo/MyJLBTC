//! 时间来源抽象。
//!
//! 原 ArkTS 到处直接 `new Date()` / `Date.now()`，测试没法控制"今天"。
//! 这里抽出 [`Clock`]，生产用 [`SystemClock`]，测试用 [`FixedClock`]。
//! 口径与原实现保持一致：
//! - 星期 1-7，周一 = 1（教务 xingqi 字段同口径）；
//! - 学期串 `YYYY-YYYY-S`：8 月及以后 = 第 1 学期；1 月 = 上学年第 1 学期；2-7 月 = 上学年第 2 学期。

use chrono::{Datelike, Local, NaiveDate, TimeZone, Timelike};

/// 时间源。`Send + Sync` 便于在异步 / FFI 场景共享。
pub trait Clock: Send + Sync {
    /// 当前 Unix 毫秒时间戳
    fn now_ms(&self) -> i64;
    /// 本地日期
    fn today(&self) -> NaiveDate;
    /// 本地时间的"当天第几分钟"（0 点起算）
    fn now_minutes(&self) -> i64;
    /// 当前本地时间 `HH:MM` 格式（日志用）
    fn now_hhmm(&self) -> String {
        let now = Local::now();
        format!("{:02}:{:02}", now.hour(), now.minute())
    }
}

/// 生产实现：本机时间。
#[derive(Debug, Default, Clone, Copy)]
pub struct SystemClock;

impl Clock for SystemClock {
    fn now_ms(&self) -> i64 {
        Local::now().timestamp_millis()
    }

    fn today(&self) -> NaiveDate {
        Local::now().date_naive()
    }

    fn now_minutes(&self) -> i64 {
        let now = Local::now();
        now.hour() as i64 * 60 + now.minute() as i64
    }
}

/// 测试实现：固定时间。
#[derive(Debug, Clone, Copy)]
pub struct FixedClock {
    /// 固定时刻（Unix 毫秒）
    pub ms: i64,
    /// 固定本地日期
    pub date: NaiveDate,
    /// 固定"当天第几分钟"
    pub minutes: i64,
}

impl FixedClock {
    /// 由本地日期 + 时分构造（时间为当天 00:00 起算）
    pub fn new(date: NaiveDate, minutes: i64) -> Self {
        let ms = Local
            .with_ymd_and_hms(date.year(), date.month(), date.day(), 0, 0, 0)
            .single()
            .map(|dt| dt.timestamp_millis())
            .unwrap_or(0)
            + minutes * 60_000;
        Self { ms, date, minutes }
    }

    /// 由 `YYYY-MM-DD` + `HH:MM` 构造
    pub fn parse(date: &str, hhmm: &str) -> Self {
        let d = NaiveDate::parse_from_str(date, "%Y-%m-%d").expect("fixed clock date");
        let (h, m) = hhmm.split_once(':').expect("HH:MM");
        let minutes =
            h.trim().parse::<i64>().expect("hour") * 60 + m.trim().parse::<i64>().expect("minute");
        Self::new(d, minutes)
    }
}

impl Clock for FixedClock {
    fn now_ms(&self) -> i64 {
        self.ms
    }

    fn today(&self) -> NaiveDate {
        self.date
    }

    fn now_minutes(&self) -> i64 {
        self.minutes
    }
}

/// 今天星期几：1-7，周一 = 1（教务 xingqi 同口径）。
pub fn weekday_of(date: NaiveDate) -> u32 {
    date.weekday().number_from_monday()
}
