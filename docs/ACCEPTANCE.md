# Manuelle Abnahme

Prüfpunkte aus den Done-when-Kriterien der Meilensteine M6–M11 in [`ROADMAP.md`](ROADMAP.md), die CI nicht
leisten kann. Pro Ziel mit VM-Snapshot als normaler Benutzer arbeiten; Datum, Systemversion und Abweichungen
neben dem Haken notieren. Ausführliche Schritte: README, Abschnitt „Manuelle Abnahme auf einer frischen VM“.

## CachyOS-VM (frisch, Profil `desktop`)

- [ ] M9: Ein Befehl `curl … | bash` (zuerst `--dry-run`) richtet die komplette Umgebung ein, ohne vorher zu klonen
- [ ] M9: zsh-Rückfrage bestätigt; `getent passwd "$USER"` zeigt zsh nach Ab- und Anmelden
- [ ] M9: zweiter Lauf ändert nichts (keine neuen Backups, `git -C ~/dotfiles status --short` leer)
- [ ] M9: `eza`, `yazi`, `tldr`, `just`, `lazydocker`, `claude`, `pi` starten; `dot update` und `dot doctor` laufen sauber
- [ ] M6: Hyprland (>= 0.57) startet mit `hyprland.lua` ohne Fehlermeldungen
- [ ] M6: jedes Binding aus `manifests/keybindings.tsv` funktioniert (Launcher, Clipboard-Verlauf, Screenshot, Sperren)
- [ ] M6: GTK- und Qt-Apps dunkel im Tokyo-Night-Look (Cursor, Icons, Wallpaper)
- [ ] M6: KDE-Session startet weiterhin
- [ ] M5: WezTerm, Zed und Neovim zeigen gleiche Farben, Fonts und Deckkraft
- [ ] M11: Installationsanleitung im README auf der frischen VM Schritt für Schritt nachvollzogen

## Windows-11-VM (frisch)

- [ ] M9: `irm … | iex` (zuerst `-DryRun`) richtet Windows und WSL ein, ohne vorher zu klonen
- [ ] M7: alle winget-Apps installiert (WezTerm, Zed, GlazeWM, Zebar, Flow, PowerShell 7, Git, .NET SDK, Ollama, Claude Code)
- [ ] M7: Fonts installiert; Zed- und Agent-Config (`~/.claude`, `~/.pi/agent`) vorhanden
- [ ] M7: Dark Mode aktiv; GlazeWM-Rahmen/Transparenz, Zebar und Flow-Theme im Tokyo-Night-Look
- [ ] M7: WezTerm mit Acrylic-Hintergrund
- [ ] M7: `windows\dot.ps1 update` und `doctor` laufen sauber; zweiter Bootstrap ändert nichts
- [ ] M8: WezTerm öffnet zsh in WSL Arch
- [ ] M8: Zed öffnet ein WSL-Projekt mit funktionierendem LSP
- [ ] M8: Claude läuft in WSL
- [ ] M6: GlazeWM-Bindings entsprechen dem Keybinding-Vertrag

## Corne (Hardware)

- [ ] M10: Vial erkennt den Corne unter Linux ohne `sudo`
- [ ] M10: Vial erkennt den Corne unter Windows
- [ ] M10: `corne_v4.vil` lässt sich laden (Anleitung: [`CORNE.md`](CORNE.md))
- [ ] M10: alle Vertrags-Bindings sind über die Layer erreichbar und lösen die erwartete Aktion aus
