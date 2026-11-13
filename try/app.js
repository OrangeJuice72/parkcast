'use strict';
const $ = id => document.getElementById(id);
const video = $('video');
const testURL = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';
let localURL = null;
let sourceKind = 'None';
const hasPicker = typeof video.webkitShowPlaybackTargetPicker === 'function';
const hls = !!video.canPlayType('application/vnd.apple.mpegurl');
$('secure').textContent = window.isSecureContext ? 'Yes' : 'No';
$('picker').textContent = hasPicker ? 'Available' : 'Not exposed';
$('hls').textContent = hls ? 'Supported' : 'Not supported';
$('airplay').disabled = !hasPicker;
if (!hasPicker) $('message').textContent = 'Open this page in Safari on iPhone. This browser does not expose the AirPlay picker.';

function report(message) { $('message').textContent = message; }
function updateWireless() {
  $('wireless').textContent = video.webkitCurrentPlaybackTargetIsWireless ? 'Active — verify the car picture' : 'Not active';
}
function resetLocalURL() {
  if (localURL) URL.revokeObjectURL(localURL);
  localURL = null;
}
function loadVideo(url, kind) {
  video.pause();
  sourceKind = kind;
  $('empty-player').hidden = true;
  video.src = url;
  video.load();
  $('playback-state').textContent = 'LOADING';
  report('Loading video. Once it plays, choose an AirPlay display.');
  const play = video.play();
  if (play) play.catch(error => {
    if (error.name === 'AbortError') return;
    report(error.name === 'NotAllowedError' ? 'Tap Play on the video to start playback.' : 'This video could not start. Try the test in Safari on iPhone or use a supported MP4.');
  });
  video.scrollIntoView({ behavior: 'auto', block: 'center' });
}
$('test').addEventListener('click', () => {
  if (!hls) { report('This test uses HLS. Open this page in Safari on your iPhone, or try a direct MP4 link below.'); return; }
  resetLocalURL();
  loadVideo(testURL, 'Apple test stream');
});
$('airplay').addEventListener('click', () => {
  if (!video.currentSrc && !video.getAttribute('src')) { report('Start a video before choosing an AirPlay display.'); return; }
  try { video.webkitShowPlaybackTargetPicker(); }
  catch { report('AirPlay could not open. Try the AirPlay control inside the video player.'); }
});
$('url-form').addEventListener('submit', event => {
  event.preventDefault();
  try {
    const url = new URL($('video-url').value.trim());
    if (url.protocol !== 'https:' || url.username || url.password) throw new Error('Unsupported URL');
    resetLocalURL();
    loadVideo(url.href, 'Direct HTTPS link');
  } catch { report('Enter a complete HTTPS video URL without an embedded username or password.'); }
});
$('local-video').addEventListener('change', event => {
  const file = event.target.files?.[0];
  if (!file) return;
  resetLocalURL();
  localURL = URL.createObjectURL(file);
  loadVideo(localURL, 'Local file (not uploaded)');
});
$('stop').addEventListener('click', () => {
  video.pause(); video.removeAttribute('src'); video.load(); resetLocalURL();
  $('empty-player').hidden = false;
  $('playback-state').textContent = 'READY';
  sourceKind = 'None'; report('Playback stopped.'); updateWireless();
});
video.addEventListener('playing', () => { $('playback-state').textContent = 'PLAYING'; report('Video is playing. Use AirPlay and check the actual car display.'); updateWireless(); });
video.addEventListener('pause', () => { if (video.getAttribute('src')) $('playback-state').textContent = 'PAUSED'; });
video.addEventListener('waiting', () => { $('playback-state').textContent = 'BUFFERING'; });
video.addEventListener('ended', () => { $('playback-state').textContent = 'FINISHED'; });
video.addEventListener('error', () => {
  if (!video.getAttribute('src')) return;
  $('playback-state').textContent = 'ERROR';
  report('Playback failed. Check your internet connection and use a video format Safari supports. Streaming-service page URLs are not direct video files.');
});
video.addEventListener('webkitcurrentplaybacktargetiswirelesschanged', updateWireless);
$('copy').addEventListener('click', async () => {
  const result = ['ParkCast Safari test', `Secure: ${window.isSecureContext}`, `AirPlay picker: ${hasPicker}`, `Native HLS: ${hls}`, `Wireless media: ${!!video.webkitCurrentPlaybackTargetIsWireless}`, `Source type: ${sourceKind}`, `Playback: ${$('playback-state').textContent}`, `Media error: ${video.error?.code ?? 'none'}`, `Browser: ${navigator.userAgent}`].join('\n');
  try { await navigator.clipboard.writeText(result); $('copy').textContent = 'Copied'; }
  catch { report(result); }
});
async function refreshBuild() {
  try {
    const response = await fetch('/api/build', { cache: 'no-store' });
    if (!response.ok) throw new Error('Unavailable');
    const build = await response.json();
    $('ipa').hidden = !build.available;
    $('build-status').textContent = build.available
      ? 'The native iPhone package is ready to download. It still needs signing and installation from your PC.'
      : 'The native iPhone build is being prepared. This page will update when its download is ready.';
  } catch { $('build-status').textContent = 'Could not check the native build. Keep your PC awake and refresh this page.'; }
}
refreshBuild();
setInterval(refreshBuild, 30000);
