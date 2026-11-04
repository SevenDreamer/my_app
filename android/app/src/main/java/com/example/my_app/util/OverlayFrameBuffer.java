package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.OverlayFrameBuffer —— 全量搬码，包名适配，行为契约不变。

/** 合并流式绘制请求；只绘制最新快照，关闭或确认时废弃排队内容。 */
public final class OverlayFrameBuffer {
  public static final class Frame {
    public final String key, text;
    private final long revision;

    private Frame(String key, String text, long revision) {
      this.key = key;
      this.text = text;
      this.revision = revision;
    }
  }

  private Frame pending;
  private long revision;

  public synchronized boolean offer(String key, String text) {
    boolean schedule = pending == null;
    pending = new Frame(key, text, ++revision);
    return schedule;
  }

  public synchronized Frame take() {
    Frame value = pending;
    pending = null;
    return value;
  }

  public synchronized boolean current(Frame frame) {
    return frame != null && frame.revision == revision;
  }

  public synchronized void clear() {
    pending = null;
    revision++;
  }
}
