package com.example.my_app.ui;

// 版权来源：DSHA（MIT）com.deepseekharness.app.ui.DragHandleView —— 全量搬码，包名适配，行为契约不变。

import android.content.Context;
import androidx.appcompat.widget.AppCompatTextView;

/** 可拖动标题保留真实点击动作，供键盘与无障碍入口使用。 */
public final class DragHandleView extends AppCompatTextView {
  public DragHandleView(Context context) {
    super(context);
    setMinHeight(Math.round(48 * getResources().getDisplayMetrics().density));
    setFocusable(true);
  }

  @Override
  public boolean performClick() {
    return super.performClick();
  }
}
