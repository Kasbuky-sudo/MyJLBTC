import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

/// 登录页：按学校实际流程走**一条**链路 —— 学号 + 密码 → 获取验证码
/// （学校往账号绑定的手机号发短信）→ 填验证码 → 登录。
///
/// 所以卡片先是两行（学号 / 密码）、主按钮是「获取验证码」；
/// 验证码发出去后卡片长出第三行，主按钮变成「登录」。
/// 版式对齐原版：标题在页面顶部左对齐居中版心、输入框在同一张白卡里、
/// 主按钮胶囊形、下方是协议勾选行（未勾选时抖动提示）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  bool _agreed = false;
  bool _sending = false;
  bool _loggingIn = false;
  bool _codeSent = false;
  int _countdown = 0;
  double _shakeX = 0;

  Timer? _codeTimer;
  Timer? _shakeTimer;

  @override
  void dispose() {
    _codeTimer?.cancel();
    _shakeTimer?.cancel();
    _user.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _loading => _sending || _loggingIn;

  void _toast(String message) {
    // Android 走系统原生 Toast（见 AppToast）
    AppToast.show(context, message, warning: true);
  }

  /// 协议没勾就抖一下（原版 `shakeAgreement`）
  void _shakeAgreement() {
    HapticFeedback.lightImpact();
    _shakeTimer?.cancel();
    setState(() => _shakeX = 8);
    _shakeTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() => _shakeX = 0);
    });
  }

  /// 统一前置校验：协议 + 学号 + 密码
  bool _checkBeforeRequest() {
    if (!_agreed) {
      _shakeAgreement();
      _toast('请先阅读并同意用户协议与隐私政策');
      return false;
    }
    if (_user.text.trim().length < 6) {
      _toast('请输入学号');
      return false;
    }
    if (_password.text.length < 6) {
      _toast('请输入密码（至少 6 位）');
      return false;
    }
    return true;
  }

  /// 第一步：学号 + 密码换验证码（学校回什么就提示什么）
  Future<void> _sendCode() async {
    if (_countdown > 0 || _loading) return;
    final store = AppScope.of(context);

    // 会话还活着就别再发短信、连学号密码都不用填：直接进主界面。
    // （原版 LoginPage.sendCode 里也有这一步，只是排在表单校验之后；会话有效时校验没意义，
    //   所以这里提到最前面。）
    // 这一步还挡掉一个隐蔽的坑：带着有效 TGC 再请求 CAS 登录页，服务端会 302 进单点登录流程、
    // 拿不到登录表单 —— 少了这个判断，发码会失败并且把原因错报成"无法连接学校系统"。
    if (await store.isCasSessionAlive()) {
      if (!mounted) return;
      await store.adoptExistingSession();
      return;
    }
    if (!_checkBeforeRequest()) return;

    setState(() => _sending = true);
    final result = await store.sendSmsCode(_user.text.trim(), _password.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.success && !result.alreadyLoggedIn) {
        _codeSent = true;
        _countdown = 60;
      }
    });
    // 发码时才发现会话还有效（并发兜底）：照样直接进
    if (result.alreadyLoggedIn) {
      await store.adoptExistingSession();
      return;
    }
    _toast(result.message);
    if (result.success) {
      _codeTimer?.cancel();
      _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _countdown -= 1);
        if (_countdown <= 0) timer.cancel();
      });
    }
  }

  /// 第二步：验证码登录
  Future<void> _login() async {
    if (_loading) return;
    if (!_agreed) {
      _shakeAgreement();
      _toast('请先阅读并同意用户协议与隐私政策');
      return;
    }
    if (_code.text.trim().length < 4) {
      _toast('请输入短信验证码');
      return;
    }
    setState(() => _loggingIn = true);
    final result = await AppScope.of(context)
        .login(_user.text.trim(), _password.text, _code.text.trim());
    if (!mounted) return;
    setState(() => _loggingIn = false);
    // 成功由 AppStore.loggedIn 驱动根节点切到主界面
    if (!result.success) _toast(result.message);
  }

  void _onMainClick() {
    if (_codeSent) {
      _login();
    } else {
      _sendCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 标题在页面顶部
            Padding(
              padding: EdgeInsets.only(top: topInset + 56),
              child: Text(
                'MyJLBTC',
                style: TextStyle(
                  fontSize: AppSize.titleSize,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const Spacer(flex: 24),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSize.pagePadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 学号 / 密码（+ 验证码）同一张卡
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(AppSize.cardRadius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _Field(
                          controller: _user,
                          hint: '学号',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 20,
                        ),
                        const _CardDivider(),
                        _PasswordField(controller: _password),
                        if (_codeSent) ...[
                          const _CardDivider(),
                          _CodeRow(
                            controller: _code,
                            countdown: _countdown,
                            onResend: _sendCode,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 主按钮：先「获取验证码」，发码后变「登录」
                  SizedBox(
                    height: AppSize.buttonHeight,
                    child: FilledButton(
                      onPressed: _loading ? null : _onMainClick,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        disabledBackgroundColor: colors.accent,
                        shape: const StadiumBorder(),
                      ),
                      child: _loading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: colors.onAccent,
                              ),
                            )
                          : Text(
                              _codeSent ? '登录' : '获取验证码',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: colors.onAccent,
                              ),
                            ),
                    ),
                  ),

                  // 协议勾选行（未勾选时抖动）
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 60),
                    transform: Matrix4.translationValues(_shakeX, 0, 0),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _agreed = !_agreed);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _agreed
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 17,
                              color: _agreed
                                  ? colors.accent
                                  : colors.placeholder,
                            ),
                            const SizedBox(width: 7),
                            // 窄屏（320dp）上这行会挤出边界，允许换行
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textSecondary,
                                  ),
                                  children: [
                                    const TextSpan(text: '我已阅读并同意'),
                                    TextSpan(
                                      text: '《用户协议》',
                                      style: TextStyle(color: colors.accent),
                                    ),
                                    const TextSpan(text: '与'),
                                    TextSpan(
                                      text: '《隐私政策》',
                                      style: TextStyle(color: colors.accent),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// 卡片内的分隔线（左右各留 18 内边距，与原版一致）
class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: 18,
    endIndent: 18,
    color: AppColor.of(context).divider,
  );
}

/// 卡内一个输入行（学号 / 验证码）
class _Field extends StatefulWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.obscure = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool obscure;
  final Widget? trailing;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return SizedBox(
      height: AppSize.fieldHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  maxLength: widget.maxLength,
                  obscureText: widget.obscure,
                  style: TextStyle(fontSize: 16, color: colors.textPrimary),
                  cursorColor: colors.accent,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: colors.placeholder,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    counterText: '',
                  ),
                ),
              ),
            ),
            ?widget.trailing,
          ],
        ),
      ),
    );
  }
}

/// 密码行：右侧眼睛切换明文
class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller});

  final TextEditingController controller;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return _Field(
      controller: widget.controller,
      hint: '密码',
      trailing: IconButton(
        onPressed: () => setState(() => _hidden = !_hidden),
        visualDensity: VisualDensity.compact,
        icon: Icon(
          _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: colors.textSecondary,
        ),
      ),
      obscure: _hidden,
    );
  }
}

/// 验证码行：输入框 + 右侧倒计时 / 重新获取
class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.controller,
    required this.countdown,
    required this.onResend,
  });

  final TextEditingController controller;
  final int countdown;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final canResend = countdown <= 0;
    return _Field(
      controller: controller,
      hint: '验证码',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      trailing: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canResend ? onResend : null,
        child: Text(
          canResend ? '重新获取' : '$countdown s 后重发',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: canResend ? colors.accent : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
