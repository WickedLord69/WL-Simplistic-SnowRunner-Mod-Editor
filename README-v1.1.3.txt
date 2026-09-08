WL Simplistic SnowRunner Mod Editor v1.1.3
Created by Wicked Lord | Discord: wickedlord69

HOTFIX RELEASE

v1.1.3 fixes Addon/Trailer Center of Gravity targeting for articulated equipment and adds a safe update notification system.

FIXED
- Addon/Trailer COG now modifies only the primary PhysicsModel body CenterOfMassOffset.
- Nested articulated ramp, winch, hook and other constrained bodies are no longer moved by the COG control.
- Fixes severe load-dependent oscillation observed with the Articulated Towing Platform.
- Controlled regression testing reduced global Addon/Trailer COG edits from 565 broad edits to 99 primary-body edits.

UPDATE CHECKER
- Automatic startup check for newer editor versions.
- Manual Check for Updates button.
- Semantic version comparison.
- If a newer version exists, the editor asks before opening the official mod.io page.
- No automatic EXE downloads and no self-replacement.
- Offline or unavailable update service never blocks normal editor use.

MOD TRUCKS
- Scan Mods remains CLEAN READ-ONLY discovery.
- Third-party mod trucks remain protected from Preview/Apply editing until separate per-mod backup/restore protection is implemented.

IMPORTANT
- Close SnowRunner before Apply or Restore.
- Preview before Apply.
- Existing trusted initial.original.pak backup/update protection remains in place.
