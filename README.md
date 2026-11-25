# ProductPulse HarmonyOS SDK

适用于 HarmonyOS NEXT（API 12+）Stage 模型应用的 ArkTS HAR 源码模块。请在 ProductPulse 后台创建 HarmonyOS 数据源并复制 Source Key。

## 从 OpenHarmony 三方库中心仓安装

首版通过中心仓审核后，在宿主模块目录执行：

```bash
ohpm install productpulse@1.0.0
```

## 本地接入

在宿主模块（通常为 `entry`）的 `oh-package.json5` 中添加本地依赖。以下路径假设已将 `sdk/harmonyos` 复制到与 `entry` 同级的位置。

```json5
{
  "dependencies": {
    "productpulse": "file:../harmonyos"
  }
}
```

在 DevEco Studio 中同步依赖，或执行 `ohpm install`。SDK 模块已声明 `ohos.permission.INTERNET`。

## 初始化与日活

在主进程入口 UIAbility 的 `onForeground` 中初始化。第一次进入前台会检查日活，之后由应用级前台监听触发检查。同一进程内多次使用相同 Source Key 初始化会复用实例。

```typescript
import { UIAbility } from '@kit.AbilityKit';
import { ProductPulse } from 'productpulse';

export default class EntryAbility extends UIAbility {
  private pulse?: ProductPulse;

  onForeground(): void {
    ProductPulse.initialize(this.context, '替换为 HarmonyOS Source Key')
      .then((pulse: ProductPulse) => { this.pulse = pulse; })
      .catch(() => { console.error('ProductPulse 初始化失败'); });
  }
}
```

SDK 在宿主 Preferences 中保存匿名 UUID，并按北京时间（UTC+8）判断当天是否已成功上报。自动上报失败会在下次进入前台时重试。应用持续停留在前台并跨天时，可调用 `await pulse.reportActive()` 手动上报。

## 提交反馈

```typescript
await pulse.submitFeedback('希望支持深色模式', { 'App 版本': '1.0.0' });
```

第二个参数可省略。反馈正文会去除首尾空白，附加信息按键排序。拼接后最多接受 2000 个 Unicode 码点。手动上报与反馈提交均返回 Promise，调用方可用 `try/catch` 处理失败。HTTP 错误和响应格式错误使用 `ProductPulseError`，包含 `status`、`code` 和 `message`。
