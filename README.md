Denizen Models
--------------

**Denizen Models**, aka **dModels**, is a tool that can take [BlockBench](https://www.blockbench.net/) "generic" models and render them in minecraft, including with full animations, by spawning sets of armor stands.

This takes the form of two components:

- DenizenModelsConverter
    - `DenizenModelsConverter.sln` and the `DenizenModelsConverter` directory
    - External program, written in C#
        - Needs to be compiled via Visual Studio 2022
        - Only tested on Windows 11 currently, but theoretically works anywhere
    - takes the `.bbmodel` file and converts it into two output files
        - A resource pack for clients
        - A `.dmodel.yml` file for the Minecraft server to read
    - Planned to eventually be replaced by entirely on-server Denizen scripts eventually, with automated pack location selection and all, instead of the manual process with external programs
    - USAGE: Command line!
        - `./DenizenModelsConverter.exe make_pack [bbmodel_file] [pack_path] [model_path] [texture_path]` Puts a model into a resource pack, must specify model and texture path within the pack.
        - Example: `./DenizenModelsConverter.exe make_pack goat.bbmodel creaturepack creatures/goat creatures/goat` This example parses a 'goat' model and puts it in reasonable paths, using by default `arrow` as the item to add onto.
- The Denizen script
    - `scripts/` directory `.dsc` files
    - Runs on your minecraft server using [Denizen](https://github.com/DenizenScript/Denizen)
    - Reads the `.dmodel.yml` file
    - Can spawn the models and animate them

### Status

Early testing. Not read for use.

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
