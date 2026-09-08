# Node.js

Node comes from Homebrew (`brew "node"`), so there is no nvm and no version
juggling. Check `node -v` if a project demands a specific major version; install
a second one with `brew install node@22` and put it on `PATH` per-project.

`npm-global.txt` lists the global packages `install.sh` installs. Globals are kept
deliberately short — three AI harnesses and a package manager. Everything else
belongs in a project's own `package.json`.

```sh
# what install.sh runs:
xargs npm install -g < npm-global.txt

# check what you have and what is stale:
npm ls -g --depth=0
npm outdated -g
```

`pnpm` is included because it is much faster than npm for real projects and uses a
content-addressed store instead of duplicating `node_modules` per project:

```sh
pnpm install        # in place of npm install
pnpm dlx <pkg>      # in place of npx
```
