// Usage: node run.js <ffmpeg args>
// e.g.
// node run.js -version
// node run.js -i video.mp4 video.gif

process.on('uncaughtException', console.log);
process.on('exit', (i) => console.log('Exit: ', i));

var ffmpeg = require("./dist/ffmpeg-webm.js");
// Print FFmpeg's version.
ffmpeg({
  arguments: process.argv.slice(2),
  noExitRuntime: true,
  print: (data) => console.log(`Print: ${data}`),
  printErr: (err) => console.log(`Error: ${err}`),
  onExit: () => console.log('ffmpeg exit'),
  onAbort: () => console.log('ffmpeg abort'),
});

console.log('Script evaluation complete');

setTimeout(() => console.log('ok'), 5000);
