import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/otp_field.dart';
import 'auth_header.dart';

/// US48 (SRS v1.8) – Yêu cầu mở khóa tài khoản:
/// nhập email → mã OTP → xem lý do khóa → gửi giải trình (20–2000 ký tự, tối đa 3 ảnh).
class AccountAppealPage extends StatefulWidget {
  const AccountAppealPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<AccountAppealPage> createState() => _AccountAppealPageState();
}

enum _Step { email, code, form, done }

class _AccountAppealPageState extends State<AccountAppealPage> {
  static const _contentMin = 20;
  static const _contentMax = 2000;
  static const _maxFiles = 3;

  final _emailForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _content = TextEditingController();
  _Step _step = _Step.email;
  String _masked = '';
  int _wait = 0;
  int _generation = 0;
  bool _loading = false;
  bool _uploading = false;
  String? _info;
  String? _error;
  String? _token;
  AppealContext? _ctx;
  final List<String> _files = [];

  @override
  void dispose() {
    for (final c in [_email, _code, _content]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (_step == _Step.email && !_emailForm.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sent = await AppScope.api(context).sendAppealOtp(_email.text);
      if (!mounted) return;
      setState(() {
        _step = _Step.code;
        _masked = sent.maskedEmail;
        _info = 'Nếu tài khoản này đang bị khóa, mã OTP đã được gửi tới ${sent.maskedEmail}. Mã có hiệu lực 5 phút.';
        _wait = sent.resendAfterSeconds;
        _generation++;
      });
      _code.clear();
    } catch (error) {
      if (!mounted) return;
      final wait = error is ApiFailure ? error.waitSeconds : null;
      setState(() {
        _error = errorMessage(error);
        if (wait != null) {
          _step = _Step.code;
          _wait = wait;
          _generation++;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (_code.text.length != OtpField.length) {
      setState(() => _error = 'Vui lòng nhập đủ 6 số của mã OTP.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await AppScope.api(context).verifyAppeal(_email.text, _code.text);
      if (!mounted) return;
      setState(() {
        _token = session.token;
        _ctx = session.context;
        _step = _Step.form;
        _info = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPhoto() async {
    final token = _token;
    if (token == null || _files.length >= _maxFiles) return;
    final api = AppScope.api(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
                title: const Text('Chụp ảnh'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await api.uploadAppealImage(token, file.path);
      if (mounted) setState(() => _files.add(url));
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final token = _token;
    if (token == null) return;
    final text = _content.text.trim();
    if (text.length < _contentMin || text.length > _contentMax) {
      setState(() => _error = 'Vui lòng viết giải trình ($_contentMin–$_contentMax ký tự).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = await AppScope.api(context).submitAppeal(
        token: token,
        content: text,
        attachmentUrls: List.of(_files),
      );
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _token = null;
        _step = _Step.done;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      _Step.email => (
        'Yêu cầu mở khóa',
        'Nhập email của tài khoản bị khóa. Chúng tôi gửi mã OTP để xác nhận bạn là chủ tài khoản.',
      ),
      _Step.code => (
        'Nhập mã xác thực',
        'Nhập mã 6 số đã gửi tới ${_masked.isEmpty ? _email.text : _masked}.',
      ),
      _Step.form => ('Gửi giải trình', 'Trình bày rõ sự việc để đội ngũ HomeService xem xét mở khóa.'),
      _Step.done => ('Đã gửi yêu cầu', 'Kết quả xem xét sẽ được gửi qua email của bạn.'),
    };
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AuthHeader(title: title, subtitle: subtitle, showServices: false),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: switch (_step) {
              _Step.email => _emailStep(),
              _Step.code => _codeStep(),
              _Step.form => _formStep(),
              _Step.done => _doneStep(),
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _messages() => [
    if (_info != null && _error == null) ...[
      NoticeBox(message: _info!, color: AppColors.success, icon: Icons.check_circle_outline_rounded),
      const SizedBox(height: 16),
    ],
    if (_error != null) ...[
      NoticeBox(message: _error!, color: AppColors.danger, icon: Icons.error_outline_rounded),
      const SizedBox(height: 16),
    ],
  ];

  Widget _emailStep() {
    return Form(
      key: _emailForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._messages(),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onFieldSubmitted: (_) => _send(),
            decoration: appInputDecoration(
              label: 'Email',
              hint: 'Nhập email tài khoản',
              icon: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(label: 'Gửi mã OTP', loading: _loading, onPressed: _send),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Quay lại đăng nhập'),
          ),
        ],
      ),
    );
  }

  Widget _codeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._messages(),
        const Text('Mã OTP', style: AppText.label),
        const SizedBox(height: 8),
        OtpField(
          controller: _code,
          hasError: _error != null && _code.text.isEmpty,
          onCompleted: (_) => _verify(),
        ),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Xác nhận', loading: _loading, onPressed: _verify),
        const SizedBox(height: 8),
        ResendCountdown(seconds: _wait, generation: _generation, busy: _loading, onResend: _send),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                  _step = _Step.email;
                  _error = null;
                  _info = null;
                }),
          child: const Text('Đổi email khác'),
        ),
      ],
    );
  }

  Widget _lockCard(AppealContext ctx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tài khoản ${ctx.fullName} (${ctx.maskedEmail})',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoRow(icon: Icons.report_outlined, label: 'Lý do', text: ctx.lockReasonText),
          if (ctx.lockDetail != null)
            InfoRow(icon: Icons.notes_rounded, label: 'Chi tiết', text: ctx.lockDetail!),
          if (ctx.lockedAt != null)
            InfoRow(icon: Icons.schedule_rounded, label: 'Thời điểm', text: formatDateTime(ctx.lockedAt!)),
        ],
      ),
    );
  }

  Widget _history(AppealContext ctx) {
    if (ctx.history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const SectionHeader('Các yêu cầu đã gửi'),
        for (var i = 0; i < ctx.history.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lần ${ctx.history.length - i} · ${formatDateTime(ctx.history[i].createdAt)}',
                          style: AppText.body,
                        ),
                      ),
                      StatusChip(
                        label: ctx.history[i].statusText,
                        color: switch (ctx.history[i].status) {
                          0 => AppColors.warning,
                          1 => AppColors.success,
                          _ => AppColors.danger,
                        },
                        dense: true,
                      ),
                    ],
                  ),
                  if (ctx.history[i].adminNote != null) ...[
                    const SizedBox(height: 6),
                    Text('Phản hồi: ${ctx.history[i].adminNote!}', style: AppText.muted),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _formStep() {
    final ctx = _ctx!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _lockCard(ctx),
        const SizedBox(height: 16),
        ..._messages(),
        if (ctx.canSubmit) ...[
          TextField(
            controller: _content,
            maxLines: 6,
            minLines: 4,
            maxLength: _contentMax,
            onChanged: (_) => setState(() {}),
            decoration: appInputDecoration(
              label: 'Nội dung giải trình',
              hint: 'Trình bày rõ sự việc, bạn đã khắc phục thế nào (VD: đã thanh toán khoản nợ ngày…).',
              helper: 'Tối thiểu $_contentMin ký tự.',
            ),
          ),
          const SizedBox(height: 12),
          Text('Ảnh minh chứng (không bắt buộc, tối đa $_maxFiles ảnh)', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final url in _files)
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.network(
                          AppConfig.mediaUrl(url) ?? url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(color: AppColors.primarySoft),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: IconButton.filled(
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          style: IconButton.styleFrom(backgroundColor: AppColors.ink),
                          onPressed: () => setState(() => _files.remove(url)),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_files.length < _maxFiles)
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Material(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: _uploading ? null : _addPhoto,
                      child: Center(
                        child: _uploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Bạn còn ${ctx.remainingAppeals} lần gửi yêu cầu cho lần khóa này.',
            style: AppText.small,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Gửi yêu cầu mở khóa',
            loading: _loading,
            onPressed: _uploading ? null : _submit,
          ),
        ] else
          NoticeBox(
            message: ctx.blockedMessage ?? 'Hiện chưa thể gửi yêu cầu mới.',
            color: AppColors.warning,
            icon: Icons.hourglass_top_rounded,
          ),
        _history(ctx),
      ],
    );
  }

  Widget _doneStep() {
    final ctx = _ctx!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoticeBox(
          title: 'Đã nhận yêu cầu mở khóa',
          message:
              'Email xác nhận đã được gửi tới ${ctx.maskedEmail}. Kết quả xem xét cũng sẽ được gửi qua email này.',
          color: AppColors.success,
          icon: Icons.check_circle_outline_rounded,
        ),
        _history(ctx),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Về trang đăng nhập',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
