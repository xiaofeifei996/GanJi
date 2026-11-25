#!/usr/bin/env python3
"""Read-only GanJi/WidgetKit signing preflight (Python 3 standard library)."""
import argparse
import plistlib
import subprocess
import sys
from pathlib import Path
from xml.parsers.expat import ExpatError

GROUPS = "com.apple.security.application-groups"
TEAM = "com.apple.developer.team-identifier"
WIDGET = "com.apple.widgetkit-extension"


class CheckError(Exception):
    pass


def read_plist(path):
    try:
        with path.open("rb") as stream:
            data = plistlib.load(stream)
        if not isinstance(data, dict):
            raise ValueError("plist 根节点不是字典")
        return data
    except (OSError, ValueError, plistlib.InvalidFileException, ExpatError) as exc:
        raise CheckError("无法读取 {}: {}".format(path, exc)) from exc


def command_plist(command, label):
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, check=False)
    except OSError as exc:
        raise CheckError("{}: 无法运行 {}；请在装有 Apple 签名工具的 macOS 上检查".
                         format(label, command[0])) from exc
    # Do not echo raw tool output: a provisioning profile contains certificate data.
    if result.returncode:
        raise CheckError("{}: {} 读取失败（退出码 {}）；请检查签名/描述文件是否完整".
                         format(label, command[0], result.returncode))
    try:
        data = plistlib.loads(result.stdout)
        if not isinstance(data, dict):
            raise ValueError("not a dictionary")
        return data
    except (ValueError, plistlib.InvalidFileException, ExpatError) as exc:
        raise CheckError("{}: {} 未返回有效 plist；无法验证真实签名权限".
                         format(label, command[0])) from exc


def string_list(value, label):
    if not isinstance(value, list) or any(not isinstance(x, str) or not x for x in value):
        raise CheckError("{} 必须是非空字符串组成的数组".format(label))
    return set(value)


def widget_bundles(app):
    if not app.is_dir() or app.suffix != ".app":
        raise CheckError("请传入解包后的 GanJi.app 目录（不是 IPA 文件）")
    read_plist(app / "Info.plist")
    widgets = []
    plugins = app / "PlugIns"
    if plugins.is_dir():
        for extension in sorted(plugins.glob("*.appex")):
            info = read_plist(extension / "Info.plist")
            metadata = info.get("NSExtension", {})
            if not isinstance(metadata, dict):
                raise CheckError("{}: NSExtension 格式无效".format(extension.name))
            if metadata.get("NSExtensionPointIdentifier") == WIDGET:
                widgets.append(extension)
    if not widgets:
        raise CheckError("未找到 WidgetKit 扩展；请保留并嵌入 PlugIns/*.appex，签名器不可删除扩展")
    return widgets


def check(app, allow_unprovisioned=False):
    app = Path(app)
    bundles = [app] + widget_bundles(app)
    common_groups = None
    teams = set()
    warnings = []
    checked = []
    for bundle in bundles:
        label = bundle.name
        ent = command_plist(["codesign", "-d", "--entitlements", ":-", str(bundle)], label)
        groups = string_list(ent.get(GROUPS, []), label + " App Groups")
        if not groups or any(not group.startswith("group.") or "*" in group for group in groups):
            raise CheckError("{}: 缺少有效 App Group；请为主 App 和所有 Widget 配置同一个具体 group.*".
                             format(label))
        common_groups = groups if common_groups is None else common_groups & groups
        team = ent.get(TEAM)
        if team is not None and (not isinstance(team, str) or not team):
            raise CheckError("{}: 签名中的 TeamIdentifier 无效".format(label))
        if team:
            teams.add(team)
        profile_path = bundle / "embedded.mobileprovision"
        if not profile_path.is_file():
            if not allow_unprovisioned:
                raise CheckError("{}: 缺少 embedded.mobileprovision，属于 unsigned/TrollStore/ad-hoc "
                                 "未配置模式；仅已有 ad-hoc 测试可显式使用 --allow-unprovisioned，"
                                 "普通证书侧载必须补齐各自 profile".format(label))
            warnings.append("{}: 未配置 profile（unsigned/TrollStore/ad-hoc 模式），无法证明证书授权".
                            format(label))
        else:
            profile = command_plist(["security", "cms", "-D", "-i", str(profile_path)], label)
            profile_teams = string_list(profile.get("TeamIdentifier", []), label + " profile TeamIdentifier")
            profile_ent = profile.get("Entitlements")
            if not isinstance(profile_ent, dict):
                raise CheckError("{}: profile 缺少 Entitlements".format(label))
            if not team or not profile_teams or team not in profile_teams:
                raise CheckError("{}: 签名 TeamIdentifier 缺失或不属于其 profile；请用同一开发团队重新签名".
                                 format(label))
            teams.update(profile_teams)
            profile_ent_team = profile_ent.get(TEAM)
            if profile_ent_team is not None and profile_ent_team != team:
                raise CheckError("{}: profile Entitlements 的 TeamIdentifier 与签名不一致".format(label))
            authorized = string_list(profile_ent.get(GROUPS, []), label + " profile App Groups")
            if not groups <= authorized:
                raise CheckError("{}: 签名 App Group 未获其 profile 精确授权；请启用相同组并重新生成该 target 的 profile".
                                 format(label))
        checked.append(label)
    if not common_groups:
        raise CheckError("主 App 与所有 Widget 没有共同 App Group；--allow-unprovisioned 也不能跳过此检查")
    if len(teams) > 1:
        raise CheckError("主 App/Widget 的 TeamIdentifier 不同；请使用同一开发团队的各自 profile 和签名")
    if warnings:
        warnings.append("此结果只适用于未配置测试；不代表普通证书可用，也不授予系统容器访问权限")
    return {"bundles": checked, "groups": sorted(common_groups),
            "team": next(iter(teams)) if teams else None, "warnings": warnings}


def main(argv=None):
    parser = argparse.ArgumentParser(description="只读检查主 App 与所有 WidgetKit 扩展的真实签名和 App Group 授权")
    parser.add_argument("app", type=Path, help="解包后的 GanJi.app 路径（在 macOS 执行）")
    parser.add_argument("--allow-unprovisioned", action="store_true",
                        help="允许缺 profile 的已有 unsigned/TrollStore/ad-hoc 测试；不豁免共同组/团队检查")
    args = parser.parse_args(argv)
    try:
        result = check(args.app, args.allow_unprovisioned)
    except CheckError as exc:
        print("FAIL: {}".format(exc), file=sys.stderr)
        print("建议：为 App 和 Widget 启用相同 App Group，生成各自 profile；签名器须保留扩展及组权限。",
              file=sys.stderr)
        return 1
    mode = "未配置测试预检通过" if result["warnings"] else "签名权限预检通过"
    print("PASS: {}（{} 个 bundle）".format(mode, len(result["bundles"])))
    print("共同 App Group: " + ", ".join(result["groups"]))
    print("TeamIdentifier: " + (result["team"] or "不可验证（未配置模式）"))
    for warning in result["warnings"]:
        print("WARN: " + warning)
    return 0


if __name__ == "__main__":
    sys.exit(main())
