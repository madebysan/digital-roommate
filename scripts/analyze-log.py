#!/usr/bin/env python3
"""
Analyze Digital Roommate activity logs for settings and persona compliance.

Usage:
    python3 scripts/analyze-log.py <activity-log.json> [--config <test-config.json>]

The script reads the activity log and checks:
1. Settings compliance: Are modules respecting enabled engines, duration caps, etc.?
2. Persona compliance: Do queries/searches match the test persona's interests?
"""

import json
import sys
import os
from collections import Counter, defaultdict


# Zephyr Moonwhale's distinctive keywords — if these appear, persona is being followed
PERSONA_KEYWORDS = {
    "search": [
        "underwater basket weaving", "subaquatic reed braiding", "deep sea macrame",
        "aquatic fiber arts", "sparkle horn polish", "unicorn horn buffing",
        "iridescent horn wax", "enchanted horn sealant", "tesseract clay throwing",
        "four-dimensional pottery", "hypercube ceramics", "quantum clay sculpting",
    ],
    "shopping": [
        "holographic yarn", "artisanal moon dust", "bioluminescent terrarium kit",
        "prismatic weaving needles", "competitive ferret racing harness",
        "ferret agility tunnel", "premium ferret racing track",
        "ferret victory celebration banner",
    ],
    "video": [
        "competitive ferret racing", "ferret agility training",
        "world ferret racing finals", "racing ferret",
        "ASMR blacksmithing", "relaxing forge sounds",
        "medieval sword making ASMR", "soothing anvil strikes",
        "how to knit with spaghetti", "pasta fiber arts",
        "spaghetti scarf knitting", "noodle crafts",
    ],
}


class Check:
    """A single compliance check with pass/fail result."""
    def __init__(self, name, passed, details=""):
        self.name = name
        self.passed = passed
        self.details = details

    def __str__(self):
        status = "PASS" if self.passed else "FAIL"
        line = f"  [{status}] {self.name}"
        if self.details:
            line += f"\n         {self.details}"
        return line


def load_log(path):
    """Load and parse the activity log JSON."""
    with open(path, "r") as f:
        return json.load(f)


def load_config(path):
    """Load and parse a test config JSON."""
    with open(path, "r") as f:
        return json.load(f)


def entries_by_module(entries):
    """Group log entries by module."""
    grouped = defaultdict(list)
    for e in entries:
        grouped[e["module"]].append(e)
    return grouped


def check_search_engines(entries, config):
    """Verify only enabled search engines are used."""
    checks = []
    settings = config["settings"]

    enabled = set()
    if settings.get("searchGoogle", True):
        enabled.add("Google")
    if settings.get("searchBing", True):
        enabled.add("Bing")
    if settings.get("searchDuckDuckGo", True):
        enabled.add("DuckDuckGo")

    used_engines = set()
    for e in entries:
        if e["action"] == "Search query" and e.get("metadata", {}).get("engine"):
            used_engines.add(e["metadata"]["engine"])

    if not used_engines:
        checks.append(Check("Search engines used", True, "No search queries logged (module may not have run)"))
        return checks

    unexpected = used_engines - enabled
    checks.append(Check(
        "Search engines: only enabled engines used",
        len(unexpected) == 0,
        f"Enabled: {enabled}, Used: {used_engines}" + (f", UNEXPECTED: {unexpected}" if unexpected else "")
    ))

    return checks


def check_burst_mode(entries, config):
    """Check if burst mode generates follow-up queries."""
    checks = []
    settings = config["settings"]

    if not settings.get("searchEnabled", False):
        checks.append(Check("Burst mode", True, "Search module disabled — skipped"))
        return checks

    if not settings.get("searchBurstMode", False):
        checks.append(Check("Burst mode", True, "Burst mode disabled in config — skipped"))
        return checks

    burst_sessions = [
        e for e in entries
        if e["action"] == "Search query" and e.get("metadata", {}).get("sessionType", "").startswith("burst")
    ]

    checks.append(Check(
        "Burst mode: burst sessions logged",
        len(burst_sessions) > 0,
        f"Found {len(burst_sessions)} burst query entries"
    ))

    return checks


def check_click_through(entries, config):
    """Check if click-through generates result clicks."""
    checks = []
    settings = config["settings"]

    if not settings.get("searchEnabled", False):
        checks.append(Check("Click-through", True, "Search module disabled — skipped"))
        return checks

    if not settings.get("searchClickThrough", False):
        checks.append(Check("Click-through", True, "Click-through disabled in config — skipped"))
        return checks

    clicks = [e for e in entries if e["action"] == "Clicked search result"]
    queries = [e for e in entries if e["action"] == "Search query"]

    if queries:
        click_rate = len(clicks) / len(queries) * 100
        checks.append(Check(
            "Click-through: result clicks logged",
            len(clicks) > 0,
            f"{len(clicks)} clicks from {len(queries)} queries ({click_rate:.0f}% click rate)"
        ))
    else:
        checks.append(Check("Click-through", True, "No search queries to check against"))

    return checks


def check_shopping_products(entries, config):
    """Check shopping products per session respects settings."""
    checks = []
    settings = config["settings"]
    max_products = settings.get("shoppingProductsPerSession", 2)

    # Count product views per search-based session only.
    # Each "Session started" from the shopping module marks a new session boundary.
    # We only count products in sessions that use "Amazon search" (the search path).
    # "Direct product page" sessions always have exactly 1 product and don't
    # need to respect the per-session limit setting.
    sessions = []
    current_products = 0
    in_search_session = False

    for e in entries:
        if e.get("module") != "shopping":
            continue
        if e["action"] == "Session started":
            # New session boundary — close any open session
            if in_search_session:
                sessions.append(current_products)
            current_products = 0
            in_search_session = False
        elif e["action"] == "Amazon search":
            # This session uses the search path — track products
            in_search_session = True
            current_products = 0
        elif e["action"] == "Direct product page":
            # Direct path — not counted against per-session limit
            in_search_session = False
        elif e["action"] == "Viewing product" and in_search_session:
            current_products += 1
        elif e["action"] == "Session complete":
            if in_search_session:
                sessions.append(current_products)
            current_products = 0
            in_search_session = False

    if in_search_session:
        sessions.append(current_products)

    if not sessions:
        checks.append(Check("Shopping products per session", True, "No shopping sessions logged"))
        return checks

    violations = [s for s in sessions if s > max_products]
    checks.append(Check(
        f"Shopping: products per session <= {max_products}",
        len(violations) == 0,
        f"Sessions: {sessions}, Max setting: {max_products}" + (f", VIOLATIONS: {violations}" if violations else "")
    ))

    return checks


def check_video_duration(entries, config):
    """Check video watch duration respects max cap."""
    checks = []
    settings = config["settings"]
    max_watch_min = settings.get("videoMaxWatchMinutes", 10)
    max_watch_sec = max_watch_min * 60

    watch_entries = [
        e for e in entries
        if e["action"] == "Watching video" and e.get("metadata", {}).get("watchDurationSec")
    ]

    if not watch_entries:
        checks.append(Check("Video duration cap", True, "No video watch entries logged"))
        return checks

    durations = []
    violations = []
    for e in watch_entries:
        dur = int(e["metadata"]["watchDurationSec"])
        durations.append(dur)
        if dur > max_watch_sec:
            violations.append(dur)

    checks.append(Check(
        f"Video: watch duration <= {max_watch_min}min ({max_watch_sec}s)",
        len(violations) == 0,
        f"Durations (sec): {durations}" + (f", OVER CAP: {violations}" if violations else "")
    ))

    return checks


def check_news_articles(entries, config):
    """Check news articles per session respects settings."""
    checks = []
    settings = config["settings"]
    max_articles = settings.get("newsArticlesPerSession", 3)

    # Count articles per site visit
    sessions = []
    current_articles = 0
    in_session = False

    for e in entries:
        if e["action"] == "Visiting news site":
            if in_session:
                sessions.append(current_articles)
            current_articles = 0
            in_session = True
        elif e["action"] == "Reading article" and in_session:
            current_articles += 1

    if in_session:
        sessions.append(current_articles)

    if not sessions:
        checks.append(Check("News articles per session", True, "No news sessions logged"))
        return checks

    violations = [s for s in sessions if s > max_articles]
    checks.append(Check(
        f"News: articles per session <= {max_articles}",
        len(violations) == 0,
        f"Sessions: {sessions}, Max setting: {max_articles}" + (f", VIOLATIONS: {violations}" if violations else "")
    ))

    return checks


def check_blocked_domains(entries, config):
    """Verify blocked domains are never visited."""
    checks = []
    settings = config["settings"]
    blocked = [d.lower().strip() for d in settings.get("blockedDomains", [])]

    if not blocked:
        checks.append(Check("Blocked domains", True, "No blocked domains configured"))
        return checks

    violations = []
    for e in entries:
        meta = e.get("metadata", {})
        for key in ["url", "clickedUrl", "articleUrl", "siteUrl"]:
            url = meta.get(key, "").lower()
            for domain in blocked:
                if domain in url:
                    violations.append(f"{e['action']}: {url} (blocked: {domain})")

    checks.append(Check(
        f"Blocked domains: {blocked} never visited",
        len(violations) == 0,
        f"Checked {len(entries)} entries" + (f", VIOLATIONS: {violations}" if violations else "")
    ))

    return checks


def check_persona_keywords(entries, module_id, keywords):
    """Check if module activity contains persona-specific keywords."""
    checks = []

    # Collect all text content from the module's entries
    text_content = []
    for e in entries:
        if e["module"] != module_id:
            continue
        meta = e.get("metadata", {})
        for key in ["query", "searchTerm", "videoTitle", "productTitle", "topic", "sourceDetail"]:
            if key in meta:
                text_content.append(meta[key].lower())

    if not text_content:
        checks.append(Check(f"Persona ({module_id}): keyword match", True, "No content to check"))
        return checks

    # Check how many entries contain at least one persona keyword
    matched = 0
    total = len(text_content)
    matched_keywords = set()

    for text in text_content:
        for kw in keywords:
            if kw.lower() in text:
                matched += 1
                matched_keywords.add(kw)
                break

    match_rate = (matched / total * 100) if total > 0 else 0

    checks.append(Check(
        f"Persona ({module_id}): keyword match rate >= 80%",
        match_rate >= 80,
        f"{matched}/{total} entries matched ({match_rate:.0f}%), keywords found: {matched_keywords}"
    ))

    return checks


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze-log.py <activity-log.json> [--config <test-config.json>]")
        sys.exit(1)

    log_path = sys.argv[1]
    config_path = None

    if "--config" in sys.argv:
        idx = sys.argv.index("--config")
        if idx + 1 < len(sys.argv):
            config_path = sys.argv[idx + 1]

    # Load the log
    if not os.path.exists(log_path):
        print(f"[ERROR] Log file not found: {log_path}")
        sys.exit(1)

    entries = load_log(log_path)
    print(f"=== Digital Roommate Log Analysis ===")
    print(f"Log file: {log_path}")
    print(f"Total entries: {len(entries)}")
    print()

    # Load config if provided
    config = None
    if config_path:
        config = load_config(config_path)
        print(f"Config: {config_path}")
        print(f"Persona: {config['personaName']}")
        enabled_modules = []
        s = config["settings"]
        if s.get("searchEnabled"): enabled_modules.append("search")
        if s.get("shoppingEnabled"): enabled_modules.append("shopping")
        if s.get("videoEnabled"): enabled_modules.append("video")
        if s.get("newsEnabled"): enabled_modules.append("news")
        print(f"Enabled modules: {', '.join(enabled_modules)}")
        print()

    # Entry counts by module
    module_counts = Counter(e["module"] for e in entries)
    print("Entries by module:")
    for module, count in sorted(module_counts.items()):
        print(f"  {module}: {count}")
    print()

    # Action counts
    action_counts = Counter(e["action"] for e in entries)
    print("Actions:")
    for action, count in sorted(action_counts.items(), key=lambda x: -x[1]):
        print(f"  {action}: {count}")
    print()

    # Run compliance checks if config is provided
    all_checks = []

    if config:
        print("=== Settings Compliance ===")
        all_checks.extend(check_search_engines(entries, config))
        all_checks.extend(check_burst_mode(entries, config))
        all_checks.extend(check_click_through(entries, config))
        all_checks.extend(check_shopping_products(entries, config))
        all_checks.extend(check_video_duration(entries, config))
        all_checks.extend(check_news_articles(entries, config))
        all_checks.extend(check_blocked_domains(entries, config))

        for check in all_checks:
            print(str(check))
        print()

        print("=== Persona Compliance ===")
        persona_checks = []

        if config["settings"].get("searchEnabled"):
            persona_checks.extend(check_persona_keywords(entries, "search", PERSONA_KEYWORDS["search"]))
        if config["settings"].get("shoppingEnabled"):
            persona_checks.extend(check_persona_keywords(entries, "shopping", PERSONA_KEYWORDS["shopping"]))
        if config["settings"].get("videoEnabled"):
            persona_checks.extend(check_persona_keywords(entries, "video", PERSONA_KEYWORDS["video"]))

        all_checks.extend(persona_checks)
        for check in persona_checks:
            print(str(check))
        print()

    # Summary
    passed = sum(1 for c in all_checks if c.passed)
    total = len(all_checks)
    print(f"=== Summary: {passed}/{total} checks passed ===")

    if passed < total:
        print("\nFailed checks:")
        for c in all_checks:
            if not c.passed:
                print(f"  - {c.name}: {c.details}")

    # Check for anomalies
    print("\n=== Anomalies ===")
    anomalies = []

    # Check for any error entries
    errors = [e for e in entries if "error" in e.get("metadata", {}) or "failed" in e["action"].lower()]
    if errors:
        anomalies.append(f"{len(errors)} error/failure entries found")
        for e in errors[:5]:
            anomalies.append(f"  {e['action']}: {e.get('metadata', {}).get('error', 'no details')}")

    # Check for unexpected modules
    expected_modules = {"Scheduler", "search", "shopping", "video", "news"}
    unexpected = set(module_counts.keys()) - expected_modules
    if unexpected:
        anomalies.append(f"Unexpected modules: {unexpected}")

    if anomalies:
        for a in anomalies:
            print(f"  {a}")
    else:
        print("  None found")

    print()
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
