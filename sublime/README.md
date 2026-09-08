# Sublime Text

Sublime Text 4 (the `sublime-text` cask), configured as it is on the source Mac.
`install.sh` copies these into
`~/Library/Application Support/Sublime Text/Packages/User/`.

| File | What it sets |
|---|---|
| `Preferences.sublime-settings` | Material Theme, 15pt, rulers at 80/100/120, acid-lime accent, indent guides, retina antialiasing |
| `Package Control.sublime-settings` | The package list — Package Control installs them all on first launch |
| `Default (OSX).sublime-keymap` | `Cmd-N` opens a new file already in Markdown syntax |
| `SublimeLinter.sublime-settings` | pycodestyle linting |
| `Material-Theme.sublime-theme` | 18pt sidebar labels |

## First launch

The settings reference Material Theme and A File Icon, which do not exist yet on a
new machine — so **Sublime will look wrong until Package Control finishes**.

1. Open Sublime once. Package Control bootstraps itself.
2. It reads `installed_packages` and downloads the seven packages listed there.
   Watch the status bar; it takes a minute.
3. Restart Sublime. The theme now applies.

If nothing installs, Package Control isn't bootstrapped: `Cmd-Shift-P` →
*Install Package Control*, then restart and wait again.

## The `subl` command

The cask puts `subl` in the app bundle; `shell/zprofile` adds it to `PATH` when the
app is present. `.zshrc` then makes it your `$EDITOR` — and falls back to `vim` if
Sublime isn't installed, so the shell config works either way.

```sh
subl file.py      # or the aliases: e, st, edit
subl .            # open the folder as a project — or: e.  /  here
```
