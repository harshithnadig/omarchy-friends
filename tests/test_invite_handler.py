import importlib.util
import json
import sys
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


HANDLER_PATH = Path(__file__).resolve().parents[1] / "bin" / "omarchy-friends-open"
LOADER = SourceFileLoader("friends_invite_handler", str(HANDLER_PATH))
SPEC = importlib.util.spec_from_loader("friends_invite_handler", LOADER)
HANDLER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HANDLER)


class InviteHandlerTests(unittest.TestCase):
    public_key = "a" * 64
    valid_url = f"omarchy-friends://invite/{public_key}"

    def invoke(self, url):
        with (
            patch.object(sys, "argv", [str(HANDLER_PATH), url]),
            patch.object(HANDLER.subprocess, "run") as run,
        ):
            run.return_value = SimpleNamespace(
                returncode=0,
                stdout=json.dumps({"ok": True, "message": "Chat invite sent"}),
                stderr="",
            )
            exit_code = HANDLER.main()
        return exit_code, run

    def test_exact_invite_dispatches_only_the_public_key(self):
        exit_code, run = self.invoke(self.valid_url)
        self.assertEqual(exit_code, 0)
        command = run.call_args_list[0].args[0]
        self.assertEqual(command[-2:], ["request-friend-direct", self.public_key])

    def test_malformed_invite_shapes_are_rejected_before_dispatch(self):
        invalid_urls = (
            "https://invite/" + self.public_key,
            "omarchy-friends://profile/" + self.public_key,
            "omarchy-friends://invite/not-a-public-key",
            self.valid_url + "/",
            self.valid_url + "//",
            self.valid_url + "?next=profile",
            self.valid_url + "?",
            self.valid_url + "#profile",
            self.valid_url + "#",
            " " + self.valid_url,
        )
        for url in invalid_urls:
            with self.subTest(url=url):
                exit_code, run = self.invoke(url)
                self.assertEqual(exit_code, 1)
                run.assert_not_called()


class InviteRegistrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from importlib.machinery import SourceFileLoader
        path = Path(__file__).resolve().parents[1] / "bin" / "build_network_app_v3.py"
        loader = SourceFileLoader("friends_build_network_registration", str(path))
        sys.path.insert(0, str(path.parent))
        spec = importlib.util.spec_from_loader("friends_build_network_registration", loader)
        cls.module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = cls.module
        spec.loader.exec_module(cls.module)

    def test_registration_reports_failure_and_retries_even_when_file_unchanged(self):
        import tempfile

        with tempfile.TemporaryDirectory() as home:
            with patch("pathlib.Path.home", return_value=Path(home)):
                with patch.object(self.module.subprocess, "run") as run:
                    run.return_value = SimpleNamespace(returncode=1, stdout="")
                    first = self.module.ensure_uri_registration()
                    second = self.module.ensure_uri_registration()
        self.assertFalse(first["registered"])
        self.assertFalse(second["registered"])
        self.assertEqual(run.call_count, 6)
        self.assertEqual(sum(call.args[0][1] == "default" for call in run.call_args_list), 2)

    def test_registration_confirms_installed_default_handler(self):
        import tempfile

        with tempfile.TemporaryDirectory() as home:
            with patch("pathlib.Path.home", return_value=Path(home)):
                with patch.object(self.module.subprocess, "run") as run:
                    run.return_value = SimpleNamespace(
                        returncode=0,
                        stdout="omarchy-friends.desktop\n",
                        stderr="",
                    )
                    result = self.module.ensure_uri_registration()
        self.assertTrue(result["registered"])
        self.assertTrue(any(call.args[0][1] == "query" for call in run.call_args_list))


if __name__ == "__main__":
    unittest.main()
