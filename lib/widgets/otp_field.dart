import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Ô nhập mã OTP 6 số: hiển thị 6 ô, nhập bằng 1 TextField ẩn (hỗ trợ dán mã và
/// tự điền mã từ bàn phím – AutofillHints.oneTimeCode).
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  static const length = 6;

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(OtpField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    final text = widget.controller.text;
    if (text.length == OtpField.length) widget.onCompleted?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: widget.enabled ? () => _focus.requestFocus() : null,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < OtpField.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _box(i, text)),
              ],
            ],
          ),
          // TextField thật nằm phủ lên, trong suốt: nhận bàn phím, dán mã, tự điền.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(OtpField.length),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(int i, String text) {
    final filled = i < text.length;
    final active = _focus.hasFocus &&
        (i == text.length || (i == OtpField.length - 1 && text.length == OtpField.length));
    final color = widget.hasError
        ? AppColors.danger
        : active
        ? AppColors.primary
        : filled
        ? AppColors.primaryDark.withValues(alpha: 0.4)
        : AppColors.line;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(color: color, width: active ? 2 : 1.4),
      ),
      child: Text(
        filled ? text[i] : '',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// Dòng "Chưa nhận được mã? Gửi lại (sau N giây)". Đổi [generation] để bắt đầu đếm lại.
class ResendCountdown extends StatefulWidget {
  const ResendCountdown({
    super.key,
    required this.seconds,
    required this.generation,
    required this.onResend,
    this.busy = false,
  });

  final int seconds;
  final int generation;
  final VoidCallback onResend;
  final bool busy;

  @override
  State<ResendCountdown> createState() => _ResendCountdownState();
}

class _ResendCountdownState extends State<ResendCountdown> {
  Timer? _timer;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    _start(widget.seconds);
  }

  @override
  void didUpdateWidget(ResendCountdown old) {
    super.didUpdateWidget(old);
    if (old.generation != widget.generation) _start(widget.seconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start(int seconds) {
    _timer?.cancel();
    _left = seconds;
    if (_left <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Chưa nhận được mã?', style: AppText.muted),
        const SizedBox(width: 4),
        if (_left > 0)
          Text('Gửi lại sau $_left giây', style: AppText.muted)
        else
          TextButton(
            onPressed: widget.busy ? null : widget.onResend,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            child: Text(widget.busy ? 'Đang gửi…' : 'Gửi lại mã'),
          ),
      ],
    );
  }
}
