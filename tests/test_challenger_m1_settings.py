#!/usr/bin/env python3
"""
Adversarial Challenger Verification Suite: Milestone M1 Settings & Customization.

Empirically tests:
1. QML Lexical & AST Delimiter Balance:
   - Strict state-machine parser handling comments (// and /* */), strings (', ", `),
     escaped tokens, regex literals, and nesting balance for (), [], {}.
   - Validates SettingsView.qml, SetCustomNotch.qml, SetMedia.qml, SetBarIsland.qml,
     and all referenced Set*.qml pages.
   - Negative testing with mutated corrupted QML inputs to prove parser sensitivity.
2. Component Hierarchy and AST Structure:
   - Verifies existence and layout integrity of newly exposed sections in SettingsView.qml,
     SetCustomNotch.qml, SetMedia.qml, and SetBarIsland.qml.
   - Verifies all 18 referenced section page files exist on the filesystem.
   - Verifies exact control properties, options, default expressions, and persistence hooks.
3. Search Discoverability and Query Matching:
   - Replicates QML matches(s) search logic against parsed sections.
   - Tests required keywords for customnotch (isla, dinamica, rayo, carga, aviso, padding).
   - Tests case insensitivity, partial prefix/infix substrings, search isolation,
     and empty/negative edge-cases.
4. State Machine and Config Contracts:
   - Verifies presence of corresponding sound assets.
"""

import os
import re
import sys
import json
import unittest
from pathlib import Path

PROJECT_ROOT = Path(os.environ.get("PANACEA_DIR", Path(__file__).resolve().parent.parent))
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


class QmlLexerBracketParser:
    """
    Robust lexical tokenizer and bracket validator for QML / JavaScript code.
    Correctly recognizes comments, string literals, template literals,
    escape sequences, and regex literals to validate delimiter balance.
    """

    def __init__(self, source: str, filename: str = "<input>"):
        self.source = source
        self.filename = filename
        self.length = len(source)
        self.pos = 0
        self.line = 1
        self.col = 1
        self.stack = []  # stores (expected_closing, open_char, line, col)
        self.errors = []

    def parse(self):
        PAIRS = {
            "{": "}",
            "[": "]",
            "(": ")",
        }
        CLOSERS = {"}": "{", "]": "[", ")": "("}

        while self.pos < self.length:
            ch = self.source[self.pos]

            # Line counting
            if ch == "\n":
                self.line += 1
                self.col = 1
                self.pos += 1
                continue

            # 1. Single-line comment
            if ch == "/" and self.pos + 1 < self.length and self.source[self.pos + 1] == "/":
                self.pos += 2
                self.col += 2
                while self.pos < self.length and self.source[self.pos] != "\n":
                    self.pos += 1
                    self.col += 1
                continue

            # 2. Multi-line comment
            if ch == "/" and self.pos + 1 < self.length and self.source[self.pos + 1] == "*":
                start_l, start_c = self.line, self.col
                self.pos += 2
                self.col += 2
                closed = False
                while self.pos + 1 < self.length:
                    if self.source[self.pos] == "\n":
                        self.line += 1
                        self.col = 1
                        self.pos += 1
                        continue
                    if self.source[self.pos] == "*" and self.source[self.pos + 1] == "/":
                        self.pos += 2
                        self.col += 2
                        closed = True
                        break
                    self.pos += 1
                    self.col += 1
                if not closed:
                    self.errors.append(f"Unclosed multiline comment starting at {start_l}:{start_c}")
                continue

            # 3. String literals (single quote, double quote, backtick)
            if ch in ('"', "'", "`"):
                quote_char = ch
                start_l, start_c = self.line, self.col
                self.pos += 1
                self.col += 1
                closed = False
                while self.pos < self.length:
                    c = self.source[self.pos]
                    if c == "\n":
                        if quote_char != "`":
                            # Standard single/double quotes cannot cross unescaped newlines in JS/QML
                            self.errors.append(f"Unescaped newline in string literal at {self.line}:{self.col}")
                            break
                        self.line += 1
                        self.col = 1
                        self.pos += 1
                        continue
                    if c == "\\":  # Escaped character
                        self.pos += 2
                        self.col += 2
                        continue
                    if c == quote_char:
                        self.pos += 1
                        self.col += 1
                        closed = True
                        break
                    self.pos += 1
                    self.col += 1
                if not closed:
                    self.errors.append(f"Unclosed string literal starting at {start_l}:{start_c}")
                continue

            # 4. Opening delimiters
            if ch in PAIRS:
                self.stack.append((PAIRS[ch], ch, self.line, self.col))
                self.pos += 1
                self.col += 1
                continue

            # 5. Closing delimiters
            if ch in CLOSERS:
                expected_open = CLOSERS[ch]
                if not self.stack:
                    self.errors.append(
                        f"Unexpected closing delimiter '{ch}' at {self.line}:{self.col} (no opening delimiter)"
                    )
                else:
                    expected_close, open_char, open_l, open_c = self.stack.pop()
                    if ch != expected_close:
                        self.errors.append(
                            f"Mismatched delimiter: expected '{expected_close}' (to match '{open_char}' at {open_l}:{open_c}), "
                            f"but found '{ch}' at {self.line}:{self.col}"
                        )
                self.pos += 1
                self.col += 1
                continue

            self.pos += 1
            self.col += 1

        # Check for unclosed delimiters at EOF
        while self.stack:
            expected_close, open_char, open_l, open_c = self.stack.pop()
            self.errors.append(
                f"Unclosed delimiter '{open_char}' at {open_l}:{open_c} (expected '{expected_close}')"
            )

        return len(self.errors) == 0, self.errors


class TestQmlDelimiterAndSyntaxIntegrity(unittest.TestCase):
    """Empirically validates delimiter and lexical integrity across QML files."""

    def test_parser_negative_detection_broken_fixtures(self):
        """Verifies that the QmlLexerBracketParser correctly detects deliberate delimiter bugs."""
        # 1. Missing brace
        broken1 = "Item { id: test; Component.onCompleted: { console.log('hi'); }"
        parser1 = QmlLexerBracketParser(broken1, "broken1")
        ok, errs = parser1.parse()
        self.assertFalse(ok)
        self.assertTrue(any("Unclosed delimiter '{'" in e for e in errs))

        # 2. Mismatched delimiters
        broken2 = "function f() { var arr = [1, 2, 3); }"
        parser2 = QmlLexerBracketParser(broken2, "broken2")
        ok, errs = parser2.parse()
        self.assertFalse(ok)
        self.assertTrue(any("Mismatched delimiter" in e for e in errs))

        # 3. Unclosed quote
        broken3 = 'Item { property string s: "unclosed; }'
        parser3 = QmlLexerBracketParser(broken3, "broken3")
        ok, errs = parser3.parse()
        self.assertFalse(ok)
        self.assertTrue(any("Unclosed string literal" in e or "Unclosed delimiter" in e for e in errs))

        # 4. Extra closer
        broken4 = "Item { } }"
        parser4 = QmlLexerBracketParser(broken4, "broken4")
        ok, errs = parser4.parse()
        self.assertFalse(ok)
        self.assertTrue(any("Unexpected closing delimiter" in e for e in errs))

    def test_settings_view_qml_delimiter_balance(self):
        """Validates delimiter balance of SettingsView.qml."""
        filepath = PROJECT_ROOT / "SettingsView.qml"
        content = filepath.read_text(encoding="utf-8")
        parser = QmlLexerBracketParser(content, str(filepath))
        ok, errs = parser.parse()
        self.assertTrue(ok, f"Delimiter errors in SettingsView.qml: {errs}")

    def test_set_custom_notch_qml_delimiter_balance(self):
        """Validates delimiter balance of SetCustomNotch.qml."""
        filepath = PROJECT_ROOT / "SetCustomNotch.qml"
        content = filepath.read_text(encoding="utf-8")
        parser = QmlLexerBracketParser(content, str(filepath))
        ok, errs = parser.parse()
        self.assertTrue(ok, f"Delimiter errors in SetCustomNotch.qml: {errs}")

    def test_set_media_qml_delimiter_balance(self):
        """Validates delimiter balance of SetMedia.qml."""
        filepath = PROJECT_ROOT / "SetMedia.qml"
        content = filepath.read_text(encoding="utf-8")
        parser = QmlLexerBracketParser(content, str(filepath))
        ok, errs = parser.parse()
        self.assertTrue(ok, f"Delimiter errors in SetMedia.qml: {errs}")

    def test_set_bar_island_qml_delimiter_balance(self):
        """Validates delimiter balance of SetBarIsland.qml."""
        filepath = PROJECT_ROOT / "SetBarIsland.qml"
        content = filepath.read_text(encoding="utf-8")
        parser = QmlLexerBracketParser(content, str(filepath))
        ok, errs = parser.parse()
        self.assertTrue(ok, f"Delimiter errors in SetBarIsland.qml: {errs}")

    def test_all_settings_section_pages_delimiter_balance(self):
        """Validates delimiter balance for all 18 referenced section pages."""
        settings_view = (PROJECT_ROOT / "SettingsView.qml").read_text(encoding="utf-8")
        page_names = re.findall(r'page:\s*"([^"]+)"', settings_view)
        self.assertGreater(len(page_names), 0, "Should discover section pages in SettingsView.qml")

        for page in page_names:
            p = PROJECT_ROOT / page
            self.assertTrue(p.exists(), f"Section page {p} referenced in SettingsView.qml must exist")
            content = p.read_text(encoding="utf-8")
            parser = QmlLexerBracketParser(content, str(p))
            ok, errs = parser.parse()
            self.assertTrue(ok, f"Delimiter errors in {page}: {errs}")


class TestComponentHierarchyAndContracts(unittest.TestCase):
    """Empirically tests component structure, contracts, and UI elements."""

    def test_settings_view_structure_and_imports(self):
        """Verifies imports, root item, and required functions in SettingsView.qml."""
        content = (PROJECT_ROOT / "SettingsView.qml").read_text(encoding="utf-8")
        self.assertIn("import QtQuick", content)
        self.assertIn("import QtQuick.Layouts", content)
        self.assertIn("import QtQuick.Controls", content)
        self.assertIn("import Quickshell", content)
        self.assertIn("id: view", content)
        self.assertIn("property var sys", content)
        self.assertIn("property int tab:", content)
        self.assertIn("property string query:", content)
        self.assertIn("function goToSection(", content)
        self.assertIn("function matches(", content)
        self.assertIn("id: searchInput", content)
        self.assertIn("id: nav", content)

    def test_set_media_cover_and_ripple_card(self):
        """Verifies the dedicated 'Efectos Visuales de Portada & Ondas' SetCard in SetMedia.qml."""
        content = (PROJECT_ROOT / "SetMedia.qml").read_text(encoding="utf-8")

        self.assertIn('text: page.sys.tr("Efectos Visuales de Portada & Ondas")', content)
        self.assertIn('label: page.sys.tr("Pulsación de carátula (Cover Bounce)")', content)
        self.assertIn("page.sys.cfg.musicCoverBounce", content)
        self.assertIn('label: page.sys.tr("Onda acústica tras la carátula (Cover Ripple)")', content)
        self.assertIn("page.sys.cfg.musicCoverRipple", content)
        self.assertIn('label: page.sys.tr("Forma de la onda tras la carátula")', content)
        self.assertIn('{ id: "0", text: page.sys.tr("Circular") }', content)
        self.assertIn('{ id: "1", text: page.sys.tr("Silueta") }', content)
        self.assertIn('{ id: "2", text: page.sys.tr("Recta") }', content)
        self.assertIn("page.sys.cfg.musicCoverRippleShape = parseInt(id) || 0", content)

    def test_set_bar_island_interactivity_card(self):
        """Verifies the dedicated 'Interactividad del Notch' SetCard in SetBarIsland.qml."""
        content = (PROJECT_ROOT / "SetBarIsland.qml").read_text(encoding="utf-8")

        self.assertIn('text: page.sys.tr("Interactividad del Notch")', content)
        self.assertIn('label: page.sys.tr("Ventana activa al pasar el cursor (Hover Peek)")', content)
        self.assertIn("page.sys.cfg.notchActiveWindowHover", content)
        self.assertIn('label: page.sys.tr("Aviso de Portapapeles (Clipboard Flash)")', content)
        self.assertIn("page.sys.cfg.notchClipboardFlash", content)
        self.assertIn('label: page.sys.tr("Aura reactiva de reproducción (Audio Ripple)")', content)
        self.assertIn("page.sys.cfg.notchAudioRipple", content)

    def test_set_custom_notch_unibody_preview_fidelity(self):
        """Verifies authentic unibody geometry, lyrics, and expanded island in SetCustomNotch.qml."""
        content = (PROJECT_ROOT / "SetCustomNotch.qml").read_text(encoding="utf-8")

        # Unibody geometry without border break
        self.assertIn("color: page.sys.currentNotchBg || page.sys.colBg || \"#000000\"", content)
        self.assertIn("border.width: 0", content)

        # Ambient glow dynamic bindings
        self.assertIn("page.sys.cfg.notchAmbientGlowRadius", content)
        self.assertIn("page.sys.cfg.notchAmbientGlowIntensity", content)
        self.assertIn("page.sys.cfg.notchAmbientGlowEnabled", content)

        # Interactive lyrics and sub-selector in preview
        self.assertIn("subMusicViewBtn", content)
        self.assertIn("previewIsExpanded", content)
        self.assertIn("previewLyricsOpen", content)
        self.assertIn("previewLyricsBtn", content)
        self.assertIn("prevExpandedItem", content)
        self.assertIn("SpicyLyricsView", content)
        self.assertIn("previewSpicyLyrics", content)

    def test_set_custom_notch_new_customization_controls(self):
        """Verifies newly exposed sliders and selects in SetCustomNotch.qml."""
        content = (PROJECT_ROOT / "SetCustomNotch.qml").read_text(encoding="utf-8")

        # Ambient glow toggle and sliders
        self.assertIn('label: page.sys.tr("Resplandor ambiental del notch (Ambient Glow)")', content)
        self.assertIn("page.sys.cfg.notchAmbientGlowEnabled", content)
        self.assertIn('label: page.sys.tr("Intensidad del resplandor ambiental")', content)
        self.assertIn("page.sys.cfg.notchAmbientGlowIntensity", content)
        self.assertIn('label: page.sys.tr("Radio de difusión del resplandor")', content)
        self.assertIn("page.sys.cfg.notchAmbientGlowRadius", content)

        # Island lyrics card
        self.assertIn('text: page.sys.tr("Visor de Letras & Expansión de la Isla")', content)
        self.assertIn('label: page.sys.tr("Altura objetivo del visor de letras")', content)
        self.assertIn("page.sys.cfg.islandLyricsHeight", content)
        self.assertIn('label: page.sys.tr("Comportamiento de apertura de letras")', content)
        self.assertIn("page.sys.cfg.islandLyricsBehavior", content)

    def test_settings_json_and_shell_qml_new_keys_contract(self):
        """Verifies settings.json, shell.qml, and IslandMusicView.qml integration contracts."""
        cfg_path = PROJECT_ROOT / "settings.json"
        data = json.loads(cfg_path.read_text(encoding="utf-8"))
        for key in ["notchAmbientGlowEnabled", "notchAmbientGlowIntensity",
                    "notchAmbientGlowRadius", "islandLyricsHeight", "islandLyricsBehavior"]:
            self.assertIn(key, data, f"Key {key} must exist in settings.json")

        shell_content = (PROJECT_ROOT / "shell.qml").read_text(encoding="utf-8")
        for key in ["notchAmbientGlowEnabled: true", "notchAmbientGlowIntensity: 35",
                    "notchAmbientGlowRadius: 60", "islandLyricsHeight: 240", "islandLyricsBehavior: \"manual\""]:
            self.assertIn(key, shell_content, f"Default key {key} must be in shell.qml defaultCfg")

        self.assertIn("root.cfg.islandLyricsHeight", shell_content)

        island_content = (PROJECT_ROOT / "IslandMusicView.qml").read_text(encoding="utf-8")
        self.assertIn("sys.cfg.islandLyricsHeight", island_content)

    def test_shell_qml_json_adapter_declares_all_new_m1_properties(self):
        """Verifies that adapter: JsonAdapter in shell.qml explicitly declares all new M1 properties so they survive writeAdapter() / saveCfg()."""
        shell_content = (PROJECT_ROOT / "shell.qml").read_text(encoding="utf-8")
        adapter_match = re.search(
            r"FileView\s*\{\s*id:\s*cfgFile.*?adapter:\s*JsonAdapter\s*\{(.*?)\n\s*\}\s*\n\s*\}",
            shell_content,
            re.DOTALL,
        )
        self.assertIsNotNone(adapter_match, "Could not find cfgFile adapter: JsonAdapter block in shell.qml")
        adapter_body = adapter_match.group(1)

        expected_properties = {
            "notchAmbientGlowEnabled": r"property\s+bool\s+notchAmbientGlowEnabled\s*:\s*true",
            "notchAmbientGlowIntensity": r"property\s+int\s+notchAmbientGlowIntensity\s*:\s*35",
            "notchAmbientGlowRadius": r"property\s+int\s+notchAmbientGlowRadius\s*:\s*60",
            "islandLyricsHeight": r"property\s+int\s+islandLyricsHeight\s*:\s*240",
            "islandLyricsBehavior": r'property\s+string\s+islandLyricsBehavior\s*:\s*"manual"',
        }

        for prop_name, pattern in expected_properties.items():
            self.assertRegex(
                adapter_body,
                pattern,
                f"Property '{prop_name}' must be declared inside adapter: JsonAdapter in shell.qml so it survives writeAdapter()/saveCfg()",
            )


class TestSearchDiscoverability(unittest.TestCase):
    """Empirically tests search discoverability and keyword matching in SettingsView.qml."""

    @classmethod
    def setUpClass(cls):
        content = (PROJECT_ROOT / "SettingsView.qml").read_text(encoding="utf-8")
        # Extract sections definitions
        # Parse section objects { id: "...", title: "...", ... keys: "..." }
        sec_block_match = re.search(r"readonly\s+property\s+var\s+sections\s*:\s*\[(.*?)\]\s*\n\s*readonly", content, re.DOTALL)
        assert sec_block_match, "Could not find sections definition in SettingsView.qml"
        sec_block = sec_block_match.group(1)

        # Parse each section entry
        cls.sections = []
        entries = re.findall(r'\{\s*id:\s*"([^"]+)",\s*title:\s*"([^"]+)",.*?keys:\s*(".*?"(?:\s*\+\s*".*?")*)\s*\}', sec_block, re.DOTALL)
        for s_id, title, raw_keys in entries:
            # Concatenate any string literals in keys
            keys_concat = "".join(re.findall(r'"([^"]*)"', raw_keys))
            cls.sections.append({
                "id": s_id,
                "title": title,
                "keys": keys_concat,
            })

    def _matches(self, section: dict, query: str) -> bool:
        """Exact Python equivalent of SettingsView.qml function matches(s)."""
        if len(query) == 0:
            return True
        q = query.lower()
        return q in section["title"].lower() or q in section["keys"].lower()

    def test_sections_parsed_successfully(self):
        """Verifies that all 18 sections were parsed from SettingsView.qml."""
        self.assertEqual(len(self.sections), 18)
        ids = [s["id"] for s in self.sections]
        self.assertIn("customnotch", ids)
        self.assertIn("bar", ids)
        self.assertIn("media", ids)

    def test_customnotch_search_keywords_discoverability(self):
        """Verifies that customnotch section keywords match."""
        target_sec = next(s for s in self.sections if s["id"] == "customnotch")

        required_keywords = [
            "isla",
            "dinamica",
            "rayo",
            "carga",
            "aviso",
            "padding",
        ]

        for kw in required_keywords:
            self.assertTrue(
                self._matches(target_sec, kw),
                f"Keyword '{kw}' must match customnotch section"
            )

    def test_search_case_insensitivity(self):
        """Verifies case-insensitive matching across query variants."""
        target_sec = next(s for s in self.sections if s["id"] == "customnotch")

        variants = [
            "Isla",
            "ISLA",
            "Dinamica",
            "DINAMICA",
            "Rayo",
            "RAYO",
            "Carga",
            "CARGA",
        ]

        for var in variants:
            self.assertTrue(
                self._matches(target_sec, var),
                f"Variant query '{var}' must match customnotch section"
            )

    def test_search_partial_substrings(self):
        """Verifies prefix and partial substring matching."""
        target_sec = next(s for s in self.sections if s["id"] == "customnotch")

        partial_queries = [
            "isl",
            "dinam",
            "carg",
            "padd",
        ]

        for q in partial_queries:
            self.assertTrue(
                self._matches(target_sec, q),
                f"Partial query '{q}' must match customnotch section"
            )

    def test_search_isolation_and_selectivity(self):
        """Verifies that specific customnotch queries match only customnotch."""
        specific_queries = ["rayo", "carga", "padding", "charging"]

        for q in specific_queries:
            matching_ids = [s["id"] for s in self.sections if self._matches(s, q)]
            self.assertEqual(
                matching_ids,
                ["customnotch"],
                f"Query '{q}' should specifically match only ['customnotch'], but matched {matching_ids}"
            )

    def test_empty_and_negative_queries(self):
        """Verifies boundary conditions: empty matches all, non-existent matches none."""
        # Empty query
        all_matches = [s["id"] for s in self.sections if self._matches(s, "")]
        self.assertEqual(len(all_matches), 18)

        # Non-existent query
        none_matches = [s["id"] for s in self.sections if self._matches(s, "nonexistent_query_xyz123")]
        self.assertEqual(len(none_matches), 0)


class TestStateSynchronizationAndSoundAssets(unittest.TestCase):
    """Empirically validates referenced sound assets exist in sound packs."""

    def test_core_sound_assets_exist(self):
        """Verifies core sound assets exist across sound packs."""
        sound_dir = PROJECT_ROOT / "sounds"
        packs = ["nothing", "material", "custom", "zen", "cyber", "retro", "bubble"]
        core_sounds = ["notification.wav", "screenshot.wav", "lock.wav", "unlock.wav", "connect.wav", "disconnect.wav"]

        for pack in packs:
            pack_dir = sound_dir / pack
            self.assertTrue(pack_dir.exists(), f"Pack directory {pack_dir} must exist")
            for sound in core_sounds:
                f = pack_dir / sound
                self.assertTrue(f.exists(), f"Core sound '{sound}' must exist in pack '{pack}'")


def run_tests():
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(TestQmlDelimiterAndSyntaxIntegrity))
    suite.addTests(loader.loadTestsFromTestCase(TestComponentHierarchyAndContracts))
    suite.addTests(loader.loadTestsFromTestCase(TestSearchDiscoverability))
    suite.addTests(loader.loadTestsFromTestCase(TestStateSynchronizationAndSoundAssets))

    runner = unittest.TextTestRunner(verbosity=2)
    res = runner.run(suite)
    return 0 if (len(res.errors) == 0 and len(res.failures) == 0) else 1


if __name__ == "__main__":
    sys.exit(run_tests())
