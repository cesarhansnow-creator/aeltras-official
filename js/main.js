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

/* ── Contact Maps (Leaflet + CartoDB tiles) ── */
(function() {
  function initMaps() {
    if (typeof L === 'undefined') { setTimeout(initMaps, 200); return; }

    // CartoDB Positron tiles via CloudFront CDN — global coverage including China edge nodes
    var tileUrl = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
    var tileOpts = {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
      subdomains: 'abcd',
      maxZoom: 19
    };

    var goldIcon = L.divIcon({
      className: 'aeltras-pin',
      html: '<span class="pin-ring"></span><span class="pin-dot"></span>',
      iconSize: [28, 28],
      iconAnchor: [14, 14]
    });

    var mapOpts = {
      zoomControl: true,
      scrollWheelZoom: false,
      dragging: true,
      doubleClickZoom: true,
      touchZoom: true,
      attributionControl: true
    };

    var el1 = document.getElementById('map-chorzow');
    if (el1 && !el1._leaflet_id) {
      var m1 = L.map(el1, mapOpts).setView([50.2945, 18.9681], 14);
      L.tileLayer(tileUrl, tileOpts).addTo(m1);
      L.marker([50.2945, 18.9681], { icon: goldIcon }).addTo(m1);
    }

    var el2 = document.getElementById('map-qingdao');
    if (el2 && !el2._leaflet_id) {
      var m2 = L.map(el2, mapOpts).setView([36.0671, 120.3826], 11);
      L.tileLayer(tileUrl, tileOpts).addTo(m2);
      L.marker([36.0671, 120.3826], { icon: goldIcon }).addTo(m2);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initMaps);
  } else {
    initMaps();
  }
})();
