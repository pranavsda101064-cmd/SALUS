(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var toggle = document.querySelector(".menu-toggle");
  var mobileMenu = document.getElementById("mobile-menu");
  var body = document.body;

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

  var revealItems = document.querySelectorAll(".reveal");
  var tagline = document.getElementById("tagline");
  var words = tagline ? tagline.querySelectorAll(".word") : [];

  if (reduceMotion) {
    revealItems.forEach(function (item) {
      item.classList.add("is-visible");
    });
    words.forEach(function (word) {
      word.classList.add("is-lit");
    });
  } else {
    if ("IntersectionObserver" in window) {
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
    } else {
      revealItems.forEach(function (item) {
        item.classList.add("is-visible");
      });
      words.forEach(function (word) {
        word.classList.add("is-lit");
      });
    }
  }

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
            link.classList.toggle(
              "is-current",
              link.getAttribute("href") === "#" + entry.target.id
            );
          });
        });
      },
      { rootMargin: "-40% 0px -50% 0px", threshold: 0 }
    );

    sections.forEach(function (section) {
      spy.observe(section);
    });
  }
})();
