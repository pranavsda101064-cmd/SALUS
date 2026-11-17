(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var mobileQuery = window.matchMedia("(max-width: 900px)");
  var canHover = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  var body = document.body;

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  /* Mobile navigation */

  var toggle = document.querySelector(".menu-toggle");
  var mobileMenu = document.getElementById("mobile-menu");

  function setMenu(open) {
    if (!toggle || !mobileMenu) return;
    toggle.classList.toggle("is-open", open);
    mobileMenu.classList.toggle("is-open", open);
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
    toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    mobileMenu.setAttribute("aria-hidden", open ? "false" : "true");
    body.classList.toggle("no-scroll", open);
    if (open) {
      var first = mobileMenu.querySelector("a");
      if (first) first.focus();
    } else {
      toggle.focus();
    }
  }

  if (toggle && mobileMenu) {
    toggle.addEventListener("click", function () {
      setMenu(!mobileMenu.classList.contains("is-open"));
    });
    mobileMenu.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        setMenu(false);
      });
    });
    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && mobileMenu.classList.contains("is-open")) {
        setMenu(false);
      }
    });
    window.addEventListener("resize", function () {
      if (window.innerWidth > 900 && mobileMenu.classList.contains("is-open")) {
        setMenu(false);
      }
    });
  }

  /* Reveals, tagline words, highlighter marks, meter */

  var revealItems = document.querySelectorAll(".reveal");
  var tagline = document.getElementById("tagline");
  var words = tagline ? tagline.querySelectorAll(".word") : [];
  var marks = Array.prototype.slice.call(document.querySelectorAll("[data-mark]"));
  var meters = Array.prototype.slice.call(document.querySelectorAll("[data-meter-block]"));

  function showAll() {
    revealItems.forEach(function (item) {
      item.classList.add("is-visible");
    });
    words.forEach(function (word) {
      word.classList.add("is-lit");
    });
    marks.forEach(function (mark) {
      mark.classList.add("is-on");
    });
    meters.forEach(function (meter) {
      meter.classList.add("is-on");
    });
  }

  if (reduceMotion || !("IntersectionObserver" in window)) {
    showAll();
  } else {
    var revealObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          revealObserver.unobserve(entry.target);
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
    );
    revealItems.forEach(function (item) {
      revealObserver.observe(item);
    });

    var wordObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-lit");
          wordObserver.unobserve(entry.target);
        });
      },
      { threshold: 0.1, rootMargin: "0px 0px -20% 0px" }
    );
    words.forEach(function (word, index) {
      word.style.transitionDelay = index * 40 + "ms";
      wordObserver.observe(word);
    });

    var markObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-on");
          markObserver.unobserve(entry.target);
        });
      },
      { threshold: 0.6 }
    );
    marks.forEach(function (mark) {
      markObserver.observe(mark);
    });

    var meterObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-on");
          meterObserver.unobserve(entry.target);
        });
      },
      { threshold: 0.5 }
    );
    meters.forEach(function (meter) {
      meterObserver.observe(meter);
    });
  }

  /* Active section in the nav */

  var navLinks = Array.prototype.slice.call(document.querySelectorAll(".nav-links a"));
  var sections = ["how-it-works", "evidence", "faq"]
    .map(function (id) {
      return document.getElementById(id);
    })
    .filter(Boolean);

  if ("IntersectionObserver" in window && navLinks.length && sections.length) {
    var spy = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          navLinks.forEach(function (link) {
            link.classList.toggle("is-current", link.getAttribute("href") === "#" + entry.target.id);
          });
        });
      },
      { rootMargin: "-40% 0px -50% 0px", threshold: 0 }
    );
    sections.forEach(function (section) {
      spy.observe(section);
    });
  }

  /* Parallax, benefit rail, Ghost Copy scene. One rAF per frame, transform only. */

  var parallaxFrames = Array.prototype.slice.call(document.querySelectorAll("[data-parallax]"));
  var slideMediaList = Array.prototype.slice.call(document.querySelectorAll(".carousel-slide"));
  var carousel = document.querySelector("[data-carousel]");
  var track = carousel ? carousel.querySelector("[data-carousel-track]") : null;
  var slides = track ? Array.prototype.slice.call(track.querySelectorAll("[data-carousel-slide]")) : [];
  var railWrap = document.querySelector(".benefit-wrap");
  var ghostSection = document.querySelector("[data-ghost]");
  var ghostStage = document.querySelector("[data-ghost-stage]");
  var ghostField = document.querySelector("[data-ghost-field]");
  var ghostCount = document.querySelector("[data-ghost-count]");
  var ghostSteps = Array.prototype.slice.call(document.querySelectorAll(".ghost-step"));
  var frameId = 0;

  function updateParallax() {
    frameId = 0;
    var vh = window.innerHeight || 1;

    if (!reduceMotion) {
      parallaxFrames.forEach(function (el) {
        var rect = el.getBoundingClientRect();
        if (rect.bottom < -100 || rect.top > vh + 100) return;
        var limit = rect.height * 0.07;
        var ratio = clamp((rect.top + rect.height / 2 - vh / 2) / (vh / 2 + rect.height / 2), -1, 1);
        el.style.setProperty("--py", (-ratio * limit).toFixed(2) + "px");
      });

      if (track && slides.length) {
        var trackRect = track.getBoundingClientRect();
        var center = trackRect.left + trackRect.width / 2;
        slides.forEach(function (slide) {
          var rect = slide.getBoundingClientRect();
          var ratio = clamp(
            (rect.left + rect.width / 2 - center) / (trackRect.width / 2 + rect.width / 2),
            -1,
            1
          );
          slide.style.setProperty("--focus", (1 - Math.abs(ratio)).toFixed(3));
          var media = slide.querySelector("[data-parallax-x]");
          if (media) {
            media.style.setProperty("--px", (-ratio * media.clientWidth * 0.08).toFixed(2) + "px");
          }
        });
      }
    }

    if (railWrap) {
      var railRect = railWrap.getBoundingClientRect();
      var railProgress = clamp((vh * 0.75 - railRect.top) / railRect.height, 0, 1);
      railWrap.style.setProperty("--rail", reduceMotion ? "1" : railProgress.toFixed(3));
    }

    if (ghostSection && ghostStage) {
      updateGhost(vh);
    }
  }

  function requestParallax() {
    if (!frameId) frameId = window.requestAnimationFrame(updateParallax);
  }

  /* Ghost Copy scene: 1,000 cells, 300 matched. Phases follow scroll. */

  var GHOST_TOTAL = 1000;
  var GHOST_HITS = 300;
  var ghostPhase = "";
  var ghostCells = [];

  function seededRandom(seed) {
    var state = seed >>> 0;
    return function () {
      state = (state + 0x6d2b79f5) >>> 0;
      var t = state;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function buildGhostField() {
    if (!ghostField || ghostCells.length) return;
    var random = seededRandom(42);
    var order = [];
    for (var i = 0; i < GHOST_TOTAL; i++) order.push(i);
    for (var j = order.length - 1; j > 0; j--) {
      var k = Math.floor(random() * (j + 1));
      var tmp = order[j];
      order[j] = order[k];
      order[k] = tmp;
    }
    var hits = {};
    order.slice(0, GHOST_HITS).forEach(function (index) {
      hits[index] = true;
    });
    var fragment = document.createDocumentFragment();
    for (var c = 0; c < GHOST_TOTAL; c++) {
      var cell = document.createElement("span");
      cell.className = "cell" + (hits[c] ? " is-hit" : " is-gone");
      fragment.appendChild(cell);
      ghostCells.push(cell);
    }
    ghostField.appendChild(fragment);
  }

  function setGhostPhase(phase, matched) {
    if (!ghostStage) return;
    if (phase !== ghostPhase) {
      ghostPhase = phase;
      ghostStage.classList.remove("is-source", "is-ghost", "is-match");
      ghostStage.classList.add("is-" + phase);
      ghostSteps.forEach(function (step) {
        var active = step.getAttribute("data-step") === String(["source", "ghost", "match"].indexOf(phase));
        step.classList.toggle("is-active", active);
      });
    }
    if (ghostCount) {
      ghostCount.textContent = String(matched);
    }
  }

  function updateGhost(vh) {
    if (mobileQuery.matches || reduceMotion) {
      setGhostPhase("match", GHOST_HITS);
      return;
    }
    var rect = ghostSection.getBoundingClientRect();
    var range = Math.max(1, ghostSection.offsetHeight - vh);
    var progress = clamp(-rect.top / range, 0, 1);
    if (progress < 0.34) {
      setGhostPhase("source", 0);
    } else if (progress < 0.67) {
      setGhostPhase("ghost", 0);
    } else {
      var matchProgress = clamp((progress - 0.67) / 0.33, 0, 1);
      setGhostPhase("match", Math.round(GHOST_HITS * matchProgress));
    }
  }

  buildGhostField();

  if (parallaxFrames.length || slides.length || railWrap || ghostSection) {
    window.addEventListener("scroll", requestParallax, { passive: true });
    window.addEventListener("resize", requestParallax);
    updateParallax();
  }

  /* Tilt on the incident panel, fine pointers only */

  if (canHover && !reduceMotion) {
    document.querySelectorAll("[data-tilt]").forEach(function (el) {
      el.addEventListener("pointermove", function (event) {
        var rect = el.getBoundingClientRect();
        var x = (event.clientX - rect.left) / rect.width - 0.5;
        var y = (event.clientY - rect.top) / rect.height - 0.5;
        el.style.setProperty("--ry", (x * 8).toFixed(2) + "deg");
        el.style.setProperty("--rx", (-y * 6).toFixed(2) + "deg");
      });
      el.addEventListener("pointerleave", function () {
        el.style.setProperty("--rx", "0deg");
        el.style.setProperty("--ry", "0deg");
      });
    });
  }

  /* Carousel. Autoplay runs on the progress bar, so pausing pauses the timer too. */

  if (carousel && track && slides.length) {
    var dots = Array.prototype.slice.call(carousel.querySelectorAll("[data-carousel-dot]"));
    var autoToggle = carousel.querySelector("[data-carousel-toggle]");
    var progressBar = carousel.querySelector("[data-carousel-progress]");
    var prevButton = document.querySelector("[data-carousel-prev]");
    var nextButton = document.querySelector("[data-carousel-next]");
    var index = 0;
    var autoplay = !reduceMotion;
    var hovered = false;
    var focused = false;

    function stepSize() {
      var gap = parseFloat(window.getComputedStyle(track).columnGap) || 0;
      return slides[0].offsetWidth + gap;
    }

    function syncIndicators() {
      dots.forEach(function (dot, i) {
        dot.setAttribute("aria-current", i === index ? "true" : "false");
      });
    }

    function isPaused() {
      return hovered || focused || document.hidden || !autoplay;
    }

    function syncPaused() {
      if (isPaused()) {
        carousel.setAttribute("data-paused", "");
      } else {
        carousel.removeAttribute("data-paused");
      }
    }

    function restartProgress() {
      if (!progressBar) return;
      carousel.classList.remove("is-running");
      void progressBar.offsetWidth;
      if (autoplay && !reduceMotion) carousel.classList.add("is-running");
      syncPaused();
    }

    function goTo(target) {
      index = (target + slides.length) % slides.length;
      track.scrollTo({
        left: index * stepSize(),
        behavior: reduceMotion ? "auto" : "smooth",
      });
      syncIndicators();
    }

    function userMoved(target) {
      goTo(target);
      restartProgress();
    }

    function syncFromScroll() {
      var next = clamp(Math.round(track.scrollLeft / stepSize()), 0, slides.length - 1);
      if (next !== index) {
        index = next;
        syncIndicators();
      }
    }

    if (progressBar) {
      progressBar.addEventListener("animationend", function () {
        if (!autoplay || isPaused()) {
          restartProgress();
          return;
        }
        goTo(index + 1);
        restartProgress();
      });
    }

    if (prevButton) {
      prevButton.addEventListener("click", function () {
        userMoved(index - 1);
      });
    }
    if (nextButton) {
      nextButton.addEventListener("click", function () {
        userMoved(index + 1);
      });
    }
    dots.forEach(function (dot, i) {
      dot.addEventListener("click", function () {
        userMoved(i);
      });
    });

    track.addEventListener("keydown", function (event) {
      if (event.key === "ArrowRight") userMoved(index + 1);
      if (event.key === "ArrowLeft") userMoved(index - 1);
      if (event.key === "Home") userMoved(0);
      if (event.key === "End") userMoved(slides.length - 1);
    });

    var scrollFrame = 0;
    track.addEventListener(
      "scroll",
      function () {
        if (scrollFrame) return;
        scrollFrame = window.requestAnimationFrame(function () {
          scrollFrame = 0;
          syncFromScroll();
          requestParallax();
        });
      },
      { passive: true }
    );

    carousel.addEventListener("pointerenter", function () {
      hovered = true;
      syncPaused();
    });
    carousel.addEventListener("pointerleave", function () {
      hovered = false;
      syncPaused();
    });
    carousel.addEventListener("focusin", function () {
      focused = true;
      syncPaused();
    });
    carousel.addEventListener("focusout", function () {
      focused = false;
      syncPaused();
    });
    document.addEventListener("visibilitychange", syncPaused);

    if (autoToggle) {
      var setToggle = function () {
        autoToggle.setAttribute("aria-pressed", autoplay ? "true" : "false");
        autoToggle.textContent = autoplay ? "Autoplay on" : "Autoplay off";
      };
      setToggle();
      autoToggle.addEventListener("click", function () {
        autoplay = !autoplay;
        setToggle();
        if (!autoplay) carousel.classList.remove("is-running");
        restartProgress();
      });
    }

    syncIndicators();
    restartProgress();
  }

  /* Count-up for the real demo numbers. Starts once, when in view. */

  var counters = Array.prototype.slice.call(document.querySelectorAll("[data-count]"));

  function countUp(el) {
    var target = parseFloat(el.getAttribute("data-count"));
    var decimals = parseInt(el.getAttribute("data-decimals") || "0", 10);
    var duration = 1400;
    var startTime = null;

    function tickCount(now) {
      if (startTime === null) startTime = now;
      var progress = clamp((now - startTime) / duration, 0, 1);
      var eased = 1 - Math.pow(1 - progress, 3);
      el.textContent = (target * eased).toFixed(decimals);
      if (progress < 1) {
        window.requestAnimationFrame(tickCount);
      } else {
        el.textContent = target.toFixed(decimals);
      }
    }

    window.requestAnimationFrame(tickCount);
  }

  if (counters.length && !reduceMotion && "IntersectionObserver" in window) {
    counters.forEach(function (el) {
      el.textContent = (0).toFixed(parseInt(el.getAttribute("data-decimals") || "0", 10));
    });
    var countObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          countUp(entry.target);
          countObserver.unobserve(entry.target);
        });
      },
      { threshold: 0.6 }
    );
    counters.forEach(function (el) {
      countObserver.observe(el);
    });
  }
})();
