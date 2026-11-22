# Runtime Test Status and Manual Dispatch

## First runner result
The first Actions attempt failed in the **Install Godot 4.5.1 headless** step. The editor import and scene launch steps were skipped. This is an infrastructure/download-step failure, not evidence of a scene/script failure.

The install step was hardened in commit `7774950` with:
- explicit shell strict mode,
- package setup for wget/unzip,
- retry and timeout behavior,
- server-response diagnostics,
- archive listing before extraction,
- version print.

## Re-run
Because commits made through GitHub's API may not trigger workflows (GitHub suppresses many workflow events originating from its own token), dispatch the workflow manually:
1. Open Actions in the repository.
2. Select **3D Prototype Runtime Smoke Test**.
3. Select **Run workflow** and branch `art/3d-art-conversion-blueprint`.

Then inspect the install step first. If it succeeds, editor import and prototype scene launch execute.

## Limits
No passing runtime result is claimed until a runner completes those later steps successfully.
