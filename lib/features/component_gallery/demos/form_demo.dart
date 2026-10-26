//! 表单样张：ShadInput/ShadTextarea/ShadCheckbox/ShadSwitch/ShadSlider
//! （Stateful：交互状态真实可玩）
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../design/tokens.dart';

class FormDemo extends StatefulWidget {
  const FormDemo({super.key});

  @override
  State<FormDemo> createState() => FormDemoState();
}

class FormDemoState extends State<FormDemo> {
  bool _switch = true;
  bool _check = false;
  double _slider = 33;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const SizedBox(
            width: double.infinity,
            child: ShadInput(placeholder: Text('ShadInput 输入框')),
          ),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(
            width: double.infinity,
            child: ShadTextarea(placeholder: Text('ShadTextarea 多行')),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            ShadCheckbox(
                value: _check, onChanged: (v) => setState(() => _check = v)),
            const SizedBox(width: AppSpacing.sm),
            const Text('ShadCheckbox', style: AppTypography.bodyMd),
            const Spacer(),
            const Text('ShadSwitch', style: AppTypography.bodyMd),
            const SizedBox(width: AppSpacing.sm),
            ShadSwitch(
                value: _switch, onChanged: (v) => setState(() => _switch = v)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          ShadSlider(
            initialValue: _slider,
            max: 100,
            onChanged: (v) => setState(() => _slider = v),
          ),
          Text('ShadSlider 当前值 ${_slider.round()}',
              style: AppTypography.labelSm),
        ],
      ),
    );
  }
}
