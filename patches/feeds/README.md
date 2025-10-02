# Local feed Kconfig fixes

`scripts/feeds update` (including `-i`) reapplies these patches before indexing.
The helper accepts an already-applied patch, and fails on incompatible changes
so upstream fixes can be reviewed and obsolete patches removed.

- video: remove the Qt5 GUI dependency from the OpenGL choice.
- packages: move the Squeezelite WMA/ALAC option outside its custom-package guard.

Kconfig counts prompt visibility expressions as dependency edges too. These
options therefore stay visible independently of package selection, as already
done for FFmpeg configuration upstream. Both OpenGL choices, WMA/ALAC support,
and conditional Mesa/FFmpeg library dependencies are preserved. An option alone
does not select its owning package. No generated tmp/ files are patched.

Feed source directories are ignored; these patch files are the persistent source.
