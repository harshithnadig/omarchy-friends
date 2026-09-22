# Build Network prototype

This branch contains the first code slice for Omarchy-native collaboration:

- Ideas
- Build Rooms
- Setup Cards
- Test Requests / Results

## Local smoke test

```bash
python3 -m unittest tests.test_build_network -v
python3 bin/build_network_cli.py idea "OLED system monitor" --summary "A clean GPU/CPU bar widget" --tag QML --tag NVIDIA
python3 bin/build_network_cli.py room "OLED system monitor" --goal "Ship a marketplace-ready widget" --role Designer --role "AMD tester" --task "Basic widget" --task "GPU support"
python3 bin/build_network_cli.py setup "My Omarchy setup" --theme Catppuccin --plugin Friends --plugin Spotify --terminal Ghostty
python3 bin/build_network_cli.py test-request "Friends build-network beta" --artifact https://github.com/harshithnadig/omarchy-friends --want NVIDIA --want AMD --want Framework
```

## Safety scope

This prototype only creates bounded metadata payloads. It does not execute shell commands, install shared configs, read private files, or auto-publish anything. Relay and QML integration should be added only after these payloads pass local testing on a real Omarchy system.
