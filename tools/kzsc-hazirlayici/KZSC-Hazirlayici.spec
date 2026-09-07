# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['C:/Users/Sinan Selim Yener/Documents/Codex/2026-08-16/c/work/release-v17-integrated/tools/kzsc-hazirlayici/app.py'],
    pathex=['C:/Users/Sinan Selim Yener/Documents/Codex/2026-08-16/c/work/release-v17-integrated/tools/kzsc-hazirlayici/vendor'],
    binaries=[('C:/Users/Sinan Selim Yener/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/DLLs/_tkinter.pyd', '.'), ('C:/Users/Sinan Selim Yener/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/DLLs/tcl86t.dll', '.'), ('C:/Users/Sinan Selim Yener/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/DLLs/tk86t.dll', '.')],
    datas=[('profile.json', '.'), ('C:/Users/Sinan Selim Yener/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/tcl/tcl8.6', '_tcl_data'), ('C:/Users/Sinan Selim Yener/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/tcl/tk8.6', '_tk_data')],
    hiddenimports=[],
    hookspath=['C:/Users/Sinan Selim Yener/Documents/Codex/2026-08-16/c/work/release-v17-integrated/tools/kzsc-hazirlayici/vendor_hooks'],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='KZSC-Hazirlayici',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='KZSC-Hazirlayici',
)
