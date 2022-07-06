Denizen Models
--------------

**Denizen Models**, aka **dModels**, is a tool that can take [BlockBench](https://www.blockbench.net/) "generic" models and render them in minecraft, including with full animations, by spawning sets of armor stands.

As the name implies, this relies on [Denizen](https://github.com/DenizenScript/Denizen).

There are three scripts:

- `dmodels_main.dsc` is the 'main' file - it contains a detailed informational header with usage details, and a configuration section.
    - Look through that file to learn how to use dModels.
- `dmodels_loader.dsc` is the script that handles loading in `.bbmodel` files to Denizen and building the resource pack.
- `dmodels_spawning.dsc` is the coremost API script that handles the spawning/deleting/positioning of models in-game.
- `dmodels_animating.dsc` is the script that handles animation playback for models.

### Related Links

- BlockBench: https://www.blockbench.net/
- General Denizen scripting homepage: https://denizenscript.com/
- DenizenModels resource page on the Denizen forum: https://forum.denizenscript.com/resources/denizen-models.103/

### Script Usage

Documented in the header of the `dmodels_main.dsc` script.

### Status

Third beta release. Functions for most basic purposes, but not the most user friendly. More is planned for this. Some things are currently being changed around from what they were in the prior betas.

### Licensing pre-note:

This is an open source project, provided entirely freely, for everyone to use and contribute to.

If you make any changes that could benefit the community as a whole, please contribute upstream.

### The short of the license is:

You can do basically whatever you want, except you may not hold any developer liable for what you do with the software.

### The long version of the license follows:

The MIT License (MIT)

Copyright (c) 2022 Alex "mcmonkey" Goodwin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
