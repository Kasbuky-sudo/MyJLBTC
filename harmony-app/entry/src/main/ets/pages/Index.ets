import { AppAnim } from '../common/Animation';
import { AppColor } from '../common/Theme';
import { SchoolClient } from '../common/SchoolClient';
import { SystemGate } from '../common/SystemGate';
import { LoginPage } from './LoginPage';
import { MainShell } from './MainShell';

/**
 * 应用入口：登录态由启动页（pages/Splash）决定好放进 AppStorage ——
 * 登录了直接进主界面，没登录（或会话过期）显示登录页。退出登录在这里清会话。
 * 系统版本不够新时**永远只显示登录页**：主界面用的沉浸光感属性是 HarmonyOS 7.0 才有的，
 * 低版本上进去第一次渲染就会 "xxx is not callable" 闪退（这里再兜一道，防止任何路径漏进去）。
 */
@Entry
@Component
struct Index {
  @StorageLink('appLoggedIn') loggedIn: boolean = false;

  build() {
    Stack() {
      if (this.loggedIn && SystemGate.ok()) {
        MainShell({
          onLogout: () => {
            // 真退出：把本机会话 Cookie 清掉，回登录页时才会真的要账号密码
            SchoolClient.get().logout();
            this.loggedIn = false;
          }
        })
          .transition(AppAnim.page())
      } else {
        LoginPage({
          onLoggedIn: () => {
            this.loggedIn = true;
          }
        })
          .transition(AppAnim.page())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.PAGE_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
