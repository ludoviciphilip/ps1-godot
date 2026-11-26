# Security Policy

PS1 Maker is a Godot editor addon (GDScript only, no network code, no C++/GDExtension), so its
attack surface is small. Still, if you find a security issue — for example something in the
import/post-import scripts or the level-painter editor tooling that could execute unexpected
code — please report it privately rather than opening a public issue.

## Reporting a vulnerability

Use GitHub's private reporting form for this repository:
[github.com/ludoviciphilip/ps1-godot/security/advisories/new](https://github.com/ludoviciphilip/ps1-godot/security/advisories/new)

Please include:
- The affected version (`addons/ps1_godot/plugin.cfg` -> `version`) and Godot version.
- Steps to reproduce.
- The impact you'd expect (e.g. arbitrary code execution in the editor, data loss).

You should get a response within a few days. There is no bug bounty; credit will be given in the
changelog unless you prefer otherwise.
