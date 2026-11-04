package com.example.my_app;

// 版权来源：DSHA（MIT）com.deepseekharness.app.ConfirmReceiver —— 全量搬码，包名适配，行为契约不变。

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * 后台安全确认通知的按钮接收器：用户点「允许/拒绝」后
 * 通知 HttpShellService 释放挂起的确认。
 */
public class ConfirmReceiver extends BroadcastReceiver {

  public static final String ACTION_ALLOW = "com.example.my_app.CONFIRM_ALLOW";
  public static final String ACTION_DENY = "com.example.my_app.CONFIRM_DENY";

  @Override
  public void onReceive(Context context, Intent intent) {
    if (intent == null
        || (!ACTION_ALLOW.equals(intent.getAction()) && !ACTION_DENY.equals(intent.getAction())))
      return;
    String identity = intent.getDataString();
    if (identity == null) return;
    HttpShellService svc = HttpShellService.instance();
    if (svc != null) {
      svc.resolveConfirm(ACTION_ALLOW.equals(intent.getAction()), identity);
    }
  }
}
