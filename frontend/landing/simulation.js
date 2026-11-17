(function () {
  "use strict";

  var root = document.querySelector("[data-sim]");
  if (!root) return;

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var SVG_NS = "http://www.w3.org/2000/svg";

  var els = {
    status: root.querySelector("[data-sim-status]"),
    statusDot: root.querySelector("[data-sim-status-dot]"),
    play: root.querySelector("[data-sim-play]"),
    restart: root.querySelector("[data-sim-restart]"),
    prev: root.querySelector("[data-sim-prev]"),
    next: root.querySelector("[data-sim-next]"),
    speed: root.querySelector("[data-sim-speed]"),
    visual: root.querySelector("[data-sim-visual]"),
    step: root.querySelector("[data-sim-step]"),
    live: root.querySelector("[data-sim-live]"),
    title: root.querySelector("[data-sim-title]"),
    body: root.querySelector("[data-sim-body]"),
    facts: root.querySelector("[data-sim-facts]"),
    agents: root.querySelector("[data-sim-agents]"),
    hint: root.querySelector("[data-sim-hint]"),
    progress: root.querySelector("[data-sim-progress]"),
    progressFill: root.querySelector("[data-sim-progress-fill]"),
    chapters: Array.prototype.slice.call(root.querySelectorAll("[data-sim-chapter]")),
    footnote: root.querySelector("[data-sim-footnote]"),
    announcer: root.querySelector("[data-sim-announcer]")
  };

  var PII_LABELS = {
    AADHAAR: "Aadhaar · Verhoeff",
    PAN: "PAN",
    GSTIN: "GSTIN · checksum",
    UPI_ID: "UPI ID",
    PHONE: "Phone",
    EMAIL: "Email",
    NAME: "Name",
    LOCATION: "Location",
    FINANCIAL_ACCOUNT: "Financial account",
    FINANCIAL_AMOUNT: "Financial amount",
    OTHER: "Context"
  };

  var FEATURE_LABELS = {
    hour_sin: "Hour of day (sin)",
    hour_cos: "Hour of day (cos)",
    is_weekend: "Weekend flag",
    viewed: "View action",
    downloaded: "Download action",
    copied: "Copy action",
    shared: "External share",
    log_volume: "Log volume",
    destination_trust: "Destination trust",
    file_sensitivity: "File sensitivity"
  };

  var AGENTS = [
    { id: "simulator", name: "Simulator", writes: "events only" },
    { id: "intake", name: "Intake", writes: "hashes, dedupe" },
    { id: "identifier", name: "Identifier", writes: "PII labels" },
    { id: "dna", name: "DNA", writes: "fingerprints, match, canary" },
    { id: "correlation", name: "Correlation", writes: "stored event links" },
    { id: "behaviour", name: "Behaviour", writes: "B score" },
    { id: "risk", name: "Risk", writes: "S/D/B/E score" },
    { id: "report", name: "Report", writes: "grounded report" }
  ];

  var state = {
    index: 0,
    playing: false,
    timer: null,
    speed: 1,
    data: null,
    source: "",
    fetchedAt: null,
    reason: "",
    rafIds: []
  };

  function node(tag, className, text) {
    var element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined && text !== null) element.textContent = String(text);
    return element;
  }

  function add(parent) {
    for (var index = 1; index < arguments.length; index++) {
      var child = arguments[index];
      if (child) parent.appendChild(child);
    }
    return parent;
  }

  function svgNode(tag, attributes) {
    var element = document.createElementNS(SVG_NS, tag);
    Object.keys(attributes || {}).forEach(function (key) {
      element.setAttribute(key, attributes[key]);
    });
    return element;
  }

  function get(object, path, fallback) {
    var current = object;
    var parts = String(path || "").split(".");
    for (var index = 0; index < parts.length; index++) {
      if (current === null || current === undefined) return fallback;
      current = current[parts[index]];
    }
    return current === null || current === undefined ? fallback : current;
  }

  function num(value, fallback) {
    var parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback || 0;
  }

  function fmt(value) {
    return num(value, 0).toLocaleString("en-IN");
  }

  function pct(value, decimals) {
    return (num(value, 0) * 100).toFixed(decimals || 0) + "%";
  }

  function fixed(value, decimals) {
    return num(value, 0).toFixed(decimals || 0);
  }

  function shortHash(value) {
    var text = String(value || "");
    if (text.length <= 18) return text || "not recorded";
    return text.slice(0, 10) + "…" + text.slice(-6);
  }

  function shortTime(value) {
    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value || "");
    return date.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" });
  }

  function titleCase(value) {
    return String(value || "")
      .toLowerCase()
      .split(/_|\s+/)
      .filter(Boolean)
      .map(function (part) {
        return part.charAt(0).toUpperCase() + part.slice(1);
      })
      .join(" ");
  }

  function prettyAction(value) {
    return titleCase(value);
  }

  function prettyPii(value) {
    return PII_LABELS[value] || titleCase(value);
  }

  function prettyFeature(value) {
    return FEATURE_LABELS[value] || titleCase(value);
  }

  function apiBase() {
    var meta = document.querySelector('meta[name="salus-api-base"]');
    var base = meta ? String(meta.content || "").trim() : "";
    if (!base || base.indexOf("__SALUS_API_BASE__") !== -1) {
      base = "http://localhost:8000";
    }
    return base.replace(/\/+$/, "");
  }

  function fetchJson(url, timeoutMs) {
    var controller = new AbortController();
    var timer = window.setTimeout(function () {
      controller.abort();
    }, timeoutMs || 5000);
    return window
      .fetch(url, { signal: controller.signal, cache: "no-store" })
      .then(function (response) {
        window.clearTimeout(timer);
        if (!response.ok) throw new Error("HTTP " + response.status);
        return response.json();
      })
      .catch(function (error) {
        window.clearTimeout(timer);
        throw error;
      });
  }

  function loadSnapshot() {
    return fetchJson("simulation-data.json", 5000);
  }

  function loadStory() {
    return fetchJson(apiBase() + "/api/v1/simulation/ghost-copy", 5000)
      .then(function (live) {
        if (live && live.available) {
          return { data: live, source: "live", fetchedAt: new Date() };
        }
        return loadSnapshot().then(function (snapshot) {
          return {
            data: snapshot,
            source: "snapshot",
            reason: (live && live.reason) || "The live demo has no incident yet."
          };
        });
      })
      .catch(function () {
        return loadSnapshot().then(function (snapshot) {
          return { data: snapshot, source: "snapshot", reason: "Live API unavailable." };
        });
      });
  }

  function showUnavailable() {
    els.status.textContent = "Demo evidence unavailable";
    els.statusDot.className = "sim-status-dot is-error";
    els.live.textContent = "NO DATA";
    els.live.className = "sim-live";
    els.title.textContent = "Demo evidence unavailable";
    els.body.textContent =
      "Run the demo workspace or open the app to generate the Ghost Copy evidence. The page will use the bundled snapshot when it is available.";
    els.facts.innerHTML = "";
    els.agents.innerHTML = "";
    els.hint.textContent = "Synthetic data only.";
    els.visual.innerHTML =
      '<div class="viz"><div class="viz-file"><strong>Demo evidence unavailable</strong><span class="viz-file-meta"><span>Check the API and reload this page.</span></span></div></div>';
    els.play.disabled = true;
  }

  function updateStatus() {
    if (state.source === "live") {
      var fetched = state.fetchedAt
        ? state.fetchedAt.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })
        : "";
      els.status.textContent = "Live demo evidence" + (fetched ? " · fetched " + fetched : "");
      els.statusDot.className = "sim-status-dot";
      els.live.textContent = "LIVE DEMO DATA";
      els.live.className = "sim-live is-live";
    } else {
      els.status.textContent =
        "Bundled demo snapshot" + (state.reason ? " · " + state.reason : "");
      els.statusDot.className = "sim-status-dot is-snapshot";
      els.live.textContent = "BUNDLED SNAPSHOT";
      els.live.className = "sim-live";
    }
  }

  function cancelRafs() {
    state.rafIds.forEach(function (id) {
      window.cancelAnimationFrame(id);
    });
    state.rafIds = [];
  }

  function animateCount(element, target, duration) {
    if (!element || reduceMotion) {
      if (element) element.textContent = fmt(target);
      return;
    }
    if (!element.isConnected) return;
    var start = null;
    function step(timestamp) {
      if (start === null) start = timestamp;
      var progress = Math.min((timestamp - start) / duration, 1);
      var eased = 1 - Math.pow(1 - progress, 3);
      element.textContent = fmt(Math.round(target * eased));
      if (progress < 1) {
        state.rafIds.push(window.requestAnimationFrame(step));
      }
    }
    state.rafIds.push(window.requestAnimationFrame(step));
  }

  function factList(items) {
    els.facts.innerHTML = "";
    items.forEach(function (item) {
      var wrapper = node("div", "sim-fact");
      add(wrapper, node("dt", "", item[0]), node("dd", "", item[1]));
      els.facts.appendChild(wrapper);
    });
  }

  function renderAgents(activeIds) {
    els.agents.innerHTML = "";
    els.agents.appendChild(node("span", "viz-label", "Pipeline agents"));
    AGENTS.forEach(function (agent) {
      var chip = node("span", "sim-agent" + (activeIds.indexOf(agent.id) !== -1 ? " is-active" : ""));
      chip.title = agent.name + " agent writes " + agent.writes;
      add(chip, node("i"), document.createTextNode(agent.name));
      els.agents.appendChild(chip);
    });
  }

  function datasetFacts(data) {
    var dataset = data.dataset || {};
    var dna = dataset.dna || {};
    return [
      ["Dataset", dataset.name || "customer_master_v1"],
      ["Rows / columns", fmt(dataset.rows) + " / " + fmt(dataset.columns)],
      ["Sensitivity", dataset.sensitivity || "CRITICAL"],
      ["Canary rows", fmt(dna.canary_rows)],
      ["Cell fingerprints", fmt(dna.cell_fingerprints)],
      ["Watermark", dataset.watermark || "none"]
    ];
  }

  function movementFacts(data) {
    var events = get(data, "movement.events", []);
    var download = events.filter(function (event) {
      return event.action === "FILE_DOWNLOADED";
    })[0];
    var share = events.filter(function (event) {
      return event.action === "EXTERNAL_SHARE";
    })[0];
    return [
      ["Download", download ? download.actor_id + " · " + download.event_id : "not recorded"],
      ["External share", share ? share.destination + " · " + share.event_id : "not recorded"],
      ["Event window", "4 minutes apart"],
      ["Evidence label", "SIMULATED"],
      ["Source", "Simulator agent"],
      ["Writes", "Events only"]
    ];
  }

  function ghostFacts(data) {
    var ghost = data.ghost_copy || {};
    return [
      ["Source rows", fmt(ghost.original_rows)],
      ["Copy rows", fmt(ghost.ghost_rows)],
      ["Rows removed", fmt(ghost.rows_removed)],
      ["Columns dropped", (ghost.dropped_columns || []).join(", ") || "none"],
      ["Canary rows kept", fmt(ghost.canary_rows_kept)],
      ["Watermark", ghost.watermark_stripped ? "stripped" : "present"]
    ];
  }

  function intakeFacts(data) {
    var intake = data.intake || {};
    return [
      ["Input", intake.filename || "clients_export_final.csv"],
      ["SHA-256", shortHash(intake.sha256)],
      ["Rows / columns", fmt(intake.rows) + " / " + fmt(intake.columns)],
      ["Investigation", intake.investigation_id || "new intake"],
      ["Status", intake.status || "OPEN"],
      ["Raw rows stored", "No"]
    ];
  }

  function dnaFacts(data) {
    var match = data.match || {};
    var evidence = match.evidence || {};
    return [
      ["Match score", fixed(match.match_score, 3)],
      ["Matched rows", fmt(match.matched_rows)],
      ["Matched cells", fmt(match.matched_cells)],
      ["Row coverage", pct(match.recall_vs_original)],
      ["Rare values shared", fmt(evidence.rare_shared_values)],
      ["Matched columns", fmt((match.matched_columns || []).length)]
    ];
  }

  function trackingFacts(data) {
    var canary = get(data, "match.canary", {});
    var events = get(data, "tracking.timeline", []);
    var edges = get(data, "tracking.lineage.edges", []);
    var audit = get(data, "tracking.audit_trail", []);
    return [
      ["Canary", canary.found ? canary.canary_id : "not found"],
      ["Canary recipient", canary.recipient || "not available"],
      ["Timeline events", fmt(events.length)],
      ["Lineage edges", fmt(edges.length)],
      ["Every edge has", "EVENT or MATCH ref"],
      ["Audit entries", fmt(audit.length)]
    ];
  }

  function behaviourFacts(data) {
    var behaviour = data.behaviour || {};
    return [
      ["Model", behaviour.model_version || "ae-v1"],
      ["Architecture", (behaviour.architecture || [10, 8, 4, 10]).join(" → ")],
      ["B score", fmt(behaviour.score)],
      ["Percentile", fmt(behaviour.percentile)],
      ["Baseline samples", fmt(behaviour.samples)],
      ["Reconstruction error", behaviour.error === null || behaviour.error === undefined ? "n/a" : fixed(behaviour.error, 6)]
    ];
  }

  function riskFacts(data) {
    var risk = data.risk || {};
    var factors = risk.factors || {};
    var report = data.report || {};
    return [
      ["Total", fmt(risk.total)],
      ["Band", risk.band || "LOW"],
      ["Policy", risk.policy_version || "risk-v1-demo"],
      ["Sensitivity (S)", fmt(get(factors, "S.score", 0))],
      ["Destination (D)", fmt(get(factors, "D.score", 0))],
      ["Behaviour (B)", fmt(get(factors, "B.score", 0))],
      ["Sequence (E)", fmt(get(factors, "E.score", 0))],
      ["Evidence hash", shortHash(report.evidence_hash)]
    ];
  }

  function renderDataset(data) {
    var dataset = data.dataset || {};
    var dna = dataset.dna || {};
    var columns = Array.isArray(dataset.column_metadata) ? dataset.column_metadata : [];
    var canary = dataset.canary || {};
    var wrap = node("div", "viz viz-dataset");
    var file = node("div", "viz-file");
    var head = node("div", "viz-file-head");
    add(
      head,
      node("span", "viz-file-name", dataset.filename || dataset.name || "customer_master_v1.xlsx"),
      node("span", "viz-chip" + (dataset.sensitivity === "CRITICAL" ? " is-warn" : ""), dataset.sensitivity || "CRITICAL")
    );
    var meta = node("div", "viz-file-meta");
    add(meta, node("span", "", fmt(dataset.rows) + " rows"), node("span", "", fmt(dataset.columns) + " columns"), node("span", "", fmt(dna.canary_rows) + " canary rows"));
    add(file, head, meta);
    if (dataset.watermark) add(file, node("span", "viz-watermark", dataset.watermark));
    add(file, node("div", "viz-scanline"));

    var columnWrap = node("div", "viz-columns");
    if (columns.length) {
      columns.slice(0, 11).forEach(function (column) {
        var pii = column.pii_type && column.pii_type !== "OTHER";
        var chip = node("div", "viz-column" + (pii ? " is-pii" : ""));
        add(chip, node("strong", "", column.name || "column"), node("span", "", prettyPii(column.pii_type)));
        columnWrap.appendChild(chip);
      });
    } else {
      ["customer_ref", "full_name", "email", "phone", "aadhaar", "pan", "gstin", "upi_id", "city", "account_no", "monthly_income"].forEach(function (name) {
        columnWrap.appendChild(node("div", "viz-column", name));
      });
    }
    var canaries = node("div", "viz-canaries");
    (canary.row_labels || []).slice(0, 5).forEach(function (label) {
      canaries.appendChild(node("span", "viz-canary-row", label));
    });
    if (!canaries.children.length) canaries.appendChild(node("span", "viz-canary-row", "CN-007 rows present"));
    add(columnWrap, canaries);
    add(wrap, file, columnWrap);
    return wrap;
  }

  function renderMovement(data) {
    var dataset = data.dataset || {};
    var events = get(data, "movement.events", []);
    var download = events.filter(function (event) {
      return event.action === "FILE_DOWNLOADED";
    })[0];
    var share = events.filter(function (event) {
      return event.action === "EXTERNAL_SHARE";
    })[0];
    var wrap = node("div", "viz viz-flow");
    var map = node("div", "flow-map");
    add(map, node("div", "flow-line"));
    [
      { left: "10%", title: dataset.name || "customer_master_v1", sub: "source dataset", className: "" },
      { left: "50%", title: download ? download.actor_id : "USER-104", sub: "download device", className: "is-actor" },
      { left: "90%", title: share ? share.destination : "external_domain.com", sub: "external destination", className: "is-external" }
    ].forEach(function (item) {
      var entry = node("div", "flow-node " + item.className);
      entry.style.left = item.left;
      add(entry, node("div", "flow-node-dot"), node("strong", "", item.title), node("span", "", item.sub));
      map.appendChild(entry);
    });
    add(map, node("div", "flow-token"));
    var eventWrap = node("div", "flow-events");
    [download, share].forEach(function (event) {
      if (!event) return;
      var card = node("div", "flow-event");
      add(
        card,
        node("strong", "", prettyAction(event.action)),
        node("span", "", event.actor_id + " → " + (event.destination || "unknown")),
        node("span", "", event.event_id + " · " + shortTime(event.timestamp)),
        node("span", "viz-chip", "SIMULATED")
      );
      eventWrap.appendChild(card);
    });
    if (!eventWrap.children.length) {
      var fallback = node("div", "flow-event");
      add(fallback, node("strong", "", "No movement event"), node("span", "", "Replay the simulator to generate the download and share."));
      eventWrap.appendChild(fallback);
    }
    add(wrap, map, eventWrap);
    return wrap;
  }

  function renderGhost(data) {
    var ghost = data.ghost_copy || {};
    var dataset = data.dataset || {};
    var wrap = node("div", "viz viz-ghost");
    var card = node("div", "ghost-card");
    add(card, node("div", "ghost-filename", ghost.renamed_to || "clients_export_final.csv"));
    var sourceCounter = node("div", "ghost-counter");
    var sourceValue = node("strong", "", "0");
    sourceValue.setAttribute("data-count-to", String(num(ghost.original_rows, 0)));
    add(sourceCounter, sourceValue, node("span", "", "rows in source"));
    var copyCounter = node("div", "ghost-counter");
    var copyValue = node("strong", "", "0");
    copyValue.setAttribute("data-count-to", String(num(ghost.ghost_rows, 0)));
    add(copyCounter, copyValue, node("span", "", "rows in copy"));
    add(card, sourceCounter, copyCounter);
    if (ghost.watermark_stripped) add(card, node("span", "ghost-stamp", "WATERMARK REMOVED"));

    var changes = node("div", "ghost-changes");
    [
      ["Rename", (ghost.renamed_from || "customer_master_v1.xlsx") + " → " + (ghost.renamed_to || "clients_export_final.csv")],
      ["Format", ghost.format_change || "XLSX to CSV"],
      ["Rows dropped", fmt(ghost.rows_removed)],
      ["Columns dropped", fmt((ghost.dropped_columns || []).length)],
      ["Canaries kept", fmt(ghost.canary_rows_kept)]
    ].forEach(function (item) {
      var row = node("div", "ghost-change");
      add(row, node("span", "", item[0]), node("strong", "", item[1]));
      changes.appendChild(row);
    });

    var columns = node("div", "ghost-columns");
    var dropped = ghost.dropped_columns || [];
    var allColumns = (dataset.column_metadata || []).map(function (column) {
      return column.name;
    });
    var names = allColumns.length ? allColumns : (ghost.matched_columns || []).concat(dropped);
    names.forEach(function (name) {
      columns.appendChild(
        node("span", "ghost-col " + (dropped.indexOf(name) !== -1 ? "is-dropped" : "is-kept"), name)
      );
    });
    add(wrap, card, changes, columns);

    window.setTimeout(function () {
      var counters = wrap.querySelectorAll("[data-count-to]");
      Array.prototype.forEach.call(counters, function (counter) {
        animateCount(counter, num(counter.getAttribute("data-count-to"), 0), 1400);
      });
    }, 60);
    return wrap;
  }

  function renderIntake(data) {
    var intake = data.intake || {};
    var dataset = data.dataset || {};
    var wrap = node("div", "viz viz-intake");
    var gate = node("div", "intake-gate");
    add(
      gate,
      node("span", "viz-label", "Investigation intake"),
      node("strong", "", intake.filename || "clients_export_final.csv"),
      node("span", "viz-code", "SHA-256 " + shortHash(intake.sha256)),
      node("span", "viz-chip is-accent", fmt(intake.rows) + " rows · " + fmt(intake.columns) + " columns"),
      node("span", "viz-chip", intake.investigation_id ? "New investigation · " + intake.investigation_id : "New investigation")
    );
    var scan = node("div", "intake-scan");
    add(scan, node("span", "viz-label", "Identification pass"));
    var detectors = node("div", "intake-detectors");
    var columns = (dataset.column_metadata || []).filter(function (column) {
      return column.pii_type && column.pii_type !== "OTHER";
    });
    if (columns.length) {
      columns.slice(0, 9).forEach(function (column) {
        var label = prettyPii(column.pii_type);
        if (column.pii_type === "AADHAAR") {
          label += " · " + fmt(column.valid_count) + " valid / " + fmt(column.invalid_count) + " invalid";
        }
        detectors.appendChild(node("span", "viz-chip", label));
      });
    } else {
      ["Aadhaar · Verhoeff", "PAN", "GSTIN · checksum", "UPI ID", "Phone", "Email"].forEach(function (label) {
        detectors.appendChild(node("span", "viz-chip", label));
      });
    }
    add(
      scan,
      detectors,
      node("span", "intake-note", intake.note || "Raw rows parsed in memory, not stored.")
    );
    add(wrap, gate, scan);
    return wrap;
  }

  function renderDna(data) {
    var match = data.match || {};
    var evidence = match.evidence || {};
    var wrap = node("div", "viz viz-dna");
    var grid = node("div", "dna-grid");
    for (var index = 0; index < 60; index++) {
      var cell = node("div", "dna-cell");
      if (index % 7 === 0) cell.classList.add("is-rare");
      else if (index % 3 === 0) cell.classList.add("is-matched");
      else if (index % 11 === 0) cell.classList.add("is-dropped");
      grid.appendChild(cell);
    }
    var side = node("div", "dna-side");
    var meter = node("div", "dna-meter");
    var fill = node("span");
    fill.style.setProperty("--fill", fixed(num(match.match_score, 0) * 100, 1) + "%");
    meter.appendChild(fill);
    add(side, node("span", "viz-label", "Weighted overlap " + fixed(match.match_score, 3)), meter);
    var stats = node("div", "dna-stats");
    [
      ["Matched rows", fmt(match.matched_rows)],
      ["Matched cells", fmt(match.matched_cells)],
      ["Rare values shared", fmt(evidence.rare_shared_values)],
      ["Row coverage", pct(match.recall_vs_original)],
      ["Containment", pct(match.containment, 1)],
      ["Dropped columns", fmt((match.dropped_columns || []).length)]
    ].forEach(function (item) {
      var stat = node("div", "dna-stat");
      add(stat, node("strong", "", item[1]), node("span", "", item[0]));
      stats.appendChild(stat);
    });
    var matchedColumns = node("div", "dna-columns");
    (match.matched_columns || []).slice(0, 6).forEach(function (name) {
      matchedColumns.appendChild(node("span", "viz-chip is-accent", name));
    });
    var droppedColumns = node("div", "dna-columns");
    (match.dropped_columns || []).slice(0, 4).forEach(function (name) {
      droppedColumns.appendChild(node("span", "viz-chip is-warn", name));
    });
    if (!matchedColumns.children.length) {
      matchedColumns.appendChild(node("span", "intake-note", "No matched columns recorded."));
    }
    if (!droppedColumns.children.length) {
      droppedColumns.appendChild(node("span", "intake-note", "No dropped columns recorded."));
    }
    add(
      side,
      stats,
      node("span", "viz-label", "Matched columns"),
      matchedColumns,
      node("span", "viz-label", "Dropped columns"),
      droppedColumns,
      node("span", "intake-note", "Illustrative cell grid. Counts and the match score are from the stored match.")
    );
    add(wrap, grid, side);
    return wrap;
  }

  function renderTracking(data) {
    var tracking = data.tracking || {};
    var events = tracking.timeline || [];
    var canary = get(data, "match.canary", {});
    var dataset = data.dataset || {};
    var source = data.source_asset || {};
    var suspect = data.suspect_asset || {};
    var investigation = data.investigation || {};
    var download = events.filter(function (event) {
      return event.action === "FILE_DOWNLOADED";
    })[0];
    var share = events.filter(function (event) {
      return event.action === "EXTERNAL_SHARE";
    })[0];
    var upload = events.filter(function (event) {
      return event.action === "SUSPECT_UPLOAD";
    })[0];

    var wrap = node("div", "viz viz-track");
    var top = node("div", "track-top");
    var canaryCard = node("div", "track-canary");
    var canaryText = node("div");
    add(
      canaryText,
      node("strong", "", canary.found ? "Canary " + canary.canary_id + " found" : "Canary not found"),
      node("span", "", canary.found ? (canary.recipient || "recipient not recorded") + " · " + fmt(canary.matched_rows) + " rows" : "A canary can be stripped from a copy.")
    );
    add(canaryCard, node("i"), canaryText);

    var timeline = node("div", "track-timeline");
    events.slice(0, 4).forEach(function (event) {
      var row = node("div", "track-event");
      add(
        row,
        node("span", "", prettyAction(event.action)),
        node("span", "", event.actor_id + " → " + (event.destination || "investigation_intake")),
        node("span", "viz-chip", event.simulated ? "SIMULATED" : event.event_id)
      );
      timeline.appendChild(row);
    });
    if (!timeline.children.length) {
      timeline.appendChild(node("span", "intake-note", "No stored timeline events."));
    }
    add(top, canaryCard, timeline);

    var map = node("div", "lineage-map");
    map.innerHTML =
      '<svg viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">' +
      '<path class="lineage-edge is-simulated" d="M14,50 C24,40 30,32 40,25"></path>' +
      '<path class="lineage-edge is-simulated" d="M14,50 C24,60 30,68 40,75"></path>' +
      '<path class="lineage-edge is-match" d="M68,55 C58,45 50,32 40,25"></path>' +
      '<path class="lineage-edge is-simulated" d="M88,30 C82,38 76,46 68,55"></path>' +
      "</svg>";
    [
      {
        left: "14%",
        top: "50%",
        title: download ? download.actor_id : "USER-104",
        ref: download ? download.event_id : "EVENT",
        className: ""
      },
      {
        left: "40%",
        top: "25%",
        title: dataset.name || source.name || "customer_master_v1",
        ref: source.asset_id || "SL-9281",
        className: ""
      },
      {
        left: "40%",
        top: "75%",
        title: share ? share.destination : "external_domain.com",
        ref: share ? share.event_id : "EVENT",
        className: ""
      },
      {
        left: "68%",
        top: "55%",
        title: suspect.name || "clients_export_final",
        ref: data.match ? data.match.match_id || "MT-2001" : "MT-2001",
        className: "is-match"
      },
      {
        left: "88%",
        top: "30%",
        title: investigation.created_by || "USER-100",
        ref: upload ? upload.event_id : "EVENT",
        className: ""
      }
    ].forEach(function (item) {
      var entry = node("div", "lineage-node " + item.className);
      entry.style.left = item.left;
      entry.style.top = item.top;
      add(entry, node("strong", "", item.title), node("span", "", item.ref));
      map.appendChild(entry);
    });
    add(wrap, top, map);
    return wrap;
  }

  function renderBehaviour(data) {
    var behaviour = data.behaviour || {};
    var architecture = behaviour.architecture || [10, 8, 4, 10];
    var wrap = node("div", "viz viz-mlp");
    var svg = svgNode("svg", {
      viewBox: "0 0 360 300",
      class: "mlp-svg",
      role: "img",
      "aria-label": "Illustrative autoencoder with 10 inputs, 8 hidden, 4 hidden and 10 outputs"
    });
    var layerX = [34, 128, 222, 326];
    var layers = architecture.map(function (count, layerIndex) {
      return Array.from({ length: count }, function (_, nodeIndex) {
        return {
          x: layerX[layerIndex] || 34 + layerIndex * 95,
          y: 28 + (244 / Math.max(count - 1, 1)) * nodeIndex
        };
      });
    });
    for (var layerIndex = 0; layerIndex < layers.length - 1; layerIndex++) {
      var current = layers[layerIndex];
      var next = layers[layerIndex + 1];
      current.forEach(function (from, fromIndex) {
        next.forEach(function (to, toIndex) {
          var edge = svgNode("line", {
            x1: from.x,
            y1: from.y,
            x2: to.x,
            y2: to.y,
            class: "mlp-edge" + ((fromIndex + toIndex + layerIndex) % 17 === 0 ? " is-hot" : "")
          });
          svg.appendChild(edge);
        });
      });
    }
    layers.forEach(function (layer, index) {
      layer.forEach(function (point) {
        var className = "mlp-node";
        if (index === 0) className += " is-input";
        if (index === layers.length - 1) className += " is-output";
        svg.appendChild(
          svgNode("circle", {
            cx: point.x,
            cy: point.y,
            r: index === 0 || index === layers.length - 1 ? 4 : 3.2,
            class: className
          })
        );
      });
      var label = svgNode("text", {
        x: layerX[index] || 34 + index * 95,
        y: 12,
        "text-anchor": "middle",
        class: "mlp-node-label"
      });
      label.textContent = String(layer.length);
      svg.appendChild(label);
    });

    var side = node("div", "mlp-side");
    var error = node("div", "mlp-error");
    add(
      error,
      node("strong", "", fmt(behaviour.score)),
      node("span", "", "B score · percentile " + fmt(behaviour.percentile) + " · " + fmt(behaviour.samples) + " baseline events")
    );
    var features = node("div", "mlp-features");
    (behaviour.top_features || []).slice(0, 3).forEach(function (feature) {
      var row = node("div", "mlp-feature");
      add(row, node("span", "", prettyFeature(feature.feature)), node("b", "", Math.round(num(feature.contribution) * 100) + "%"));
      features.appendChild(row);
    });
    if (!features.children.length) {
      features.appendChild(node("span", "intake-note", "No baseline contributors recorded."));
    }
    add(
      side,
      node("span", "viz-label", "Reconstruction error"),
      error,
      node("span", "viz-label", "Top contributors"),
      features,
      node("span", "intake-note", behaviour.note || "Illustrative architecture. Score and features are computed by the model.")
    );
    add(wrap, svg, side);
    return wrap;
  }

  function renderRisk(data) {
    var risk = data.risk || {};
    var factors = risk.factors || {};
    var report = data.report || {};
    var wrap = node("div", "viz viz-risk");
    var left = node("div");
    var bars = node("div", "risk-factors");
    [
      ["S", "Sensitivity"],
      ["D", "Destination"],
      ["B", "Behaviour"],
      ["E", "Event sequence"]
    ].forEach(function (item) {
      var factor = factors[item[0]] || {};
      var row = node("div", "risk-factor");
      var bar = node("div", "risk-bar");
      var fill = node("i");
      fill.style.setProperty("--value", Math.max(0, Math.min(100, num(factor.score, 0))) + "%");
      bar.appendChild(fill);
      add(row, node("span", "", item[0]), bar, node("b", "", fmt(factor.score)));
      bars.appendChild(row);
    });
    var total = node("div", "risk-total");
    add(
      total,
      node("strong", "", fmt(risk.total)),
      node("span", "", (risk.band || "LOW") + " · S 0.35 / D 0.30 / B 0.20 / E 0.15")
    );
    add(left, bars, total);

    var reportCard = node("div", "risk-report");
    add(
      reportCard,
      node("strong", "", "Incident report · " + (report.provider || "SALUS_TEMPLATE")),
      node("p", "", report.summary || "No report summary is stored."),
      node("span", "viz-label", "Grounding references")
    );
    var refs = node("div", "risk-refs");
    (report.grounding_refs || []).slice(0, 7).forEach(function (ref) {
      refs.appendChild(node("span", "viz-chip", ref));
    });
    add(reportCard, refs, node("span", "viz-label", "Next actions"));
    var actions = node("div", "risk-actions");
    (report.recommended_actions || []).slice(0, 4).forEach(function (action, index) {
      var row = node("div", "risk-action");
      add(row, node("b", "", String(action.priority || index + 1)), node("span", "", action.action || ""));
      actions.appendChild(row);
    });
    if (!actions.children.length) {
      actions.appendChild(node("span", "intake-note", "No actions were generated."));
    }
    add(reportCard, actions);
    add(wrap, left, reportCard);
    return wrap;
  }

  var CHAPTERS = [
    {
      id: "dataset",
      duration: 7000,
      agents: ["identifier", "dna"],
      title: "The dataset",
      body: "The synthetic customer master is scanned column by column. Aadhaar is checked with Verhoeff, GSTIN with its own check digit, and every identity or contact field is labelled. Five canary rows are planted in the file.",
      hint: "Every number here is read from the demo evidence. Nothing is generated for the animation.",
      facts: datasetFacts,
      render: renderDataset
    },
    {
      id: "movement",
      duration: 8000,
      agents: ["simulator"],
      title: "The movement",
      body: "Priya downloads the file and shares it to an external domain four minutes later. Both events are stored with an event ID and labelled SIMULATED. The simulator writes events only; it never writes a match or a risk score.",
      hint: "SIMULATED is part of the evidence, not decoration.",
      facts: movementFacts,
      render: renderMovement
    },
    {
      id: "ghost",
      duration: 8000,
      agents: ["simulator"],
      title: "The ghost copy",
      body: "Outside the company the file is renamed, converted to CSV, stripped of its watermark, reduced to 300 rows, and loses three columns. Three canary rows survive. Row hashes would break here; cell hashes do not.",
      hint: "Dropped columns do not break the match because cell hashes ignore column names.",
      facts: ghostFacts,
      render: renderGhost
    },
    {
      id: "intake",
      duration: 8000,
      agents: ["intake", "identifier"],
      title: "Intake and identification",
      body: "The copy is uploaded. SALUS hashes the whole file, checks for a duplicate intake, parses it in memory, and runs the identification pass. Raw rows are not stored. Only hashes, labels, counts and metadata remain.",
      hint: "Uploading the same file twice returns the same investigation.",
      facts: intakeFacts,
      render: renderIntake
    },
    {
      id: "dna",
      duration: 9000,
      agents: ["dna"],
      title: "Data DNA",
      body: "Each cell is normalized, hashed with the organization salt, and weighted by rarity. The suspect keeps only 300 of 1,000 rows and 8 of 11 columns, but the rare shared values still produce a very high weighted overlap.",
      hint: "Illustrative cell grid. The counts, columns and match score are from the stored match.",
      facts: dnaFacts,
      render: renderDna
    },
    {
      id: "tracking",
      duration: 9000,
      agents: ["correlation", "dna"],
      title: "Canary and tracking",
      body: "The canary points to one issuance and one recipient. The timeline and lineage are built only from stored events and the stored match. A similarity score never invents a download or a share.",
      hint: "Every edge carries a stored EVENT or MATCH reference.",
      facts: trackingFacts,
      render: renderTracking
    },
    {
      id: "behaviour",
      duration: 9000,
      agents: ["behaviour"],
      title: "Neural behaviour model",
      body: "A per-user autoencoder learns normal behaviour from synthetic baseline events. The download's reconstruction error becomes the B score. The top contributors explain which inputs were unusual.",
      hint: "Illustrative network. The B score, percentile and top features are computed by the model.",
      facts: behaviourFacts,
      render: renderBehaviour
    },
    {
      id: "risk",
      duration: 9000,
      agents: ["risk", "report"],
      title: "Risk and report",
      body: "S, D, B and E are combined with fixed demo weights. The report explains what left, who moved it, and what to do now. The limits are part of the report, not a footnote.",
      hint: "Weights are demo policy, not validated standards. The language model only explains the evidence.",
      facts: riskFacts,
      render: renderRisk
    }
  ];

  function updateChapterLabels(data) {
    var labels = [
      fmt(get(data, "dataset.rows", 1000)) + " rows, " + fmt(get(data, "dataset.columns", 11)) + " columns",
      fmt(get(data, "movement.events", []).length) + " stored events",
      fmt(get(data, "ghost_copy.ghost_rows", 300)) + " rows, " + fmt(get(data, "ghost_copy.dropped_columns", []).length) + " columns dropped",
      get(data, "intake.investigation_id", "new investigation"),
      "Match " + fixed(get(data, "match.match_score", 0.999), 3),
      "Canary " + get(data, "match.canary.canary_id", "CN-007"),
      "B " + fmt(get(data, "behaviour.score", 0)),
      "Risk " + fmt(get(data, "risk.total", 0)) + " " + get(data, "risk.band", "LOW")
    ];
    els.chapters.forEach(function (button, index) {
      var small = button.querySelector("small");
      if (small) small.textContent = labels[index] || small.textContent;
    });
  }

  function renderChapter(index, announce) {
    var chapter = CHAPTERS[index];
    if (!chapter) return;
    state.index = index;
    cancelRafs();
    els.chapters.forEach(function (button, buttonIndex) {
      if (buttonIndex === index) button.setAttribute("aria-current", "step");
      else button.removeAttribute("aria-current");
    });
    els.step.textContent = String(index + 1).padStart(2, "0") + " / " + CHAPTERS.length;
    els.title.textContent = chapter.title;
    els.body.textContent = chapter.body;
    els.hint.textContent = chapter.hint;
    els.visual.innerHTML = "";
    if (state.data) {
      els.visual.appendChild(chapter.render(state.data));
      factList(chapter.facts(state.data));
      updateChapterLabels(state.data);
    } else {
      factList([]);
    }
    renderAgents(chapter.agents);
    var progress = Math.round(((index + 1) / CHAPTERS.length) * 1000) / 10;
    els.progressFill.style.width = progress + "%";
    els.progress.setAttribute("aria-valuenow", String(index + 1));
    if (announce && els.announcer) {
      els.announcer.textContent = chapter.title + ". " + chapter.body;
    }
  }

  function clearTimer() {
    if (state.timer) {
      window.clearTimeout(state.timer);
      state.timer = null;
    }
  }

  function scheduleNext() {
    clearTimer();
    if (!state.playing || reduceMotion) return;
    var chapter = CHAPTERS[state.index];
    var delay = chapter.duration / state.speed;
    state.timer = window.setTimeout(function () {
      if (!state.playing) return;
      if (state.index >= CHAPTERS.length - 1) {
        setPlaying(false);
        return;
      }
      renderChapter(state.index + 1, true);
      scheduleNext();
    }, delay);
  }

  function setPlaying(playing) {
    state.playing = playing;
    root.classList.toggle("is-paused", !playing);
    els.play.textContent = playing ? "Pause" : reduceMotion ? "Next chapter" : "Play investigation";
    els.play.setAttribute("aria-pressed", playing ? "true" : "false");
    clearTimer();
    if (playing) scheduleNext();
  }

  function go(index, announce) {
    var next = Math.max(0, Math.min(CHAPTERS.length - 1, index));
    renderChapter(next, announce);
    if (state.playing) scheduleNext();
  }

  els.chapters.forEach(function (button) {
    button.addEventListener("click", function () {
      go(num(button.getAttribute("data-sim-chapter"), 0), true);
    });
  });

  els.play.addEventListener("click", function () {
    if (reduceMotion) {
      go((state.index + 1) % CHAPTERS.length, true);
      return;
    }
    setPlaying(!state.playing);
  });

  els.restart.addEventListener("click", function () {
    setPlaying(false);
    go(0, true);
  });

  els.prev.addEventListener("click", function () {
    go(state.index - 1, true);
  });

  els.next.addEventListener("click", function () {
    go(state.index + 1, true);
  });

  els.speed.addEventListener("change", function () {
    state.speed = num(els.speed.value, 1) || 1;
    if (state.playing) scheduleNext();
  });

  document.addEventListener("keydown", function (event) {
    if (!root.contains(document.activeElement)) return;
    if (event.key === "ArrowRight") {
      event.preventDefault();
      go(state.index + 1, true);
    } else if (event.key === "ArrowLeft") {
      event.preventDefault();
      go(state.index - 1, true);
    } else if (event.key === "Home") {
      event.preventDefault();
      go(0, true);
    }
  });

  if ("IntersectionObserver" in window) {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting && state.playing) {
            setPlaying(false);
          }
        });
      },
      { threshold: 0.1 }
    );
    observer.observe(root);
  }

  if (reduceMotion) {
    els.play.textContent = "Next chapter";
  }

  els.play.disabled = true;
  renderChapter(0, false);
  loadStory()
    .then(function (result) {
      state.data = result.data;
      state.source = result.source;
      state.fetchedAt = result.fetchedAt || null;
      state.reason = result.reason || "";
      updateStatus();
      els.play.disabled = false;
      renderChapter(0, false);
    })
    .catch(function () {
      showUnavailable();
    });
})();
