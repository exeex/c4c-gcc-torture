# Vendored gcc torture subset

This directory contains the curated GCC torture execute subset used by c4c.

Layout:
- `src/`: vendored test cases, preserving upstream subdirectories where needed
- `allowlist.txt`: manifest of the vendored cases registered by CMake
- `RunCase.cmake`: per-case runner
- `PruneAllowlistToFailed.cmake`: helper to reduce the manifest to last-failed cases
- `LICENSES/`: upstream GPL license files

The source of truth for what is included is this directory, not the original
llvm-test-suite checkout.
