# KZSC v1.0.7-generic

- Fixed Entware archive selection for Keenetic models whose recent KeeneticOS versions report only a generic CPU family.
- Added documented model mappings for MIPSel, MIPS big-endian, and AArch64 devices, including Hopper KN-3810 and Titan KN-1812.
- Added regression coverage for Hopper, Titan, and the documented model architecture matrix.
- The Windows preparer remains DNS-neutral and continues to configure DNS only from the KZSC panel after installation.
