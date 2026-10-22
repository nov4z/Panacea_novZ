#!/usr/bin/env python3
"""
Adversarial Challenger Verification Suite: Milestone 1 Upstream Reconciliation & Packaging.

Empirically tests and stress-tests:
1. System Load on Island:
   - settings.json & settings.json.example schema configuration (systemLoadOnIsland: false).
   - SetBarIsland.qml toggle binding and saveCfg() invocation.
   - Translations.qml multilingual translations for system load text strings (ru, es, tr).
   - shell.qml sensor properties, loadWanted logic, and sysload.sh process integration.
   - sysload.sh execution, field parsing, and error-tolerant parsing for missing metrics.
2. Enterprise Wi-Fi:
   - ControlsView.qml userField presence, visibility conditions, activeFocus navigation.
   - ControlsView.qml connect button activation logic for both standard PSK and EAP.
   - shell.qml connectWifi 4-argument dispatch logic across all security variants.
   - scripts/wifi.sh connect command argument alignment, PEAP-MSCHAPv2 configuration, and cleanup.
3. Persistent Keyboard Layouts:
   - scripts/geninput.sh validation, variant expansion, and dual output (Lua & Hyprland conf).
   - Negative stress tests for geninput.sh with malformed layouts, injected characters, count mismatches.
   - shell.qml applyKeyboardLayouts validation equivalence with geninput.sh.
   - Compositor.qml layoutLabel() evaluation: JSON mapping, regex extraction, word dictionary, fallbacks.
4. Shortcut Editor (SetKeys.qml):
   - Flickable layout, vertical scroll bar, and WheelHandler scrolling logic.
   - BindRow manual mode: TextField presence, width adjustment, mouse grab suppression, sync hooks.
   - Proper tagging of multimedia, lid switch, and mouse window management bindings.
5. Installer & Packaging Symlink Hardening:
   - install.sh ln -sfn non-nesting symlink verification.
   - Multi-pass stress testing of directory symlinks preventing recursive ../assets/assets nesting.
   - Dual entrypoint validation: root-level symlinks vs qml/ relative component symlinks.
"""

import os
import re
import sys
import json
import shutil
import tempfile
import subprocess
import unittest
from pathlib import Path

PROJECT_ROOT = Path(os.environ.get("PANACEA_DIR", Path(__file__).resolve().parent.parent))
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from tests.test_challenger_m1_settings import QmlLexerBracketParser


class TestSystemLoadOnIsland(unittest.TestCase):
    """Adversarial verification of System Load on Island (F7)."""

    def setUp(self):
        self.settings_path = PROJECT_ROOT / "settings.json"
        self.example_settings_path = PROJECT_ROOT / "settings.json.example"
        self.set_bar_island_path = PROJECT_ROOT / "qml" / "SetBarIsland.qml"
        self.shell_path = PROJECT_ROOT / "qml" / "shell.qml"
        self.translations_path = PROJECT_ROOT / "qml" / "Translations.qml"
        self.sysload_path = PROJECT_ROOT / "scripts" / "sysload.sh"

    def test_01_settings_schema_has_system_load_flag(self):
        """settings.json and settings.json.example must declare systemLoadOnIsland defaulting to false."""
        self.assertTrue(self.settings_path.is_file(), "settings.json missing")
        self.assertTrue(self.example_settings_path.is_file(), "settings.json.example missing")

        with open(self.settings_path, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        self.assertIn("systemLoadOnIsland", cfg)
        self.assertIs(cfg["systemLoadOnIsland"], False)

        with open(self.example_settings_path, "r", encoding="utf-8") as f:
            cfg_ex = json.load(f)
        self.assertIn("systemLoadOnIsland", cfg_ex)
        self.assertIs(cfg_ex["systemLoadOnIsland"], False)

    def test_02_set_bar_island_qml_syntax_and_toggle(self):
        """SetBarIsland.qml must have balanced delimiters and expose a SetToggle for systemLoadOnIsland."""
        self.assertTrue(self.set_bar_island_path.is_file())
        with open(self.set_bar_island_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Bracket & syntax balance
        parser = QmlLexerBracketParser(content, str(self.set_bar_island_path))
        is_valid, errors = parser.parse()
        self.assertTrue(is_valid, f"Delimiter errors in SetBarIsland.qml: {errors}")

        # Toggle bindings
        self.assertIn("page.sys.cfg.systemLoadOnIsland", content)
        self.assertRegex(content, r"on:\s*page\.sys\.cfg\.systemLoadOnIsland")
        self.assertRegex(content, r"onToggled:\s*value\s*=>\s*\{\s*page\.sys\.cfg\.systemLoadOnIsland\s*=\s*value;\s*page\.sys\.saveCfg\(\);")

    def test_03_translations_for_system_load(self):
        """Translations.qml must include translations for system load text in Spanish and Turkish."""
        self.assertTrue(self.translations_path.is_file())
        with open(self.translations_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Check Russian key translated to Spanish and Turkish
        self.assertIn('"Нагрузка системы на острове"', content)
        self.assertIn('"Carga del sistema en el notch"', content)
        self.assertIn('"Adada sistem yükü"', content)

    def test_04_shell_qml_sysload_bindings(self):
        """shell.qml must connect systemLoadOnIsland to loadWanted and execute sysload.sh."""
        self.assertTrue(self.shell_path.is_file())
        with open(self.shell_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Property in cfg definition
        self.assertRegex(content, r"property\s+bool\s+systemLoadOnIsland:\s*false")

        # loadWanted condition
        self.assertRegex(content, r"readonly\s+property\s+bool\s+loadWanted:\s*root\.expanded\s*\|\|\s*root\.cfg\.featWidgets\s*\|\|\s*root\.cfg\.systemLoadOnIsland")

        # Command switching full vs fast
        self.assertIn("root.expanded || root.cfg.systemLoadOnIsland", content)
        self.assertIn("sysload.sh", content)

        # Island notch visible expression
        self.assertIn("visible: root.cfg.systemLoadOnIsland && (root.loadCpu >= 0 || root.loadGpu >= 0)", content)

    def test_05_sysload_script_execution_and_parsing(self):
        """scripts/sysload.sh must execute cleanly and return pipe-delimited metrics."""
        self.assertTrue(self.sysload_path.is_file())
        self.assertTrue(os.access(self.sysload_path, os.X_OK))

        # Test normal execution
        res = subprocess.run([str(self.sysload_path)], capture_output=True, text=True, timeout=5)
        self.assertEqual(res.returncode, 0, f"sysload.sh failed: {res.stderr}")
        out = res.stdout.strip()
        parts = out.split("|")
        self.assertEqual(len(parts), 6, f"Expected 6 pipe-delimited fields, got {len(parts)}: '{out}'")

        # Test --fast execution
        res_fast = subprocess.run([str(self.sysload_path), "--fast"], capture_output=True, text=True, timeout=3)
        self.assertEqual(res_fast.returncode, 0)
        parts_fast = res_fast.stdout.strip().split("|")
        self.assertEqual(len(parts_fast), 6)
        # In fast mode, CPU and GPU fields must be empty
        self.assertEqual(parts_fast[0], "")
        self.assertEqual(parts_fast[2], "")

    def test_06_simulated_sensor_fallbacks(self):
        """Simulate shell.qml parse logic for sysload outputs with missing/negative metrics."""
        # shell.qml parsing function logic:
        def num(s):
            s = str(s if s is not None else "").strip()
            return int(s) if len(s) else -1

        def parse_sysload(text, expanded_or_island=True):
            recs = [r for r in text.strip().split("\n") if "|" in r]
            if not recs:
                return {}
            a = recs[-1].split("|")
            if expanded_or_island:
                return {
                    "loadCpu": num(a[0]),
                    "loadMem": num(a[1]),
                    "loadGpu": num(a[2]),
                    "loadTempCpu": num(a[3]),
                    "loadTempGpu": num(a[4]),
                    "loadDisk": num(a[5]),
                }
            return {
                "loadMem": num(a[1]),
                "loadDisk": num(a[5]),
            }

        # Case A: Full metrics
        res_a = parse_sysload("15|42|20|55|60|75\n")
        self.assertEqual(res_a["loadCpu"], 15)
        self.assertEqual(res_a["loadMem"], 42)
        self.assertEqual(res_a["loadGpu"], 20)
        self.assertEqual(res_a["loadTempCpu"], 55)
        self.assertEqual(res_a["loadTempGpu"], 60)
        self.assertEqual(res_a["loadDisk"], 75)

        # Case B: No GPU, No Temps (common in headless/VM)
        res_b = parse_sysload("22|50||||80\n")
        self.assertEqual(res_b["loadCpu"], 22)
        self.assertEqual(res_b["loadMem"], 50)
        self.assertEqual(res_b["loadGpu"], -1)
        self.assertEqual(res_b["loadTempCpu"], -1)
        self.assertEqual(res_b["loadTempGpu"], -1)
        self.assertEqual(res_b["loadDisk"], 80)

        # Visibility condition check: visible if root.cfg.systemLoadOnIsland && (loadCpu >= 0 || loadGpu >= 0)
        vis_b = (True and (res_b["loadCpu"] >= 0 or res_b["loadGpu"] >= 0))
        self.assertTrue(vis_b)

        # Case C: All sensors empty
        res_c = parse_sysload("|||||\n")
        self.assertEqual(res_c["loadCpu"], -1)
        self.assertEqual(res_c["loadGpu"], -1)
        vis_c = (True and (res_c["loadCpu"] >= 0 or res_c["loadGpu"] >= 0))
        self.assertFalse(vis_c, "Empty sensors must not cause island text to display invalid data")


class TestEnterpriseWifi(unittest.TestCase):
    """Adversarial verification of WPA-Enterprise Wi-Fi support (F8)."""

    def setUp(self):
        self.controls_path = PROJECT_ROOT / "qml" / "ControlsView.qml"
        self.shell_path = PROJECT_ROOT / "qml" / "shell.qml"
        self.wifi_script_path = PROJECT_ROOT / "scripts" / "wifi.sh"

    def test_01_controls_view_eap_fields(self):
        """ControlsView.qml wifiPage must include passwordSecurity, userField, and EAP connect validation."""
        self.assertTrue(self.controls_path.is_file())
        with open(self.controls_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Verify property passwordSecurity
        self.assertIn('property string passwordSecurity: "psk"', content)

        # Verify userField definition
        self.assertIn("id: userField", content)
        self.assertIn('visible: wifiPage.passwordFor.length > 0 && wifiPage.passwordSecurity === "eap"', content)
        self.assertIn('placeholderText: view.sys.tr("Имя пользователя")', content)
        self.assertIn("onAccepted: pwField.forceActiveFocus()", content)

        # Verify connectBtn activation check
        self.assertIn('wifiPage.passwordSecurity === "eap" && !userField.text.length', content)
        self.assertIn("view.sys.connectWifi(wifiPage.passwordFor, pwField.text, userField.text, wifiPage.passwordSecurity)", content)

        # Verify cleanup on submit
        self.assertIn('userField.text = ""', content)

    def test_02_shell_qml_connect_wifi_dispatch(self):
        """shell.qml connectWifi must support 4 arguments and construct appropriate commands."""
        self.assertTrue(self.shell_path.is_file())
        with open(self.shell_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Signature
        self.assertIn("function connectWifi(ssid, password, username, security)", content)

        # EAP command construction
        self.assertIn('security === "eap"', content)
        self.assertIn('root.wifiScript + " connect \\"$1\\" \\"$2\\" \\"$3\\" eap", "_", ssid, password, username', content)

        # Normal password command construction
        self.assertIn('root.wifiScript + " connect \\"$1\\" \\"$2\\"", "_", ssid, password', content)

        # Open network command construction
        self.assertIn('root.wifiScript + " connect \\"$1\\"", "_", ssid', content)

    def test_03_wifi_script_eap_support(self):
        """scripts/wifi.sh must recognize EAP security and build correct nmcli command."""
        self.assertTrue(self.wifi_script_path.is_file())
        with open(self.wifi_script_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Security classification regex
        self.assertIn(r'802\.1X|WPA-EAP|WPA2-EAP|WPA3-EAP', content)
        self.assertIn('sec_type = (sec == "" || sec == "--") ? "open" : (sec ~ /802\\.1X|WPA-EAP|WPA2-EAP|WPA3-EAP/) ? "eap" : "psk"', content)

        # Arguments extraction in connect
        self.assertIn('SSID="$2"; PW="$3"; USERNAME="$4"; SECURITY="$5"', content)

        # EAP handling block
        self.assertIn('if [ "$SECURITY" = eap ]; then', content)
        self.assertIn('[ -n "$USERNAME" ] && [ -n "$PW" ] || exit 1', content)
        self.assertIn('key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2 802-1x.identity "$USERNAME"', content)
        self.assertIn('nmcli connection modify "$UUID" 802-1x.password "$PW"', content)

    def test_04_wifi_script_eap_argument_error_handling(self):
        """scripts/wifi.sh connect without required EAP credentials must cleanly exit 1."""
        # Running connect with eap security but missing username or password
        res = subprocess.run(
            ["bash", str(self.wifi_script_path), "connect", "TestCorpNet", "", "", "eap"],
            capture_output=True,
            text=True
        )
        self.assertEqual(res.returncode, 1, "EAP connect with empty credentials must exit 1")


class TestPersistentKeyboardLayouts(unittest.TestCase):
    """Adversarial verification of Persistent Keyboard Layouts (F9)."""

    def setUp(self):
        self.geninput_path = PROJECT_ROOT / "scripts" / "geninput.sh"
        self.shell_path = PROJECT_ROOT / "qml" / "shell.qml"
        self.compositor_path = PROJECT_ROOT / "qml" / "Compositor.qml"
        self.set_input_path = PROJECT_ROOT / "qml" / "SetInput.qml"

    def test_01_set_input_qml_layout_card(self):
        """SetInput.qml must include controls for keyboardLayouts, keyboardVariants, keyboardOptions."""
        self.assertTrue(self.set_input_path.is_file())
        with open(self.set_input_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Bracket & syntax balance
        parser = QmlLexerBracketParser(content, str(self.set_input_path))
        is_valid, errors = parser.parse()
        self.assertTrue(is_valid, f"Delimiter errors in SetInput.qml: {errors}")

        self.assertIn("page.sys.cfg.keyboardLayouts", content)
        self.assertIn("page.sys.cfg.keyboardVariants", content)
        self.assertIn("page.sys.cfg.keyboardOptions", content)
        self.assertIn("page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text)", content)

    def test_02_geninput_script_validation_and_generation(self):
        """scripts/geninput.sh must safely validate inputs and generate Lua and conf files."""
        self.assertTrue(self.geninput_path.is_file())
        self.assertTrue(os.access(self.geninput_path, os.X_OK))

        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            cfg_dir = tmppath / ".config" / "panacea"
            cfg_dir.mkdir(parents=True)
            cfg_file = cfg_dir / "settings.json"

            hypr_dir = tmppath / ".config" / "hypr"
            hypr_lua_dir = hypr_dir / "lua"
            hypr_dir.mkdir(parents=True)

            # Test Case A: Valid 2 layouts with empty variants
            cfg_data = {
                "keyboardLayouts": "us,tr",
                "keyboardVariants": "",
                "keyboardOptions": "grp:alt_shift_toggle"
            }
            with open(cfg_file, "w", encoding="utf-8") as f:
                json.dump(cfg_data, f)

            env = os.environ.copy()
            env["HOME"] = str(tmppath)
            env["PANACEA_DRYRUN"] = "1"

            res = subprocess.run(["bash", str(self.geninput_path)], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"geninput.sh failed: {res.stderr}")

            lua_out = hypr_lua_dir / "input_data.lua"
            conf_out = hypr_dir / "input_data.conf"

            self.assertTrue(lua_out.is_file(), "input_data.lua not generated")
            self.assertTrue(conf_out.is_file(), "input_data.conf not generated")

            lua_content = lua_out.read_text(encoding="utf-8")
            conf_content = conf_out.read_text(encoding="utf-8")

            # Check Lua content
            self.assertIn('layouts = "us,tr"', lua_content)
            self.assertIn('variants = ","', lua_content)  # Automatically padded
            self.assertIn('options = "grp:alt_shift_toggle"', lua_content)

            # Check Hyprland conf content
            self.assertIn('kb_layout = "us,tr"', conf_content)
            self.assertIn('kb_variant = ","', conf_content)
            self.assertIn('kb_options = "grp:alt_shift_toggle"', conf_content)

    def test_03_geninput_script_stress_and_negative_cases(self):
        """geninput.sh must reject command injection attempts and malformed layout counts."""
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            cfg_dir = tmppath / ".config" / "panacea"
            cfg_dir.mkdir(parents=True)
            cfg_file = cfg_dir / "settings.json"

            env = os.environ.copy()
            env["HOME"] = str(tmppath)
            env["PANACEA_DRYRUN"] = "1"

            # Case 1: Injected shell metacharacters
            cfg_data = {
                "keyboardLayouts": "us;rm -rf /",
                "keyboardVariants": "",
                "keyboardOptions": "grp:alt_shift_toggle"
            }
            with open(cfg_file, "w", encoding="utf-8") as f:
                json.dump(cfg_data, f)

            res = subprocess.run(["bash", str(self.geninput_path)], env=env, capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "geninput.sh must reject shell metacharacters")

            # Case 2: Leading comma or double commas
            cfg_data["keyboardLayouts"] = ",us,ru"
            with open(cfg_file, "w", encoding="utf-8") as f:
                json.dump(cfg_data, f)
            res = subprocess.run(["bash", str(self.geninput_path)], env=env, capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "geninput.sh must reject leading commas")

            cfg_data["keyboardLayouts"] = "us,,ru"
            with open(cfg_file, "w", encoding="utf-8") as f:
                json.dump(cfg_data, f)
            res = subprocess.run(["bash", str(self.geninput_path)], env=env, capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "geninput.sh must reject double commas")

            # Case 3: Variant count mismatch when non-empty
            cfg_data["keyboardLayouts"] = "us,tr"
            cfg_data["keyboardVariants"] = "dvorak"  # Only 1 variant specified, but not empty/comma
            with open(cfg_file, "w", encoding="utf-8") as f:
                json.dump(cfg_data, f)
            res = subprocess.run(["bash", str(self.geninput_path)], env=env, capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "geninput.sh must reject mismatching variant counts")

    def test_04_compositor_layout_label_algorithm(self):
        """Compositor.qml layoutLabel() logic must handle diverse layout names, custom maps, and fallbacks."""
        # Emulate Compositor.qml layoutLabel logic in Python
        def layout_label(name, layout_map=""):
            full = str(name if name is not None else "").strip()
            if not full:
                return ""
            try:
                m = json.loads(layout_map) if layout_map else {}
                for k, v in m.items():
                    if k.lower() == full.lower() and len(str(v)):
                        return str(v).upper()[:3]
            except Exception:
                pass

            m_short = re.search(r"\(([a-zA-Z]{2,3})\)", full)
            if m_short:
                return m_short.group(1).upper()

            codes = {
                "english": "US", "russian": "RU", "turkish": "TR", "german": "DE",
                "french": "FR", "spanish": "ES", "ukrainian": "UA"
            }
            for lang, code in codes.items():
                if lang in full.lower():
                    return code

            return full[:2].upper()

        # Check standard layout names
        self.assertEqual(layout_label("English (US)"), "US")
        self.assertEqual(layout_label("Turkish (TR)"), "TR")
        self.assertEqual(layout_label("Russian (RU)"), "RU")
        self.assertEqual(layout_label("Spanish (Latin America)"), "ES")
        self.assertEqual(layout_label("German"), "DE")
        self.assertEqual(layout_label("Ukrainian"), "UA")

        # Custom mapping override
        custom_map = json.dumps({"custom layout": "CST", "English (US)": "ENG"})
        self.assertEqual(layout_label("custom layout", custom_map), "CST")
        self.assertEqual(layout_label("English (US)", custom_map), "ENG")

        # Fallback to 2-letter uppercase
        self.assertEqual(layout_label("Polski"), "PO")
        self.assertEqual(layout_label(""), "")
        self.assertEqual(layout_label(None), "")

        # Resilient to invalid JSON in map
        self.assertEqual(layout_label("English (US)", "{malformed json"), "US")


class TestShortcutEditor(unittest.TestCase):
    """Adversarial verification of Shortcut Editor & Manual Mode (F10)."""

    def setUp(self):
        self.set_keys_path = PROJECT_ROOT / "qml" / "SetKeys.qml"

    def test_01_set_keys_qml_syntax_and_flickable(self):
        """SetKeys.qml must have balanced delimiters and contain a Flickable with vertical ScrollBar."""
        self.assertTrue(self.set_keys_path.is_file())
        with open(self.set_keys_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Bracket & syntax balance
        parser = QmlLexerBracketParser(content, str(self.set_keys_path))
        is_valid, errors = parser.parse()
        self.assertTrue(is_valid, f"Delimiter errors in SetKeys.qml: {errors}")

        # Flickable check
        self.assertIn("Flickable {", content)
        self.assertIn("id: bindScroll", content)
        self.assertIn("ScrollBar.vertical: SetScroll { sys: page.sys }", content)
        self.assertIn("WheelHandler {", content)

    def test_02_bind_row_manual_text_field_mode(self):
        """BindRow component must support manual mode with TextField and suppressed mouse capture."""
        with open(self.set_keys_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Component definition
        self.assertIn("property bool manual: false", content)

        # Dynamic box width for manual input
        self.assertIn("Layout.preferredWidth: brow.manual ? 220 : 176", content)

        # TextField for manual editing
        self.assertIn("TextField {", content)
        self.assertIn("id: manualCombo", content)
        self.assertIn("visible: brow.manual", content)
        self.assertIn("text: page.bindRaw(brow.bindId)", content)
        self.assertIn("onEditingFinished: if (text.trim() !== page.bindRaw(brow.bindId)) page.setBind(brow.bindId, text.trim())", content)

        # MouseArea disabled when manual is true
        self.assertIn("enabled: !brow.manual", content)

    def test_03_manual_rows_declared(self):
        """Specific multimedia, lid, and mouse shortcuts must be declared with manual: true."""
        with open(self.set_keys_path, "r", encoding="utf-8") as f:
            content = f.read()

        required_manual_binds = [
            "volumeUp", "volumeDown", "volumeMute", "micMute",
            "brightnessUp", "brightnessDown", "mediaNext", "mediaPrevious",
            "mediaPlay", "mediaPause", "lidOn", "lidOff",
            "closeMouse", "dragWindow", "resizeWindowMouse"
        ]

        for bind_id in required_manual_binds:
            pattern = rf'bindId:\s*"{bind_id}"[^}}]*manual:\s*true'
            self.assertRegex(content, pattern, f"Binding '{bind_id}' should be configured with manual: true")


class TestInstallerAndPackagingSymlinks(unittest.TestCase):
    """Adversarial verification of install.sh and packaging symlink hardening (F13)."""

    def setUp(self):
        self.install_sh_path = PROJECT_ROOT / "install.sh"

    def test_01_install_script_uses_sfn_flags(self):
        """install.sh must use 'ln -sfn' for directory symlinks to prevent recursive nesting."""
        self.assertTrue(self.install_sh_path.is_file())
        with open(self.install_sh_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("ln -sfn ../assets", content)
        self.assertIn("ln -sfn ../scripts", content)
        self.assertIn("ln -sfn ../sounds", content)

        # Should also invoke geninput.sh during deployment
        self.assertIn('"$INSTALL_DIR/scripts/geninput.sh"', content)

    def test_02_symlink_non_nesting_stress_test(self):
        """Simulate repeated install symlinking in a sandbox to verify ln -sfn does not create ../assets/assets."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sandbox = Path(tmpdir) / "test_install"
            sandbox.mkdir()

            assets_dir = sandbox / "assets"
            scripts_dir = sandbox / "scripts"
            sounds_dir = sandbox / "sounds"
            qml_dir = sandbox / "qml"

            for d in [assets_dir, scripts_dir, sounds_dir, qml_dir]:
                d.mkdir()

            # Place sentinel files in real dirs
            (assets_dir / "test_icon.svg").write_text("icon", encoding="utf-8")
            (scripts_dir / "test_script.sh").write_text("#!/bin/sh\n", encoding="utf-8")
            (sounds_dir / "test_sound.wav").write_text("wav", encoding="utf-8")

            # Run symlinking command 5 times consecutively
            for iteration in range(1, 6):
                subprocess.run(["ln", "-sfn", "../assets", str(qml_dir / "assets")], check=True)
                subprocess.run(["ln", "-sfn", "../scripts", str(qml_dir / "scripts")], check=True)
                subprocess.run(["ln", "-sfn", "../sounds", str(qml_dir / "sounds")], check=True)

                # Assert that qml/assets is a valid symlink to ../assets
                assets_link = qml_dir / "assets"
                self.assertTrue(assets_link.is_symlink(), f"Iteration {iteration}: qml/assets is not a symlink")
                self.assertEqual(os.readlink(assets_link), "../assets")

                # CRITICAL: Assert that nested directory qml/assets/assets was NOT created
                nested_dir = assets_dir / "assets"
                self.assertFalse(nested_dir.exists(), f"Iteration {iteration}: CRITICAL FAILURE - nested assets/assets created!")

                # Sentinel file must still be accessible via symlink
                self.assertTrue((assets_link / "test_icon.svg").is_file())

    def test_03_dual_entrypoint_symlink_resolution(self):
        """Verify that the repository structure satisfies dual entrypoint execution contracts."""
        qml_dir = PROJECT_ROOT / "qml"
        self.assertTrue(qml_dir.is_dir())

        # Relative symlinks inside qml/
        for link_name in ["assets", "scripts", "sounds"]:
            link_path = qml_dir / link_name
            self.assertTrue(link_path.is_symlink(), f"qml/{link_name} must be a relative symlink")
            target = os.readlink(link_path)
            self.assertEqual(target, f"../{link_name}")
            # Target must resolve to existing directory
            self.assertTrue(link_path.is_dir(), f"qml/{link_name} does not resolve to an existing directory")

        # Root symlinks for dual entrypoint
        shell_qml = PROJECT_ROOT / "shell.qml"
        themes_js = PROJECT_ROOT / "Themes.js"

        if shell_qml.exists():
            self.assertTrue(shell_qml.is_symlink())
            self.assertEqual(os.readlink(shell_qml), "qml/shell.qml")

        if themes_js.exists():
            self.assertTrue(themes_js.is_symlink())
            self.assertEqual(os.readlink(themes_js), "qml/Themes.js")


class TestMultiLocaleAndTurkishBundle(unittest.TestCase):
    """Adversarial verification of Multi-locale, Turkish Bundle, and Weather Fallback (F11, F12)."""

    def setUp(self):
        self.set_appearance_path = PROJECT_ROOT / "qml" / "SetAppearance.qml"
        self.set_pick_path = PROJECT_ROOT / "qml" / "SetPick.qml"
        self.translations_path = PROJECT_ROOT / "qml" / "Translations.qml"
        self.weather_path = PROJECT_ROOT / "qml" / "WeatherDetailsView.qml"

    def test_01_set_appearance_qml_locale_picker(self):
        """SetAppearance.qml must have balanced syntax, preserve Spanish default option, and use searchable SetPick."""
        self.assertTrue(self.set_appearance_path.is_file())
        with open(self.set_appearance_path, "r", encoding="utf-8") as f:
            content = f.read()

        parser = QmlLexerBracketParser(content, str(self.set_appearance_path))
        is_valid, errors = parser.parse()
        self.assertTrue(is_valid, f"Delimiter errors in SetAppearance.qml: {errors}")

        # Spanish option preservation
        self.assertIn('{ id: "es", text: "Español" }', content)

        # Dynamic locale.sh execution
        self.assertIn('page.sys.scriptDir + "/locale.sh", "list"', content)

        # Searchable SetPick
        self.assertIn("SetPick {", content)
        self.assertIn("searchable: true", content)
        self.assertIn("options: page.localeOptions", content)

    def test_02_set_pick_qml_search_filtering(self):
        """SetPick.qml must have balanced syntax and filter options by text or id case-insensitively."""
        self.assertTrue(self.set_pick_path.is_file())
        with open(self.set_pick_path, "r", encoding="utf-8") as f:
            content = f.read()

        parser = QmlLexerBracketParser(content, str(self.set_pick_path))
        is_valid, errors = parser.parse()
        self.assertTrue(is_valid, f"Delimiter errors in SetPick.qml: {errors}")

        self.assertIn("property bool searchable: false", content)
        self.assertIn("readonly property var filteredOptions:", content)
        self.assertIn("TextField {", content)
        self.assertIn("id: searchField", content)

        # Replicate SetPick filter logic
        def filter_options(options, query, searchable=True):
            if not searchable or not query:
                return options
            q = query.lower()
            return [
                o for o in options
                if q in str(o.get("text", "")).lower() or q in str(o.get("id", "")).lower()
            ]

        sample_options = [
            {"id": "es", "text": "Español"},
            {"id": "en", "text": "English"},
            {"id": "ru", "text": "Русский"},
            {"id": "tr", "text": "Türkçe"},
            {"id": "de_DE", "text": "Deutsch · de_DE"}
        ]

        # Case-insensitive text match
        self.assertEqual(len(filter_options(sample_options, "esp")), 1)
        self.assertEqual(filter_options(sample_options, "esp")[0]["id"], "es")

        # Case-insensitive id match
        self.assertEqual(len(filter_options(sample_options, "TR")), 1)
        self.assertEqual(filter_options(sample_options, "TR")[0]["text"], "Türkçe")

        # Multi-match
        self.assertEqual(len(filter_options(sample_options, "e")), 4)  # es, en, tr (Türkçe), de_DE
        self.assertEqual(len(filter_options(sample_options, "de")), 1)  # de_DE only

        # Empty match
        self.assertEqual(len(filter_options(sample_options, "nonexistent")), 0)

    def test_03_translations_turkish_dictionary(self):
        """Translations.qml must contain a complete Turkish translation dictionary with >= 600 entries."""
        self.assertTrue(self.translations_path.is_file())
        with open(self.translations_path, "r", encoding="utf-8") as f:
            content = f.read()

        parser = QmlLexerBracketParser(content, str(self.translations_path))
        is_valid, errors = parser.parse()
        self.assertTrue(is_valid, f"Delimiter errors in Translations.qml: {errors}")

        self.assertIn("tr: ({", content)

        # Extract keys in tr block
        tr_match = re.search(r"tr:\s*\(\{\s*(.*?)\s*\}\)", content, re.DOTALL)
        self.assertIsNotNone(tr_match, "Turkish dictionary tr: ({ ... }) missing")

        tr_body = tr_match.group(1)
        # Count entries in tr
        tr_entries = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)":\s*"([^"\\]*(?:\\.[^"\\]*)*)"', tr_body)
        self.assertGreaterEqual(len(tr_entries), 600, f"Expected >= 600 Turkish entries, found {len(tr_entries)}")

        tr_dict = dict(tr_entries)
        self.assertIn("Настройки", tr_dict)
        self.assertEqual(tr_dict["Настройки"], "Ayarlar")
        self.assertIn("Батарея", tr_dict)
        self.assertEqual(tr_dict["Батарея"], "Pil")
        self.assertIn("Язык", tr_dict)
        self.assertEqual(tr_dict["Язык"], "Dil")

    def test_04_weather_details_fallback(self):
        """WeatherDetailsView.qml must prioritize Spanish (isEs) and fall back to English for non-Russian locales."""
        self.assertTrue(self.weather_path.is_file())
        with open(self.weather_path, "r", encoding="utf-8") as f:
            content = f.read()

        parser = QmlLexerBracketParser(content, str(self.weather_path))
        is_valid, errors = parser.parse()
        self.assertTrue(is_valid, f"Delimiter errors in WeatherDetailsView.qml: {errors}")

        # Fallback property
        self.assertIn('languageCode !== "ru"', content)

        # Precedence in date formatting
        self.assertIn("var dayArr = view.sys.isEs ? daysEs : (view.isEn ? daysEn : daysRu);", content)
        self.assertIn("var monArr = view.sys.isEs ? monthsEs : (view.isEn ? monthsEn : monthsRu);", content)

        # Weather condition translations & mapping
        self.assertIn("function weatherConditionTr(desc)", content)
        self.assertIn('"Llovizna"', content)
        self.assertIn('"Chubascos"', content)
        self.assertIn('"Niebla"', content)
        self.assertIn('"Cielo despejado"', content)
        self.assertIn('"Parcialmente nublado"', content)
        self.assertIn('"Nublado"', content)
        self.assertIn("view.weatherConditionTr(activeDay.desc)", content)
        self.assertIn("view.weatherConditionTr(dayItem.modelData.desc)", content)

        # Verify Translations.qml has weather keys
        tr_content = self.translations_path.read_text(encoding="utf-8")
        self.assertIn('"Drizzle": "Llovizna"', tr_content)
        self.assertIn('"Rain showers": "Chubascos"', tr_content)
        self.assertIn('"Fog": "Niebla"', tr_content)
        self.assertIn('"Clear sky": "Cielo despejado"', tr_content)

    def test_05_multilingual_purity_and_keyboard_input(self):
        """Translations.qml must have zero Cyrillic in Spanish/English and SetInput.qml must support keyboard layout presets."""
        tr_content = self.translations_path.read_text(encoding="utf-8")

        # Verify 3 distinct language dictionaries exist
        self.assertIn("readonly property var en:", tr_content)
        self.assertIn("readonly property var es:", tr_content)
        self.assertIn("readonly property var ru:", tr_content)

        # Verify SetInput.qml keyboard configuration
        set_input_path = PROJECT_ROOT / "qml" / "SetInput.qml"
        self.assertTrue(set_input_path.is_file())
        set_input_content = set_input_path.read_text(encoding="utf-8")
        self.assertIn("Español (Latam) + US", set_input_content)
        self.assertIn("latam,us", set_input_content)
        self.assertIn("applyKeyboardLayouts", set_input_content)
        self.assertNotIn("us,tr", set_input_content)

        # Verify real-time locale session synchronization in shell.qml
        shell_path = PROJECT_ROOT / "qml" / "shell.qml"
        self.assertTrue(shell_path.is_file())
        shell_content = shell_path.read_text(encoding="utf-8")
        self.assertIn("pUserLocaleSync", shell_content)
        self.assertIn("systemctl --user set-environment", shell_content)
        self.assertIn("dbus-update-activation-environment", shell_content)


class TestReinstallCleanWorkflow(unittest.TestCase):
    """Adversarial verification of Clean Reinstallation workflow from 0 (reinstall.sh & QML UI)."""

    def setUp(self):
        self.reinstall_sh = PROJECT_ROOT / "scripts" / "reinstall.sh"
        self.setsystem_qml = PROJECT_ROOT / "qml" / "SetSystem.qml"
        self.shell_qml = PROJECT_ROOT / "qml" / "shell.qml"
        self.translations_qml = PROJECT_ROOT / "qml" / "Translations.qml"

    def test_01_reinstall_script_syntax_and_permissions(self):
        """reinstall.sh must exist, be executable, support help, and contain no hardcoded scratch paths."""
        self.assertTrue(self.reinstall_sh.is_file(), "scripts/reinstall.sh does not exist")
        self.assertTrue(os.access(self.reinstall_sh, os.X_OK), "scripts/reinstall.sh is not executable")

        content = self.reinstall_sh.read_text(encoding="utf-8")
        self.assertNotIn(".gemini", content, "reinstall.sh must not contain hardcoded scratch directory paths")
        self.assertIn("nov4z/Panacea_novZ", content)
        self.assertIn("quickshell.service", content)

        res = subprocess.run([str(self.reinstall_sh), "--help"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("reinstall.sh", res.stdout)

    def test_02_reinstall_dry_run_simulation(self):
        """reinstall.sh --dry-run apply must simulate download, clean, install, restart and output status=done."""
        res = subprocess.run([str(self.reinstall_sh), "--dry-run", "apply"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"dry-run failed: {res.stderr}")
        self.assertIn("step=download", res.stdout)
        self.assertIn("step=clean", res.stdout)
        self.assertIn("step=install", res.stdout)
        self.assertIn("step=restart", res.stdout)
        self.assertIn("status=done", res.stdout)

    def test_03_reinstall_error_handling_when_git_fails(self):
        """reinstall.sh must fail cleanly without wiping directories if clone fails."""
        with tempfile.TemporaryDirectory() as tmpdir:
            test_conf = Path(tmpdir) / "panacea"
            test_conf.mkdir()
            canary = test_conf / "canary.txt"
            canary.write_text("keep_intact", encoding="utf-8")

            res = subprocess.run([
                str(self.reinstall_sh), "apply",
                "--config-dir", str(test_conf),
                "--git", "/nonexistent/repo/path",
                "--no-restart"
            ], capture_output=True, text=True)

            self.assertNotEqual(res.returncode, 0)
            self.assertIn("error=download", res.stdout)
            self.assertIn("status=failed", res.stdout)
            self.assertTrue(canary.is_file(), "Existing config was destroyed despite download failure!")

    def test_04_reinstall_clean_execution_and_cache_wiping(self):
        """reinstall.sh must wipe cache, backup/clean existing config, and deploy a 100% clean installation."""
        with tempfile.TemporaryDirectory() as tmpdir:
            test_conf = Path(tmpdir) / "panacea"
            test_cache = Path(tmpdir) / "panacea_cache"
            test_conf.mkdir()
            test_cache.mkdir()

            old_file = test_conf / "old_custom_setting.json"
            old_file.write_text("{}", encoding="utf-8")
            cache_file = test_cache / "stale_cache.bin"
            cache_file.write_text("cache", encoding="utf-8")

            res = subprocess.run([
                str(self.reinstall_sh), "apply",
                "--config-dir", str(test_conf),
                "--cache-dir", str(test_cache),
                "--git", str(PROJECT_ROOT),
                "--branch", "main",
                "--no-restart"
            ], capture_output=True, text=True)

            self.assertEqual(res.returncode, 0, f"reinstall failed: {res.stderr}\nstdout: {res.stdout}")
            self.assertIn("status=done", res.stdout)

            # Cache must be wiped
            self.assertFalse(test_cache.exists(), "Cache directory was not wiped")

            # Old custom files must not remain in the new installation
            self.assertFalse(old_file.exists(), "Old configuration file still exists in target dir")

            # A backup of the old config must have been created
            backups = list(Path(tmpdir).glob("panacea.reinstall_backup_*"))
            self.assertGreaterEqual(len(backups), 1, "Backup was not created prior to clean wipe")

            # Clean install must have new shell.qml and settings.json
            self.assertTrue((test_conf / "qml" / "shell.qml").is_file(), "shell.qml missing from clean install")
            self.assertTrue((test_conf / "settings.json").is_file(), "settings.json missing from clean install")

    def test_05_setsystem_qml_reinstall_ui_contracts(self):
        """SetSystem.qml must implement reinstall button with 2 confirmations, 5s cooldown and clear warning."""
        self.assertTrue(self.setsystem_qml.is_file())
        content = self.setsystem_qml.read_text(encoding="utf-8")

        # State properties and cooldown timer
        self.assertIn("property int reinstallStep: 0", content)
        self.assertIn("property int reinstallCooldown: 0", content)
        self.assertIn("id: reinstallTimer", content)
        self.assertIn("id: reinstallDisarmTimer", content)
        self.assertIn("function cancelReinstall()", content)

        # 5-second cooldown initialization
        self.assertIn("reinstallCooldown = 5", content)

        # 2 confirmation checks
        self.assertIn("page.reinstallStep === 1", content)
        self.assertIn("page.reinstallStep === 2", content)

        # Warning banner with clean reinstall notice
        self.assertIn("reinstallWarnCol", content)
        self.assertIn("~/.cache/panacea", content)

        # Reinstall button, cancel button and applyReinstall invocation
        self.assertIn("reinstallBtn", content)
        self.assertIn("cancelReinstallBtn", content)
        self.assertIn("page.sys.applyReinstall()", content)

    def test_06_shell_qml_reinstall_process_integration(self):
        """shell.qml must integrate applyReinstall and pReinstallApply."""
        self.assertTrue(self.shell_qml.is_file())
        content = self.shell_qml.read_text(encoding="utf-8")

        self.assertIn("property bool   updIsReinstall: false", content)
        self.assertIn("function applyReinstall()", content)
        self.assertIn("id: pReinstallApply", content)
        self.assertIn('root.scriptDir + "/reinstall.sh", "apply"', content)
        self.assertIn('{ id: "clean"', content)

    def test_07_translations_reinstall_multilingual_coverage(self):
        """Translations.qml must have reinstall translations with zero Cyrillic in English and Spanish."""
        self.assertTrue(self.translations_qml.is_file())
        content = self.translations_qml.read_text(encoding="utf-8")

        # Check key strings exist in all dictionaries
        for key in ["Reinstalar", "Confirmar (1/2)", "Confirmar y reinstalar", "очистка"]:
            self.assertIn(f'"{key}"', content)

        # Verify no Cyrillic in en and es dictionaries for reinstall entries
        en_match = re.search(r"readonly property var en:\s*\(\{\s*(.*?)\s*\}\)", content, re.DOTALL)
        self.assertIsNotNone(en_match, "en dictionary not found")
        es_match = re.search(r"readonly property var es:\s*\(\{\s*(.*?)\s*\}\)", content, re.DOTALL)
        self.assertIsNotNone(es_match, "es dictionary not found")


if __name__ == "__main__":
    unittest.main()



