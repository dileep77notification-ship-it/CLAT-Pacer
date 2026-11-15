"""
Cross-device Playwright test for CLAT Daily Sprint at localhost:3000
Devices: Desktop Chrome, Desktop Safari, iPhone 15, Pixel 7
Checks: page load, navigation, screenshots, console errors
"""

import os
import sys
import json

# Force UTF-8 output on Windows so unicode symbols print correctly
if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

from playwright.sync_api import sync_playwright, ConsoleMessage

BASE_URL = "http://localhost:3000"
SCREENSHOT_DIR = "test_screenshots"

DEVICES = [
    {
        "name": "Desktop Chrome",
        "browser": "chromium",
        "viewport": {"width": 1280, "height": 800},
        "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "is_mobile": False,
    },
    {
        "name": "Desktop Safari",
        "browser": "webkit",
        "viewport": {"width": 1280, "height": 800},
        "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15",
        "is_mobile": False,
    },
    {
        "name": "iPhone 15",
        "browser": "webkit",
        "viewport": {"width": 393, "height": 852},
        "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1",
        "is_mobile": True,
        "device_scale_factor": 3,
    },
    {
        "name": "Pixel 7",
        "browser": "chromium",
        "viewport": {"width": 412, "height": 915},
        "user_agent": "Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.82 Mobile Safari/537.36",
        "is_mobile": True,
        "device_scale_factor": 2.625,
    },
]


def slug(name: str) -> str:
    return name.lower().replace(" ", "_")


def collect_console(msgs: list, msg: ConsoleMessage):
    msgs.append({"type": msg.type, "text": msg.text})


def goto_home(page):
    """Navigate to home and wait for Flutter to boot. Never waits for networkidle
    because Flutter/CanvasKit polls continuously and never reaches it."""
    page.goto(BASE_URL, timeout=20000, wait_until="load")
    page.wait_for_timeout(3000)  # give Flutter time to initialise and paint


def detect_renderer(page) -> str:
    try:
        if page.locator("flt-text").count() > 0:
            return "HTML"
        if page.locator("canvas").count() > 0:
            return "CanvasKit"
        return "Unknown"
    except Exception:
        return "Unknown"


def snap(page, device_name: str, label: str, screenshots_taken: list, full_page=True) -> str:
    path = os.path.join(SCREENSHOT_DIR, f"{slug(device_name)}_{label}.png")
    # full_page with high DPI (mobile 3x) can exceed 32767px limit — use viewport only
    vp = page.viewport_size or {}
    is_high_dpi_mobile = vp.get("width", 1280) < 600
    page.screenshot(path=path, full_page=(full_page and not is_high_dpi_mobile))
    screenshots_taken.append(path)
    return path


def try_click(page, selectors: list, fallback_coords=None, vp=None) -> bool:
    """Try a list of selectors, then optionally a coordinate fallback.
    Returns True if any click was attempted without raising."""
    for strategy, value in selectors:
        try:
            if strategy == "role":
                role, name = value
                loc = page.get_by_role(role, name=name)
                if loc.count() > 0:
                    loc.first.click(timeout=3000)
                    page.wait_for_timeout(1500)
                    return True
            elif strategy == "text":
                loc = page.get_by_text(value, exact=False)
                if loc.count() > 0:
                    loc.first.click(timeout=3000)
                    page.wait_for_timeout(1500)
                    return True
            elif strategy == "css":
                loc = page.locator(value)
                if loc.count() > 0:
                    loc.first.click(timeout=3000)
                    page.wait_for_timeout(1500)
                    return True
        except Exception:
            continue

    if fallback_coords and vp:
        x = int(vp["width"] * fallback_coords[0])
        y = int(vp["height"] * fallback_coords[1])
        try:
            page.mouse.click(x, y)
            page.wait_for_timeout(1500)
            return True
        except Exception:
            pass
    return False


def try_navigate(page, device_name: str, screenshots_taken: list) -> list:
    vp = page.viewport_size
    is_mobile = vp["width"] < 600
    results = []

    def s(label): return snap(page, device_name, label, screenshots_taken)

    # ── 1. Home baseline ──────────────────────────────────────────────────
    goto_home(page)
    s("01_home")

    # ── 2. Settings ───────────────────────────────────────────────────────
    goto_home(page)
    clicked = try_click(page,
        [("role", ("button", "Settings")), ("text", "Settings"), ("css", "[aria-label='Settings']")],
        fallback_coords=(0.95, 0.05), vp=vp)
    s("02_settings")
    results.append({"nav": "Settings", "clicked": clicked})

    # ── 3. Daily Sprint CTA ───────────────────────────────────────────────
    goto_home(page)
    # On mobile this button sits further down (stats stack above it)
    y = 0.60 if is_mobile else 0.47
    clicked = try_click(page,
        [("role", ("button", "Sprint")), ("text", "Today's Sprint"), ("text", "Daily Sprint"), ("text", "Start Sprint")],
        fallback_coords=(0.5, y), vp=vp)
    s("03_daily_sprint")
    results.append({"nav": "Daily Sprint", "clicked": clicked})

    # ── 4. Full Mock CTA ──────────────────────────────────────────────────
    goto_home(page)
    y = 0.72 if is_mobile else 0.58
    clicked = try_click(page,
        [("role", ("button", "Mock")), ("text", "Full Mock"), ("text", "Mock Test")],
        fallback_coords=(0.5, y), vp=vp)
    s("04_full_mock")
    results.append({"nav": "Full Mock Test", "clicked": clicked})

    # ── 5. Practice grid — Legal Reasoning ───────────────────────────────
    goto_home(page)
    # Scroll down to the practice section grid
    page.evaluate("window.scrollTo(0, 9999)")
    page.wait_for_timeout(600)
    s("05_practice_grid")
    clicked = try_click(page,
        [("role", ("button", "Legal")), ("text", "Legal Reasoning")],
        fallback_coords=(0.25 if is_mobile else 0.22, 0.78), vp=vp)
    s("06_legal_reasoning")
    results.append({"nav": "Legal Reasoning tile", "clicked": clicked})

    # ── 6. Practice grid — Brain Gym ─────────────────────────────────────
    goto_home(page)
    page.evaluate("window.scrollTo(0, 9999)")
    page.wait_for_timeout(600)
    clicked = try_click(page,
        [("role", ("button", "Brain Gym")), ("text", "Brain Gym")],
        fallback_coords=(0.75 if is_mobile else 0.78, 0.90), vp=vp)
    s("07_brain_gym")
    results.append({"nav": "Brain Gym tile", "clicked": clicked})

    # ── 7. Final full-page home capture ───────────────────────────────────
    goto_home(page)
    page.evaluate("window.scrollTo(0, 0)")
    page.wait_for_timeout(400)
    s("08_home_full")

    return results


def test_device(playwright, device_cfg: dict) -> dict:
    name = device_cfg["name"]
    print(f"\n{'='*60}")
    print(f"  Testing: {name}")
    print(f"{'='*60}")

    console_msgs = []
    screenshots_taken = []

    browser_type = getattr(playwright, device_cfg["browser"])
    browser = browser_type.launch(headless=True)

    ctx_opts = {
        "viewport": device_cfg["viewport"],
        "user_agent": device_cfg["user_agent"],
        "is_mobile": device_cfg.get("is_mobile", False),
        "device_scale_factor": device_cfg.get("device_scale_factor", 1),
    }
    context = browser.new_context(**ctx_opts)
    page = context.new_page()
    page.on("console", lambda msg: collect_console(console_msgs, msg))

    # ── Page load ─────────────────────────────────────────────────────────
    load_ok = False
    load_error = None
    http_status = "?"
    try:
        response = page.goto(BASE_URL, timeout=20000, wait_until="load")
        page.wait_for_timeout(3000)
        if response:
            http_status = response.status
            load_ok = response.status < 400
        else:
            http_status = "No response"
    except Exception as e:
        load_error = str(e)
        http_status = "ERROR"

    print(f"  Load: {'OK' if load_ok else 'FAILED'} (HTTP {http_status})")

    renderer = detect_renderer(page)
    print(f"  Flutter renderer: {renderer}")

    # DOM text check — only works with HTML renderer
    try:
        body_text = page.evaluate("document.body.innerText")
        has_dom_text = len(body_text.strip()) > 50
    except Exception:
        has_dom_text = False
    print(f"  DOM text accessible: {has_dom_text}")

    snap(page, name, "00_initial", screenshots_taken)

    # ── Navigation checks ─────────────────────────────────────────────────
    nav_results = []
    if load_ok:
        try:
            nav_results = try_navigate(page, name, screenshots_taken)
            for r in nav_results:
                icon = "✓" if r["clicked"] else "~"
                print(f"  [{icon}] Nav: {r['nav']}")
        except Exception as e:
            print(f"  Navigation failed with exception: {e}")

    # ── Console error filtering ───────────────────────────────────────────
    # Skip common benign Flutter/browser noise
    SKIP_PATTERNS = [
        "favicon", "net::ERR_ABORTED", "ERR_EMPTY_RESPONSE",
        "Failed to load resource", "Unrecognized feature",
        "Service worker", "service-worker",
    ]
    real_errors = [
        m for m in console_msgs
        if m["type"] == "error"
        and not any(p.lower() in m["text"].lower() for p in SKIP_PATTERNS)
    ]
    warnings = [m for m in console_msgs if m["type"] == "warning"]

    print(f"  Console errors: {len(real_errors)} | warnings: {len(warnings)} | total msgs: {len(console_msgs)}")

    browser.close()

    return {
        "device": name,
        "browser_engine": device_cfg["browser"],
        "viewport": device_cfg["viewport"],
        "renderer": renderer,
        "dom_text_accessible": has_dom_text,
        "load_ok": load_ok,
        "load_error": load_error,
        "http_status": http_status,
        "screenshots": screenshots_taken,
        "nav_results": nav_results,
        "console_errors": real_errors,
        "console_warnings": warnings[:10],
        "total_console_msgs": len(console_msgs),
    }


def print_report(all_results):
    print("\n")
    print("=" * 60)
    print("  CROSS-DEVICE TEST REPORT")
    print("=" * 60)

    for r in all_results:
        load_icon = "✓" if r["load_ok"] else "✗"
        print(f"\n[{load_icon}] {r['device']}  ({r['viewport']['width']}×{r['viewport']['height']})")
        print(f"     Engine  : {r['browser_engine']} | Renderer: {r['renderer']}")
        print(f"     HTTP    : {r['http_status']} | DOM text: {r['dom_text_accessible']}")
        if r["load_error"]:
            print(f"     Error   : {r['load_error']}")

        if r["nav_results"]:
            print("     Navigation:")
            for n in r["nav_results"]:
                icon = "✓" if n["clicked"] else "~"
                print(f"       [{icon}] {n['nav']}")

        if r["console_errors"]:
            print(f"     Console ERRORS ({len(r['console_errors'])}):")
            for e in r["console_errors"][:5]:
                print(f"       ✗ {e['text'][:140]}")
        else:
            print("     Console errors : none")

        if r["console_warnings"]:
            print(f"     Warnings (first 3 of {len(r['console_warnings'])}):")
            for w in r["console_warnings"][:3]:
                print(f"       ⚠ {w['text'][:140]}")

        print(f"     Screenshots ({len(r['screenshots'])}):")
        for s in r["screenshots"]:
            print(f"       → {s}")


def main():
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    all_results = []

    with sync_playwright() as pw:
        for device in DEVICES:
            result = test_device(pw, device)
            all_results.append(result)

    print_report(all_results)

    summary_path = os.path.join(SCREENSHOT_DIR, "test_summary.json")
    with open(summary_path, "w") as f:
        json.dump(all_results, f, indent=2)
    print(f"\n  Full summary: {summary_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()
