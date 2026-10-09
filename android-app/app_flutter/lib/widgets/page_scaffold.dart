import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/app_theme.dart';

/// 带「大标题随滚动收缩」的页面骨架（原沉浸标题栏的液态玻璃版）。
///
/// - 标题悬浮在内容之上，滚动 [AppSize.titleCollapseDistance] 后从 30 收到 22；
/// - 标题背板是一块真玻璃（`AdaptiveGlass`）：滚动后才出现，
///   内容从玻璃下面透出（与原版沉浸材质的行为一致）；
/// - 内容通过 `slivers` 传入（CustomScrollView）。
class PageScaffold extends StatefulWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
  });

  final String title;
  final List<Widget> slivers;

  /// 标题栏右侧操作（刷新按钮等）
  final List<Widget> actions;

  @override
  State<PageScaffold> createState() => _PageScaffoldState();
}

class _PageScaffoldState extends State<PageScaffold> {
  final ScrollController _controller = ScrollController();
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final next = _controller.hasClients ? _controller.offset : 0.0;
      if ((next - _offset).abs() > 0.5) {
        setState(() => _offset = next);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barHeight = topInset + AppSize.titleBarHeight;
    final scrolled = _offset > 2;

    return Stack(
      children: [
        CustomScrollView(
          controller: _controller,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(top: barHeight),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: EdgeInsets.only(
                      left: AppSize.pagePadding - 4,
                      right: AppSize.pagePadding - 4,
                      bottom: barZone(bottomInset),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.slivers,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),

        // 标题背板：液态玻璃（滚动后淡入，内容从玻璃下透出）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: scrolled ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: AdaptiveGlass(
                shape: const LiquidRoundedRectangle(borderRadius: 0),
                settings: const LiquidGlassSettings(
                  blur: 8,
                  thickness: 16,
                  lightIntensity: 0.35,
                  refractiveIndex: 1.15,
                ),
                child: SizedBox(height: barHeight),
              ),
            ),
          ),
        ),

        // 标题（始终在最上层）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SizedBox(
            height: barHeight,
            child: Padding(
              padding: EdgeInsets.only(top: topInset, left: 20, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: collapsedTitleSize(_offset),
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ),
                  ...widget.actions,
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
