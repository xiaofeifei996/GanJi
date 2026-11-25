# Widget 背景与签名权限

## 为什么旧版正常，证书侧载后却报 permission denied？

`/var/mobile/Library/GanJi` 不是普通沙盒 App 的共享容器。旧 iOS 16 + TrollStore 环境的权限表现，不能作为新版 iOS / 普通证书侧载的保证。写入该目录被拒绝是沙盒权限问题，修改图片格式、创建目录或重试写入不能授予访问权。

App 与 Widget 是独立进程、独立沙盒。正常证书安装时，应通过双方有权访问的 App Group 共享背景数据，而不是直接访问固定的 `/var/mobile/...` 路径。代码、Info.plist 配置键、甚至单独往签名里塞 entitlement，都不能代替开发者后台授权及 provisioning profile。

## 正常证书打包要求

1. 在同一个 Apple Developer 团队下，为主 App 和每个 Widget 的独立 Bundle ID 启用 App Groups。
2. 给双方关联**同一个实际注册的 `group.*` 标识**；所有 Widget 必须至少共享同一个组。使用所属团队有权配置该能力的账号。
3. 修改能力后，分别重新生成、下载主 App 与各 Widget 的 provisioning profile。不能只更新主 App 的 profile，也不能把主 App 的 profile 直接复制给扩展。
4. 主 App 和每个 Widget 的实际签名 entitlements 都须包含该组，且被各自 profile 精确授权；TeamIdentifier 必须一致。
5. 签名/重签工具必须保留 `PlugIns/*.appex`、正确的 WidgetKit 扩展声明、组权限及各自 profile，不能删除扩展、剥离 App Group 或给不同 bundle 混用 profile。
6. 对**最终重签后准备分发的包**运行预检，再在目标设备验证设置背景和 Widget 展示。

运行时自定义组可使用 `GanJiAppGroupID` 配置键；该键的接入和 profile 自动检测由运行时代码的独立改动实现，不属于本工具。无论通过哪种方式选择组，都必须与真实签名及授权一致；配置键不能创建权限。

## 只读预检工具

要求 macOS、Python 3 标准库、Apple 的 `codesign` 与 `security`。不需要第三方 Python 依赖。先解包 IPA，再传入 `.app` 目录，例如：

```sh
unzip GanJi.ipa -d /tmp/ganji-check
python3 Tools/check_widget_signing.py /tmp/ganji-check/Payload/GanJi.app
```

工具从主 App 的 `PlugIns/*.appex/Info.plist` 识别**全部 WidgetKit 扩展**（`com.apple.widgetkit-extension`），逐个执行：

```sh
codesign -d --entitlements :- /path/to/GanJi.app
security cms -D -i /path/to/GanJi.app/embedded.mobileprovision
# 对每个 Widget .appex 执行相同的只读命令。
```

它读取最终签名中的真实 entitlements，而非源码中的 `.entitlements` 文件，检查：

- 存在 WidgetKit 扩展，主 App 和所有 Widget 有共同的具体 App Group；
- 每个 bundle 声明的全部 App Group 均获其自己 profile 的精确授权，不把 `group.*` 通配符当作授权；
- 签名团队与自身 profile 一致，主 App 和各 Widget 的 TeamIdentifier 相同；
- 正常模式下，每个 bundle 都必须有可解析的 profile。存在但损坏/不匹配的 profile 不能靠参数绕过。

退出码：`0` 为本工具范围内通过，`1` 为权限预检失败，`2` 为命令行参数错误。结果只显示简短结论、组标识、团队标识和修复建议；不输出完整 profile、证书内容或原始命令错误输出。工具不会签名、修改包、访问钥匙串或读取/输出私钥。`security cms` 仅解析包内 profile，其中可能包含公开证书数据，工具不会输出这些数据。

### 未配置 / TrollStore / ad-hoc 测试

缺少 `embedded.mobileprovision` 默认失败，并明确提示 unsigned/TrollStore/ad-hoc 未配置模式。仅在已经制作好的本地 ad-hoc 等测试包上，可显式允许缺 profile：

```sh
python3 Tools/check_widget_signing.py /path/to/GanJi.app --allow-unprovisioned
```

此选项仅放宽“缺 profile”，**不表示普通证书侧载可用**，也不授予任何权限。仍须能用 `codesign` 读到真实 entitlements，且主 App 和所有 Widget 必须有共同 App Group；已知的 TeamIdentifier 不一致仍失败。完全没有可读签名的 unsigned 包不会通过。未配置包的团队信息可能不可验证，工具会明确警告；不要把这类通过结果当作正常证书授权证明。

### 检查边界

这是共享组/签名权限预检，不是 Apple 完整安装验证器。它不验证证书链、签名完整性、profile 有效期、设备 UDID、所有其他 entitlement，也不保证 iOS 26 的实际安装、Widget 刷新或图片渲染成功。通过后仍应进行正常的签名验证与真机测试。若工具显示缺扩展或缺组，应修正打包/签名流程，而不是回退到无权限目录。

## 跨平台测试

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_widget_signing.py' -v
```

测试用临时 bundle、plist 和 mock 命令输出模拟主 App/多个 Widget、团队/profile/组不匹配、未配置模式、工具不可用及损坏 plist，不依赖 macOS，不使用真实证书或密钥。
