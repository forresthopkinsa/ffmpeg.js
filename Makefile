# Compile FFmpeg and all its dependencies to JavaScript.
# You need emsdk environment installed and activated, see:
# <https://kripken.github.io/emscripten-site/docs/getting_started/downloads.html>.

PRE_JS = build/pre.js

FFMPEG_FILTERS = scale crop overlay fps palettegen paletteuse split
FFMPEG_DEMUXERS = mov srt image2 png_pipe
FFMPEG_DECODERS = \
	h264 \
	png \
	ass ssa srt
FFMPEG_MUXERS = null gif srt
FFMPEG_ENCODERS = gif srt

FFMPEG_WEBM_BC = build/ffmpeg-webm/ffmpeg.bc
LIBASS_PC_PATH = ../freetype/dist/lib/pkgconfig:../fribidi/dist/lib/pkgconfig
FFMPEG_WEBM_PC_PATH_ = \
	$(LIBASS_PC_PATH):\
	../zlib/pkgconfig:\
	../libass/dist/lib/pkgconfig
FFMPEG_WEBM_PC_PATH = $(subst : ,:,$(FFMPEG_WEBM_PC_PATH_))
LIBASS_DEPS = \
	build/fribidi/dist/lib/libfribidi.so \
	build/freetype/dist/lib/libfreetype.so
WEBM_SHARED_DEPS = \
	$(LIBASS_DEPS) \
	build/libass/dist/lib/libass.so

all: webm
webm: ffmpeg-webm.js

clean: clean-js clean-wasm \
	clean-freetype clean-fribidi clean-libass \
	clean-ffmpeg-webm
clean-js:
	rm -f -- dist/ffmpeg*.js
clean-wasm:
	rm -f -- dist/ffmpeg*.wasm
clean-freetype:
	-cd build/freetype && rm -rf dist && make clean
clean-fribidi:
	-cd build/fribidi && rm -rf dist && make clean
clean-libass:
	-cd build/libass && rm -rf dist && make clean
clean-ffmpeg-webm:
	-cd build/ffmpeg-webm && rm -f ffmpeg.bc && make clean

build/freetype/builds/unix/configure:
	cd build/freetype && ./autogen.sh

# XXX(Kagami): host/build flags are used to enable cross-compiling
# (values must differ) but there should be some better way to achieve
# that: it probably isn't possible to build on x86 now.
build/freetype/dist/lib/libfreetype.so: build/freetype/builds/unix/configure
	cd build/freetype && \
	emconfigure ./configure \
		CFLAGS="-O3" \
		--prefix="$$(pwd)/dist" \
		--host=x86-none-linux \
		--build=x86_64 \
		--disable-static \
		\
		--without-zlib \
		--without-bzip2 \
		--without-png \
		--without-harfbuzz \
		&& \
	emmake make -j8 && \
	emmake make install

build/fribidi/configure:
	cd build/fribidi && ./autogen.sh

build/fribidi/dist/lib/libfribidi.so: build/fribidi/configure
	cd build/fribidi && \
	git reset --hard && \
	patch -p1 < ../fribidi-make.patch && \
	emconfigure ./configure \
		CFLAGS=-O3 \
		NM=llvm-nm \
		--prefix="$$(pwd)/dist" \
		--disable-dependency-tracking \
		--disable-debug \
		--without-glib \
		&& \
	emmake make -j8 && \
	emmake make install

build/libass/configure:
	cd build/libass && ./autogen.sh

build/libass/dist/lib/libass.so: build/libass/configure $(LIBASS_DEPS)
	cd build/libass && \
	EM_PKG_CONFIG_PATH=$(LIBASS_PC_PATH) emconfigure ./configure \
		CFLAGS="-O3" \
		--prefix="$$(pwd)/dist" \
		--disable-static \
		--disable-enca \
		--disable-fontconfig \
		--disable-require-system-font-provider \
		--disable-harfbuzz \
		--disable-asm \
		&& \
	emmake make -j8 && \
	emmake make install

# TODO(Kagami): Emscripten documentation recommends to always use shared
# libraries but it's not possible in case of ffmpeg because it has
# multiple declarations of `ff_log2_tab` symbol. GCC builds FFmpeg fine
# though because it uses version scripts and so `ff_log2_tag` symbols
# are not exported to the shared libraries. Seems like `emcc` ignores
# them. We need to file bugreport to upstream. See also:
# - <https://kripken.github.io/emscripten-site/docs/compiling/Building-Projects.html>
# - <https://github.com/kripken/emscripten/issues/831>
# - <https://ffmpeg.org/pipermail/libav-user/2013-February/003698.html>
FFMPEG_COMMON_ARGS = \
	--cc=emcc \
	--enable-cross-compile \
	--target-os=none \
	--arch=x86 \
	--disable-runtime-cpudetect \
	--disable-asm \
	--disable-fast-unaligned \
	--disable-pthreads \
	--disable-w32threads \
	--disable-os2threads \
	--disable-debug \
	--disable-stripping \
	\
	--disable-all \
	--enable-ffmpeg \
	--enable-avcodec \
	--enable-avformat \
	--enable-avutil \
	--enable-swresample \
	--enable-swscale \
	--enable-avfilter \
	--disable-network \
	--disable-d3d11va \
	--disable-dxva2 \
	--disable-vaapi \
	--disable-vdpau \
	$(addprefix --enable-decoder=,$(FFMPEG_DECODERS)) \
	$(addprefix --enable-demuxer=,$(FFMPEG_DEMUXERS)) \
	--enable-protocol=file \
	$(addprefix --enable-filter=,$(FFMPEG_FILTERS)) \
	--disable-bzlib \
	--disable-iconv \
	--disable-libxcb \
	--disable-lzma \
	--disable-securetransport \
	--disable-xlib \
	--enable-zlib

build/ffmpeg-webm/ffmpeg.bc: $(WEBM_SHARED_DEPS)
	cd build/ffmpeg-webm && \
	git reset --hard && \
	patch -p1 < ../ffmpeg-disable-arc4random-monotonic.patch && \
	patch -p1 < ../ffmpeg-default-font.patch && \
	patch -p1 < ../ffmpeg-configure-zlib.patch && \
	EM_PKG_CONFIG_PATH=$(FFMPEG_WEBM_PC_PATH) emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		$(addprefix --enable-encoder=,$(FFMPEG_ENCODERS)) \
		$(addprefix --enable-muxer=,$(FFMPEG_MUXERS)) \
		--enable-filter=subtitles \
		--enable-libass \
		--extra-cflags="-s USE_ZLIB=1" \
		&& \
	emmake make -j8 && \
	cp ffmpeg ffmpeg.bc

# Compile bitcode to JavaScript.
# NOTE(Kagami): Bump heap size to 64M, default 16M is not enough even
# for simple tests and 32M tends to run slower than 64M.
EMCC_COMMON_ARGS = \
	--closure 1 \
	--pre-js $(PRE_JS) \
	-s EXPORT_NAME=ffmpegjs \
	-s AGGRESSIVE_VARIABLE_ELIMINATION=1 \
	-s MODULARIZE=1 \
	-s USE_ZLIB=1 \
	-s USE_LIBPNG=1 \
	-O3 --memory-init-file 0 \
	-o $@

ffmpeg-webm.js: $(FFMPEG_WEBM_BC) $(PRE_JS)
	emcc $(FFMPEG_WEBM_BC) $(WEBM_SHARED_DEPS) \
		-s ALLOW_MEMORY_GROWTH=1 \
		-s WASM=1 \
		$(EMCC_COMMON_ARGS) && \
	mv ffmpeg-webm.js dist/ffmpeg-webm.js && \
	mv ffmpeg-webm.wasm dist/ffmpeg-webm.wasm

