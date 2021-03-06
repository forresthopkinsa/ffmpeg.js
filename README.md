# ffmpeg.js

This library provides FFmpeg builds ported to JavaScript using [Emscripten project](https://github.com/kripken/emscripten). Builds are optimized for in-browser use: minimal size for faster loading, asm.js, performance tunings, etc. Though they work in Node as well.

This fork in particular is built for encoding gifs with subtitles.

## Builds

Currently available builds (additional builds may be added in future):
* `ffmpeg-webm.js` - WebM encoding (VP8 & Opus encoders, popular decoders).

Note: only NPM releases contain abovementioned files.

## Version scheme

Contrary to the upstream projects, this fork uses traditional semantic versioning, starting at version 4.0.0.

## Usage

See documentation on [Module object](https://kripken.github.io/emscripten-site/docs/api_reference/module.html#affecting-execution) for the list of options that you can pass.

### Sync run

ffmpeg.js provides common module API, `ffmpeg-webm.js` is the default module. Add its name after the slash if you need another build, e.g. `require("ffmpeg.js/ffmpeg-mp4.js")`.

```js
var ffmpeg = require("ffmpeg.js");
var stdout = "";
var stderr = "";
// Print FFmpeg's version.
ffmpeg({
  arguments: ["-version"],
  print: function(data) { stdout += data + "\n"; },
  printErr: function(data) { stderr += data + "\n"; },
  onExit: function(code) {
    console.log("Process exited with code " + code);
    console.log(stdout);
  },
});
```

Use e.g. [browserify](https://github.com/substack/node-browserify) in case of Browser.

### Files

Empscripten supports several types of [file systems](https://kripken.github.io/emscripten-site/docs/api_reference/Filesystem-API.html#file-systems). ffmpeg.js uses [MEMFS](https://kripken.github.io/emscripten-site/docs/api_reference/Filesystem-API.html#memfs) to store the input/output files in FFmpeg's working directory. You need to pass *Array* of *Object* to `MEMFS` option with the following keys:
* **name** *(String)* - File name, can't contain slashes.
* **data** *(ArrayBuffer/ArrayBufferView/Array)* - File data.

ffmpeg.js resulting object has `MEMFS` option with the same structure and contains files which weren't passed to the input, i.e. new files created by FFmpeg.

```js
var ffmpeg = require("ffmpeg.js");
var fs = require("fs");
var testData = new Uint8Array(fs.readFileSync("test.webm"));
// Encode test video to VP8.
var result = ffmpeg({
  MEMFS: [{name: "test.webm", data: testData}],
  arguments: ["-i", "test.webm", "-c:v", "libvpx", "-an", "out.webm"],
  // Ignore stdin read requests.
  stdin: function() {},
});
// Write out.webm to disk.
var out = result.MEMFS[0];
fs.writeFileSync(out.name, Buffer(out.data));
```

You can also mount other FS by passing *Array* of *Object* to `mounts` option with the following keys:
* **type** *(String)* - Name of the file system.
* **opts** *(Object)* - Underlying file system options.
* **mountpoint** *(String)* - Mount path, must start with a slash, must not contain other slashes and also the following paths are blacklisted: `/tmp`, `/home`, `/dev`, `/work`. Mount directory will be created automatically before mount.

See documentation of [FS.mount](https://kripken.github.io/emscripten-site/docs/api_reference/Filesystem-API.html#FS.mount) for more details.

```js
var ffmpeg = require("ffmpeg.js");
ffmpeg({
  // Mount /data inside application to the current directory.
  mounts: [{type: "NODEFS", opts: {root: "."}, mountpoint: "/data"}],
  arguments: ["-i", "/data/test.webm", "-c:v", "libvpx", "-an", "/data/out.webm"],
  stdin: function() {},
});
// out.webm was written to the current directory.
```

## Build instructions
Tips, use a [docker](https://www.docker.com/) container (basic ubuntu is good)

```bash
apt-get update
apt-get -y install wget python git automake libtool build-essential cmake libglib2.0-dev closure-compiler

cd /root # or /home/whatever
wget https://s3.amazonaws.com/mozilla-games/emscripten/releases/emsdk-portable.tar.gz
tar xzvf emsdk-portable.tar.gz
cd emsdk-portable
./emsdk update
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh

cd /root # or /home/whatever
git clone https://github.com/arjun-g/ffmpeg.js
cd ffmpeg.js
git submodule init
git submodule update --recursive

make all
```

## Credits

Thanks to [videoconverter.js](https://bgrins.github.io/videoconverter.js/) for inspiration. And of course to all great projects which made this library possible: FFmpeg, Emscripten, asm.js, node.js and many others.

## License

Own library code licensed under LGPL 2.1 or later.

### WebM build

This build uses LGPL version of FFmpeg and thus available under LGPL 2.1 or later. See [here](https://www.ffmpeg.org/legal.html) for more details and FFmpeg's license information.

Included libraries:
* libopus [licensed under BSD](https://git.xiph.org/?p=opus.git;a=blob;f=COPYING).
* freetype [licensed under FreeType Project LICENSE](http://git.savannah.gnu.org/cgit/freetype/freetype2.git/tree/docs/FTL.TXT).
* fribidi [licensed under LGPL](https://github.com/behdad/fribidi/blob/master/COPYING).
* libass [licensed under ISC](https://github.com/libass/libass/blob/master/COPYING).
* libvpx [licensed under BSD](https://chromium.googlesource.com/webm/libvpx/+/master/LICENSE).

See [LICENSE.WEBM](https://github.com/Kagami/ffmpeg.js/blob/master/LICENSE.WEBM) for the full text of software licenses used in this build.

