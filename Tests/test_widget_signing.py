"""Portable mock fixtures: no macOS, signing identity or real profile required."""
import contextlib
import importlib.util
import io
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "widget_signing", Path(__file__).resolve().parents[1] / "Tools/check_widget_signing.py")
signing = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(signing)
GROUP = "group.test.ganji"
TEAM = "TEAM123456"


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "GanJi.app"
        self.entitlements = {}
        self.profiles = {}
        self.commands = []
        self.add_bundle(self.app)
        self.widget = self.app / "PlugIns/GanJiWidget.appex"
        self.add_bundle(self.widget, widget=True)
        mock = patch.object(signing.subprocess, "run", side_effect=self.run_command)
        self.run_mock = mock.start()
        self.addCleanup(mock.stop)

    def add_bundle(self, path, widget=False):
        path.mkdir(parents=True)
        info = {"CFBundleIdentifier": "test." + path.stem}
        if widget:
            info["NSExtension"] = {"NSExtensionPointIdentifier": signing.WIDGET}
        (path / "Info.plist").write_bytes(plistlib.dumps(info))
        (path / "embedded.mobileprovision").write_bytes(b"mock CMS")
        self.entitlements[path] = {signing.GROUPS: [GROUP], signing.TEAM: TEAM}
        self.profiles[path] = {"TeamIdentifier": [TEAM], "Entitlements": {
            signing.GROUPS: [GROUP], signing.TEAM: TEAM},
            "DeveloperCertificates": [b"SECRET_CERTIFICATE_DATA"]}

    def run_command(self, command, **kwargs):
        self.commands.append(command)
        if command[0] == "codesign":
            self.assertEqual(command[:4], ["codesign", "-d", "--entitlements", ":-"])
            data = self.entitlements[Path(command[-1])]
        else:
            self.assertEqual(command[:4], ["security", "cms", "-D", "-i"])
            data = self.profiles[Path(command[-1]).parent]
        return subprocess.CompletedProcess(command, 0, plistlib.dumps(data), b"diagnostic")

    def assert_failure(self, message, allow=False):
        with self.assertRaisesRegex(signing.CheckError, message):
            signing.check(self.app, allow)

    def remove_profiles(self):
        for bundle in self.profiles:
            (bundle / "embedded.mobileprovision").unlink()

    def test_valid_profiles_and_read_only_commands(self):
        result = signing.check(self.app)
        self.assertEqual(result["groups"], [GROUP])
        self.assertEqual(result["team"], TEAM)
        self.assertEqual(result["warnings"], [])
        self.assertEqual(len(self.commands), 4)

    def test_all_widget_extensions_checked(self):
        second = self.app / "PlugIns/AnotherWidget.appex"
        self.add_bundle(second, widget=True)
        self.assertEqual(len(signing.check(self.app)["bundles"]), 3)
        self.entitlements[second][signing.GROUPS] = ["group.other"]
        self.profiles[second]["Entitlements"][signing.GROUPS] = ["group.other"]
        self.assert_failure("没有共同 App Group")

    def test_non_widget_extension_ignored(self):
        self.add_bundle(self.app / "PlugIns/Share.appex")
        self.assertEqual(len(signing.check(self.app)["bundles"]), 2)

    def test_extension_removed(self):
        (self.widget / "Info.plist").write_bytes(plistlib.dumps({}))
        self.assert_failure("未找到 WidgetKit")

    def test_invalid_app_path(self):
        with self.assertRaisesRegex(signing.CheckError, "GanJi.app"):
            signing.check(self.app / "missing")

    def test_missing_profile_requires_explicit_option(self):
        (self.widget / "embedded.mobileprovision").unlink()
        self.assert_failure("unsigned/TrollStore/ad-hoc")

    def test_ad_hoc_without_teams_allowed_only_with_option(self):
        self.remove_profiles()
        for ent in self.entitlements.values():
            ent.pop(signing.TEAM)
        result = signing.check(self.app, True)
        self.assertIsNone(result["team"])
        self.assertIn("不代表普通证书可用", result["warnings"][-1])
        self.assertEqual(len(self.commands), 2)

    def test_no_common_group_fails_even_with_option(self):
        self.remove_profiles()
        self.entitlements[self.widget][signing.GROUPS] = ["group.other"]
        self.assert_failure("没有共同 App Group", allow=True)

    def test_missing_groups_fail_even_with_option(self):
        self.remove_profiles()
        self.entitlements[self.widget].pop(signing.GROUPS)
        self.assert_failure("缺少有效 App Group", allow=True)

    def test_group_must_be_authorized_by_each_profile(self):
        self.profiles[self.widget]["Entitlements"][signing.GROUPS] = []
        self.assert_failure("未获其 profile 精确授权", allow=True)

    def test_all_claimed_groups_must_be_authorized(self):
        self.entitlements[self.app][signing.GROUPS].append("group.extra")
        self.assert_failure("未获其 profile 精确授权")

    def test_profile_wildcard_does_not_grant_group(self):
        self.profiles[self.widget]["Entitlements"][signing.GROUPS] = ["group.*"]
        self.assert_failure("未获其 profile 精确授权")

    def test_different_teams_fail(self):
        other = "OTHERTEAM1"
        self.entitlements[self.widget][signing.TEAM] = other
        self.profiles[self.widget]["TeamIdentifier"] = [other]
        self.profiles[self.widget]["Entitlements"][signing.TEAM] = other
        self.assert_failure("TeamIdentifier 不同")

    def test_unprovisioned_different_teams_still_fail(self):
        self.remove_profiles()
        self.entitlements[self.widget][signing.TEAM] = "OTHERTEAM1"
        self.assert_failure("TeamIdentifier 不同", allow=True)

    def test_signed_team_must_match_profile(self):
        self.profiles[self.app]["TeamIdentifier"] = ["OTHERTEAM1"]
        self.assert_failure("不属于其 profile")

    def test_profile_entitlement_team_must_match(self):
        self.profiles[self.widget]["Entitlements"][signing.TEAM] = "OTHERTEAM1"
        self.assert_failure("profile Entitlements 的 TeamIdentifier")

    def test_provisioned_bundle_requires_signed_team(self):
        self.entitlements[self.app].pop(signing.TEAM)
        self.assert_failure("TeamIdentifier 缺失", allow=True)

    def test_invalid_entitlement_type(self):
        self.entitlements[self.widget][signing.GROUPS] = GROUP
        self.assert_failure("字符串组成的数组")

    def test_missing_macos_tool(self):
        self.run_mock.side_effect = FileNotFoundError()
        self.assert_failure("macOS")

    def test_failed_command_does_not_echo_secrets(self):
        self.run_mock.side_effect = None
        self.run_mock.return_value = subprocess.CompletedProcess(
            [], 1, b"SECRET_CERTIFICATE_DATA", b"SECRET_CERTIFICATE_DATA")
        out = io.StringIO()
        with contextlib.redirect_stderr(out):
            self.assertEqual(signing.main([str(self.app)]), 1)
        self.assertIn("读取失败", out.getvalue())
        self.assertNotIn("SECRET_CERTIFICATE_DATA", out.getvalue())

    def test_invalid_plist_from_command(self):
        self.run_mock.side_effect = None
        self.run_mock.return_value = subprocess.CompletedProcess([], 0, b"<?xml broken", b"")
        self.assert_failure("有效 plist")

    def test_corrupt_info_plist(self):
        (self.widget / "Info.plist").write_bytes(b"<?xml broken")
        self.assert_failure("无法读取")

    def test_cli_output_no_certificate_data(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(signing.main([str(self.app)]), 0)
        self.assertIn("PASS", out.getvalue())
        self.assertNotIn("SECRET_CERTIFICATE_DATA", out.getvalue())


if __name__ == "__main__":
    unittest.main()
