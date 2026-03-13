Upstream repository chain:
- https://github.com/llvm/llvm-test-suite
- Original testcase source: GCC `gcc.c-torture/execute`

Upstream source path used previously:
- `SingleSource/Regression/C/gcc-c-torture/execute/`

Vendored subset policy:
- Only cases listed in `allowlist.txt` are copied into `src/`
- Relative subdirectories such as `ieee/` are preserved under `src/`

License notes:
- Test cases in this directory are GPL-covered; see files in `LICENSES/`
