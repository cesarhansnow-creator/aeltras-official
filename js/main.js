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

/* ── Contact Maps (Leaflet + Esri ArcGIS Light Gray Canvas) ── */
(function() {
  function initMaps() {
    if (typeof L === 'undefined') { setTimeout(initMaps, 200); return; }

    // Esri ArcGIS Light Gray Canvas — global unified tile source, Esri's own CDN
    // (different infrastructure from CartoDB/CloudFront). Free, no API key.
    // Two layers: base (roads/areas) + reference (labels) = clean minimalist look.
    var baseUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';
    var refUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}';
    var tileOpts = {
      attribution: 'Tiles &copy; <a href="https://www.esri.com">Esri</a>',
      maxZoom: 16
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
      attributionControl: true,
      maxZoom: 16
    };

    function addEsriLayers(map) {
      L.tileLayer(baseUrl, tileOpts).addTo(map);
      L.tileLayer(refUrl, tileOpts).addTo(map);
    }

    // Chorzów (Poland)
    var el1 = document.getElementById('map-chorzow');
    if (el1 && !el1._leaflet_id) {
      var m1 = L.map(el1, mapOpts).setView([50.2945, 18.9681], 14);
      addEsriLayers(m1);
      L.marker([50.2945, 18.9681], { icon: goldIcon }).addTo(m1);
    }

    // Qingdao (China)
    var el2 = document.getElementById('map-qingdao');
    if (el2 && !el2._leaflet_id) {
      var m2 = L.map(el2, mapOpts).setView([36.0671, 120.3826], 11);
      addEsriLayers(m2);
      L.marker([36.0671, 120.3826], { icon: goldIcon }).addTo(m2);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initMaps);
  } else {
    initMaps();
  }
})();
