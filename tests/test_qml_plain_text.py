import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class QmlPlainTextSafetyTests(unittest.TestCase):
    def test_qml_labels_use_plain_text_component(self):
        for path in ROOT.glob("*.qml"):
            if path.name == "PlainText.qml":
                continue
            with self.subTest(path=path.name):
                source = path.read_text(encoding="utf-8")
                self.assertNotRegex(source, r"(?<![A-Za-z0-9_])Text\s*\{")
                if "PlainText {" in source:
                    self.assertIn('import "."', source)

    def test_plain_text_component_disables_markup_and_remote_images(self):
        source = (ROOT / "PlainText.qml").read_text(encoding="utf-8")
        self.assertRegex(source, r"textFormat\s*:\s*Text\.PlainText")

    def test_editable_qml_text_is_plain_text(self):
        for path in ROOT.glob("*.qml"):
            source = path.read_text(encoding="utf-8")
            for match in re.finditer(r"\b(?:TextArea|TextEdit)\s*\{", source):
                with self.subTest(path=path.name, offset=match.start()):
                    self.assertRegex(
                        source[match.end() : match.end() + 140],
                        r"textFormat\s*:\s*TextEdit\.PlainText",
                    )


if __name__ == "__main__":
    unittest.main()
