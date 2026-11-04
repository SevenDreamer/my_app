package com.example.my_app;

// 版权来源：DSHA（MIT）com.deepseekharness.app.AgentTaskStopReceiver —— 全量搬码，包名适配，行为契约不变。

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Explicit, non-exported PendingIntent target; never stops the Web service. */
public final class AgentTaskStopReceiver extends BroadcastReceiver {
  @Override
  public void onReceive(Context context, Intent intent) {
    if (intent != null) {
      if ("dsha-task-dismiss".equals(intent.getAction()))
        AgentTaskNotifications.get(context).dismiss(intent);
      else AgentTaskNotifications.get(context).stop(intent);
    }
  }
}
