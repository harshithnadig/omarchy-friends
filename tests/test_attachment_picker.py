import importlib.machinery
import importlib.util
import pathlib
import sys
import types
import unittest
from unittest.mock import patch


ROOT = pathlib.Path(__file__).resolve().parents[1]


class FakeLoop:
    def __init__(self, bus):
        self.bus = bus
        self.running = False

    def is_running(self):
        return self.running

    def run(self):
        self.running = True
        for path, response, values in self.bus.responses:
            self.bus.receiver(response, values, signal_path=path)
        self.running = False

    def quit(self):
        self.running = False


class FakeBus:
    def __init__(self, responses):
        self.responses = responses
        self.receiver = None
        self.receiver_options = None

    # Match dbus-python's supported options. In particular it accepts
    # path_keyword but not path_namespace; keeping this strict catches
    # runtime-only API mismatches that a permissive mock would hide.
    def add_signal_receiver(
        self, callback, signal_name=None, dbus_interface=None, path_keyword=None
    ):
        self.receiver = callback
        self.receiver_options = {
            "signal_name": signal_name,
            "dbus_interface": dbus_interface,
            "path_keyword": path_keyword,
        }

    def get_object(self, *_args):
        return object()


class AttachmentPickerPortalTests(unittest.TestCase):
    def load_cli(self):
        loader = importlib.machinery.SourceFileLoader(
            "friends_cli_for_picker_test", str(ROOT / "bin" / "omarchy-friends")
        )
        spec = importlib.util.spec_from_loader(loader.name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        return module

    def run_picker(self, *, folder, response=0, uris=None, foreign_response=None):
        handle = "/org/freedesktop/portal/desktop/request/1_2/test"
        responses = []
        if foreign_response is not None:
            responses.append((handle + "_other", foreign_response, {"uris": ["file:///wrong"]}))
        responses.append((handle, response, {"uris": uris or []}))
        bus = FakeBus(responses)
        seen = {}

        class FakeInterface:
            def __init__(self, *_args):
                pass

            def OpenFile(self, parent, title, options):
                seen.update(parent=parent, title=title, options=options)
                return handle

        class VariantDict(dict):
            def __init__(self, values, signature):
                super().__init__(values)
                self.signature = signature

        dbus = types.ModuleType("dbus")
        dbus.SessionBus = lambda: bus
        dbus.Interface = FakeInterface
        dbus.String = str
        dbus.Boolean = bool
        dbus.ByteArray = bytes
        dbus.Dictionary = VariantDict

        dbus_mainloop = types.ModuleType("dbus.mainloop")
        dbus_glib = types.ModuleType("dbus.mainloop.glib")
        dbus_glib.DBusGMainLoop = lambda **_kwargs: None

        class GLib(types.ModuleType):
            SOURCE_REMOVE = False

            @staticmethod
            def MainLoop():
                return FakeLoop(bus)

            @staticmethod
            def timeout_add_seconds(*_args):
                return 1

            @staticmethod
            def source_remove(*_args):
                pass

        gi = types.ModuleType("gi")
        repository = types.ModuleType("gi.repository")
        repository.GLib = GLib("GLib")

        fake_modules = {
            "dbus": dbus,
            "dbus.mainloop": dbus_mainloop,
            "dbus.mainloop.glib": dbus_glib,
            "gi": gi,
            "gi.repository": repository,
        }
        dbus_glib.DBusGMainLoop = lambda **_kwargs: None
        with patch.dict(sys.modules, fake_modules):
            result = self.load_cli().pick_attachment_from_portal(folder)
        return result, seen, bus

    def test_folder_uses_portal_directory_mode_and_decodes_local_uri(self):
        result, seen, bus = self.run_picker(
            folder=True, uris=["file:///home/harshith/Shared%20files"]
        )
        self.assertEqual(result, {"ok": True, "path": "/home/harshith/Shared files"})
        self.assertTrue(seen["options"]["directory"])
        self.assertEqual(seen["options"].signature, "sv")
        self.assertEqual(bus.receiver_options["path_keyword"], "signal_path")
        self.assertEqual(bus.receiver_options["signal_name"], "Response")
        self.assertEqual(
            bus.receiver_options["dbus_interface"], "org.freedesktop.portal.Request"
        )

    def test_file_uses_file_mode_and_ignores_other_portal_requests(self):
        result, seen, _bus = self.run_picker(
            folder=False,
            uris=["file:///home/harshith/notes.txt"],
            foreign_response=0,
        )
        self.assertEqual(result, {"ok": True, "path": "/home/harshith/notes.txt"})
        self.assertFalse(seen["options"]["directory"])

    def test_cancel_is_not_an_error_or_a_selection(self):
        result, _seen, _bus = self.run_picker(folder=False, response=1)
        self.assertEqual(result, {"ok": True, "path": ""})

    def test_rejects_nonlocal_chooser_uri(self):
        result, _seen, _bus = self.run_picker(
            folder=False, uris=["https://files.example/notes.txt"]
        )
        self.assertFalse(result["ok"])


if __name__ == "__main__":
    unittest.main()
