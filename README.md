# gembindl

## Atari ST GEM AES and VDI interface for tosbindl

This interface is written in Lua 5.5 and includes some additional utility modules.

For the interface implementations see [aes.lua](src/gembindl/aes.lua) and [vdi.lua](src/gembindl/vdi.lua). The utility modules are in the [utility](src/gembindl/utility) subdirectory.

I wrote the AES and VDI interfaces in Lua using the GEM parameter block binding I wrote for tosbindl. After writing the GEMDOS Lua C binding for tosbindl I wanted to use Lua for the GEM bindings, something that is possible due to the way the GEM trap #2 interface works on the Atari ST. My main sources of reference while doing this were:
  * Compute!'s Technical Reference Guide Atari ST Volume One: VDI
  * Compute!'s Technical Reference Guide Atari ST Volume Two: AES
  * The Atari Compendium
  * [tos.hyp](https://github.com/freemint/tos.hyp) The documentation for TOS

On a few occasions I used the [GEMLIB](https://github.com/freemint/gemlib) source to check on a particular aspect of a function if something wasn't working as expected.

I limited the scope to supporting enough functions to write useful programs with TOS 1.04 / EmuTOS 1.4 and Atari GDOS 1.1.