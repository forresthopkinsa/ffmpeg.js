import ffmpeg from './dist/ffmpeg-webm.js';
import ffmpegModule from './dist/ffmpeg-webm.wasm';

function exe(opts) {
	return ffmpeg({
		...opts,
		stdin: () => {},
		locateFile(path) {
			if (path.endsWith('.wasm')) {
				return ffmpegModule;
			}
			return path;
		},
	});
}

export default exe;

