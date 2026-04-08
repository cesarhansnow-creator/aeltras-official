/**
 * Aeltras 波欧诚顺 — Main Scripts
 * Hero carousel + future interactive features
 */

/* ── Hero Carousel ── */
(function() {
  var current = 0, timer;
  var track = document.getElementById('heroTrack');
  var dots = document.querySelectorAll('.hero-dot');

  if (!track || !dots.length) return;
  var total = dots.length;

  function go(i) {
    current = ((i % total) + total) % total;
    track.style.transform = 'translateX(-' + current * 100 + '%)';
    dots.forEach(function(d, idx) { d.classList.toggle('active', idx === current); });
  }

  function auto() {
    timer = setInterval(function() { go(current + 1); }, 4500);
  }

  window.goSlide = function(i) {
    clearInterval(timer);
    go(i);
    auto();
  };

  auto();
})();
