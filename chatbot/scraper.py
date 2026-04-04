"""
scraper.py
Web scraper for product market data with anti-block bypass layers.

Layer 1: requests + rotating User-Agents + headers  (fast, most sites)
Layer 2: Random delays + retry with backoff          (rate-limit bypass)
Layer 3: Playwright headless browser                 (JS-heavy / bot-protected)
Layer 4: Graceful fallback with partial data         (when all layers fail)

Scraping targets (in order of attempt):
  1. Google Shopping (search result snippets)
  2. IndiaMART       (B2B pricing India)
  3. Amazon.in       (retail price + availability)
"""

import os
import re
import time
import random
import json
import logging
from datetime import datetime
from typing import Optional
from urllib.parse import quote_plus

import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv

load_dotenv(override=True)
logger = logging.getLogger(__name__)


# Rotating User-Agents pool

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36 Edg/123.0.0.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15",
]

def _random_headers(referer: str = "https://www.google.com") -> dict:
    return {
        "User-Agent":      random.choice(USER_AGENTS),
        "Accept":          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
        "Accept-Encoding": "gzip, deflate, br",
        "DNT":             "1",
        "Connection":      "keep-alive",
        "Upgrade-Insecure-Requests": "1",
        "Referer":         referer,
        "Cache-Control":   "no-cache",
        "Pragma":          "no-cache",
        "Sec-Fetch-Dest":  "document",
        "Sec-Fetch-Mode":  "navigate",
        "Sec-Fetch-Site":  "cross-site",
    }

def _random_delay(min_s: float = 2.0, max_s: float = 5.0):
    """Human-like delay between requests."""
    time.sleep(random.uniform(min_s, max_s))

def _safe_get(url: str, retries: int = 3, timeout: int = 12) -> Optional[requests.Response]:
    """
    GET with rotating UA, random delay, and retry-with-backoff.
    Returns None if all attempts fail.
    """
    for attempt in range(retries):
        try:
            _random_delay(1.5 + attempt, 3.0 + attempt * 2)
            session = requests.Session()
            session.headers.update(_random_headers(referer=url))
            resp = session.get(url, timeout=timeout, allow_redirects=True)
            if resp.status_code == 200:
                return resp
            elif resp.status_code == 429:
                logger.warning(f"Rate limited on {url}, waiting {10 * (attempt+1)}s")
                time.sleep(10 * (attempt + 1))
            elif resp.status_code in (403, 406, 503):
                logger.warning(f"Blocked ({resp.status_code}) on {url}")
                return None
        except requests.exceptions.RequestException as e:
            logger.warning(f"Request attempt {attempt+1} failed: {e}")
    return None



# Layer 3: Playwright fallback

def _playwright_get(url: str) -> Optional[str]:
    """
    Use Playwright headless Chromium for JS-heavy or bot-protected pages.
    Returns page HTML string or None.
    """
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            browser = p.chromium.launch(
                headless=True,
                args=["--no-sandbox", "--disable-blink-features=AutomationControlled"]
            )
            context = browser.new_context(
                user_agent=random.choice(USER_AGENTS),
                viewport={"width": 1366, "height": 768},
                locale="en-IN",
            )
            page = context.new_page()
            # Mask automation signals
            page.add_init_script("""
                Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
                window.chrome = { runtime: {} };
            """)
            page.goto(url, wait_until="domcontentloaded", timeout=20000)
            _random_delay(2, 4)
            html = page.content()
            browser.close()
            return html
    except ImportError:
        logger.warning("Playwright not installed. Run: pip install playwright && playwright install chromium")
        return None
    except Exception as e:
        logger.warning(f"Playwright failed for {url}: {e}")
        return None



# Price extraction helpers

def _extract_prices(text: str) -> list[float]:
    """Extract all price-like numbers from text (handles ₹, Rs., commas)."""
    text = text.replace(",", "")
    patterns = [
        r"₹\s*(\d+(?:\.\d+)?)",
        r"Rs\.?\s*(\d+(?:\.\d+)?)",
        r"INR\s*(\d+(?:\.\d+)?)",
        r"(\d{3,7}(?:\.\d{1,2})?)\s*(?:/-|/\-)",   # Indian price format
    ]
    prices = []
    for pat in patterns:
        for m in re.finditer(pat, text, re.IGNORECASE):
            val = float(m.group(1))
            if 10 < val < 10_000_000:   # sanity range
                prices.append(val)
    return prices


# Source 1: Google Shopping

def _scrape_google_shopping(product_name: str, sku: str) -> Optional[dict]:
    """Scrape Google Shopping for price range and availability."""
    query   = quote_plus(f"{product_name} {sku} price India buy")
    url     = f"https://www.google.com/search?q={query}&tbm=shop&gl=in&hl=en"
    html    = None

    resp = _safe_get(url)
    if resp:
        html = resp.text
    else:
        logger.info("requests blocked by Google, trying Playwright...")
        html = _playwright_get(url)

    if not html:
        return None

    soup   = BeautifulSoup(html, "html.parser")
    prices = []
    items  = []

    # Google Shopping result cards
    for card in soup.select("div.sh-dgr__grid-result, div[data-sh-pr], .mnIHsc"):
        price_el = card.select_one(".a8Pemb, .kHxwFf, span[data-price]")
        name_el  = card.select_one("h3, .tAxDx, .sh-np__click-target")
        seller_el= card.select_one(".aULzUe, .IuHnof")

        price_text = price_el.get_text() if price_el else ""
        found      = _extract_prices(price_text)
        if found:
            prices.extend(found)
            items.append({
                "name":   name_el.get_text(strip=True) if name_el else product_name,
                "price":  found[0],
                "seller": seller_el.get_text(strip=True) if seller_el else "",
            })

    # Also try generic price mentions in page
    if not prices:
        prices = _extract_prices(soup.get_text())

    if not prices:
        return None

    prices.sort()
    return {
        "source":      "Google Shopping",
        "url":         url,
        "price_min":   round(min(prices), 2),
        "price_max":   round(max(prices), 2),
        "price_avg":   round(sum(prices) / len(prices), 2),
        "availability":"In Stock" if items else "Unknown",
        "supplier":    items[0]["seller"] if items else "",
        "items":       items[:5],
    }



# Source 2: IndiaMART

def _scrape_indiamart(product_name: str, sku: str) -> Optional[dict]:
    """Scrape IndiaMART for B2B pricing."""
    query = quote_plus(f"{product_name} {sku}")
    url   = f"https://www.indiamart.com/search.mp?ss={query}"

    resp  = _safe_get(url, retries=2)
    if not resp:
        html = _playwright_get(url)
    else:
        html = resp.text

    if not html:
        return None

    soup   = BeautifulSoup(html, "html.parser")
    prices = []
    supplier = ""

    # IndiaMART product listing cards
    for card in soup.select(".product-card, .lst-card, div[data-catlog-id]"):
        price_el    = card.select_one(".price, .rupee, span[data-field='price']")
        supplier_el = card.select_one(".companyname, .company, .seller")
        if price_el:
            found = _extract_prices(price_el.get_text())
            prices.extend(found)
        if not supplier and supplier_el:
            supplier = supplier_el.get_text(strip=True)

    if not prices:
        prices = _extract_prices(soup.get_text())

    if not prices:
        return None

    prices.sort()
    return {
        "source":       "IndiaMART",
        "url":          url,
        "price_min":    round(min(prices), 2),
        "price_max":    round(max(prices), 2),
        "price_avg":    round(sum(prices) / len(prices), 2),
        "availability": "Available",
        "supplier":     supplier,
    }



# Source 3: Amazon India

def _scrape_amazon(product_name: str, sku: str) -> Optional[dict]:
    """Scrape Amazon.in for retail price and availability."""
    query   = quote_plus(f"{product_name} {sku}")
    url     = f"https://www.amazon.in/s?k={query}"

    resp    = _safe_get(url, retries=2)
    if not resp:
        html = _playwright_get(url)
    else:
        html = resp.text

    if not html:
        return None

    soup    = BeautifulSoup(html, "html.parser")
    prices  = []

    # Amazon search result prices
    for item in soup.select("div[data-component-type='s-search-result']"):
        price_whole = item.select_one(".a-price-whole")
        if price_whole:
            price_text = price_whole.get_text().replace(",", "").strip().rstrip(".")
            try:
                prices.append(float(price_text))
            except ValueError:
                pass

    # Check availability keywords
    page_text    = soup.get_text()
    availability = "Unknown"
    if "In Stock" in page_text or "Add to Cart" in page_text:
        availability = "In Stock"
    elif "Out of Stock" in page_text or "Currently unavailable" in page_text:
        availability = "Out of Stock"

    if not prices:
        return None

    prices.sort()
    return {
        "source":       "Amazon.in",
        "url":          url,
        "price_min":    round(min(prices), 2),
        "price_max":    round(max(prices), 2),
        "price_avg":    round(sum(prices) / len(prices), 2),
        "availability": availability,
        "supplier":     "Amazon.in",
    }



# Main scrape function — tries all sources

def scrape_product_market_data(product_name: str, sku: str, category: str = "") -> dict:
    """
    Scrape market data for a product from multiple sources.
    Returns a unified dict ready to INSERT into product_market_info.

    Result schema:
    {
        "market_price_min": float | None,
        "market_price_max": float | None,
        "market_price_avg": float | None,
        "availability":     str,
        "supplier_name":    str,
        "supplier_url":     str,
        "product_url":      str,
        "specifications":   dict,
        "scraped_from":     str,
        "scrape_status":    "success" | "failed" | "blocked",
        "scrape_error":     str | None,
    }
    """
    logger.info(f"Scraping market data for: {product_name} (SKU: {sku})")

    result = {
        "market_price_min": None,
        "market_price_max": None,
        "market_price_avg": None,
        "availability":     "Unknown",
        "supplier_name":    "",
        "supplier_url":     "",
        "product_url":      "",
        "specifications":   {},
        "scraped_from":     "",
        "scrape_status":    "failed",
        "scrape_error":     None,
    }

    scrapers = [
        ("Google Shopping", _scrape_google_shopping),
        ("IndiaMART",       _scrape_indiamart),
        ("Amazon.in",       _scrape_amazon),
    ]

    for source_name, scraper_fn in scrapers:
        try:
            logger.info(f"  Trying {source_name}...")
            data = scraper_fn(product_name, sku)

            if data and data.get("price_min"):
                result.update({
                    "market_price_min": data["price_min"],
                    "market_price_max": data["price_max"],
                    "market_price_avg": data["price_avg"],
                    "availability":     data.get("availability", "Unknown"),
                    "supplier_name":    data.get("supplier", ""),
                    "supplier_url":     data.get("url", ""),
                    "product_url":      data.get("url", ""),
                    "scraped_from":     source_name,
                    "scrape_status":    "success",
                    "scrape_error":     None,
                    "specifications":   {"raw_items": data.get("items", [])},
                })
                logger.info(f"  ✓ Got data from {source_name}: ₹{data['price_min']} – ₹{data['price_max']}")
                return result

        except Exception as e:
            logger.warning(f"  ✗ {source_name} failed: {e}")
            result["scrape_error"] = str(e)
            continue

    # All sources failed
    result["scrape_status"] = "failed"
    result["scrape_error"]  = result.get("scrape_error") or "All scraping sources failed"
    logger.warning(f"  ✗ All sources failed for {product_name}")
    return result
