/* Pause/play control for the decorative background video (WCAG 2.2.2).
   Source selection and the reduced-motion check run inline in index.html, before playback. */
(function () {
  'use strict';
  var video = document.getElementById('bg-video');
  var btn = document.getElementById('bg-toggle');
  var root = document.documentElement;
  if (!video || !btn || typeof video.play !== 'function') return;

  var label = document.getElementById('bg-toggle-label');
  var KEY = 'ontos-bg-paused';
  var expectPlay = !root.classList.contains('bg-still');

  function remember(paused) {
    try { window.localStorage.setItem(KEY, paused ? '1' : '0'); } catch (e) {}
  }

  function render(paused) {
    btn.classList.toggle('is-paused', paused);
    label.textContent = paused ? 'Play background video' : 'Pause background video';
  }

  function sync() { render(video.paused); }

  function hideIfNoVideo() {
    if (root.classList.contains('no-video')) btn.hidden = true;
  }

  btn.addEventListener('click', function () {
    if (video.paused) {
      remember(false);
      video.preload = 'auto';
      var p = video.play();
      if (p && typeof p.catch === 'function') p.catch(sync);
    } else {
      remember(true);
      video.pause();
    }
    sync();
  });

  video.addEventListener('play', sync);
  video.addEventListener('playing', sync);
  video.addEventListener('pause', sync);
  video.addEventListener('error', function () { setTimeout(hideIfNoVideo, 0); });
  var sources = video.getElementsByTagName('source');
  if (sources.length) {
    sources[sources.length - 1].addEventListener('error', function () { setTimeout(hideIfNoVideo, 0); });
  }

  // Follow a reduced-motion switch made while the page is open.
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    var onChange = function (e) { if (e.matches && !video.paused) video.pause(); };
    if (mq.addEventListener) mq.addEventListener('change', onChange);
    else if (mq.addListener) mq.addListener(onChange);
  }

  // Autoplay is intended unless motion is reduced; correct the icon if the
  // browser blocked it (e.g. iOS Low Power Mode never fires an event for that).
  render(expectPlay ? false : true);
  if (expectPlay) setTimeout(sync, 2500);

  btn.hidden = false;
  hideIfNoVideo();
})();
