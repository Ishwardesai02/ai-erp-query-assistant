"""
market_enricher.py
Orchestrates the "check DB → scrape if missing → fill table" flow.

Called before the LangChain pipeline when a question touches products.
"""

import json
import logging
from datetime import datetime, timedelta
from typing import Optional

from chatbot.db_utils import execute_query
from chatbot.scraper import scrape_product_market_data

logger = logging.getLogger(__name__)

# Re-scrape if data is older than this many days
RESCRAPE_AFTER_DAYS = 7


def _get_products_needing_enrichment(product_ids: list[int]) -> list[dict]:
    """
    Given a list of product_ids, return those that have no market data
    or stale market data (older than RESCRAPE_AFTER_DAYS).
    """
    if not product_ids:
        return []

    ids_str = ",".join(str(i) for i in product_ids)
    result  = execute_query(f"""
        SELECT
            p.product_id,
            p.name        AS product_name,
            p.sku,
            pc.name       AS category,
            pmi.info_id,
            pmi.scrape_status,
            pmi.last_scraped_at
        FROM products p
        LEFT JOIN product_categories pc  ON p.category_id = pc.category_id
        LEFT JOIN product_market_info pmi ON p.product_id  = pmi.product_id
        WHERE p.product_id IN ({ids_str})
    """)

    if result["error"]:
        logger.error(f"Error checking enrichment status: {result['error']}")
        return []

    stale_cutoff = datetime.now() - timedelta(days=RESCRAPE_AFTER_DAYS)
    needs_scrape = []

    for row in result["rows"]:
        if row["info_id"] is None:
            # No market data at all
            needs_scrape.append(row)
        elif row["scrape_status"] == "success" and row["last_scraped_at"]:
            if row["last_scraped_at"] < stale_cutoff:
                needs_scrape.append(row)
        elif row["scrape_status"] in ("failed", "pending"):
            needs_scrape.append(row)

    return needs_scrape


def _upsert_market_info(product_id: int, data: dict):
    """Insert or update market info for a product."""
    specs_json = json.dumps(data.get("specifications", {}))

    # Check if row exists
    check = execute_query(
        "SELECT info_id FROM product_market_info WHERE product_id = %s",
        (product_id,)
    )

    if check["rows"]:
        # UPDATE
        execute_query("""
            UPDATE product_market_info SET
                market_price_min = %s,
                market_price_max = %s,
                market_price_avg = %s,
                availability     = %s,
                supplier_name    = %s,
                supplier_url     = %s,
                product_url      = %s,
                specifications   = %s,
                scraped_from     = %s,
                scrape_status    = %s,
                scrape_error     = %s,
                last_scraped_at  = NOW()
            WHERE product_id = %s
        """, (
            data["market_price_min"], data["market_price_max"], data["market_price_avg"],
            data["availability"], data["supplier_name"], data["supplier_url"],
            data["product_url"], specs_json, data["scraped_from"],
            data["scrape_status"], data["scrape_error"], product_id
        ))
    else:
        # INSERT
        execute_query("""
            INSERT INTO product_market_info
                (product_id, market_price_min, market_price_max, market_price_avg,
                 availability, supplier_name, supplier_url, product_url,
                 specifications, scraped_from, scrape_status, scrape_error, last_scraped_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW())
        """, (
            product_id,
            data["market_price_min"], data["market_price_max"], data["market_price_avg"],
            data["availability"], data["supplier_name"], data["supplier_url"],
            data["product_url"], specs_json, data["scraped_from"],
            data["scrape_status"], data["scrape_error"]
        ))


def enrich_products_if_needed(product_ids: list[int]) -> dict:
    """
    For each product_id:
      1. Check if market data exists and is fresh
      2. If not → scrape → store in product_market_info
    
    Returns a summary dict:
    {
        "enriched": [list of product_ids that were scraped],
        "already_fresh": [list of product_ids that had fresh data],
        "failed": [list of product_ids where scraping failed],
    }
    """
    summary = {"enriched": [], "already_fresh": [], "failed": []}

    if not product_ids:
        return summary

    needs_scrape = _get_products_needing_enrichment(product_ids)
    fresh_ids    = set(product_ids) - {r["product_id"] for r in needs_scrape}
    summary["already_fresh"] = list(fresh_ids)

    for product in needs_scrape:
        pid  = product["product_id"]
        name = product["product_name"]
        sku  = product["sku"]
        cat  = product.get("category", "")

        logger.info(f"Enriching product {pid}: {name} ({sku})")

        try:
            market_data = scrape_product_market_data(name, sku, cat)
            _upsert_market_info(pid, market_data)

            if market_data["scrape_status"] == "success":
                summary["enriched"].append(pid)
                logger.info(f"  ✓ Enriched product {pid}")
            else:
                summary["failed"].append(pid)
                logger.warning(f"  ✗ Scraping failed for product {pid}: {market_data.get('scrape_error')}")

        except Exception as e:
            summary["failed"].append(pid)
            logger.error(f"  ✗ Exception enriching product {pid}: {e}")
            # Still store a failed record so we don't retry immediately
            _upsert_market_info(pid, {
                "market_price_min": None, "market_price_max": None, "market_price_avg": None,
                "availability": "Unknown", "supplier_name": "", "supplier_url": "",
                "product_url": "", "specifications": {}, "scraped_from": "",
                "scrape_status": "failed", "scrape_error": str(e),
            })

    return summary


def get_product_ids_from_question(question: str) -> list[int]:
    """
    Detect if a question is about specific products and return their IDs.
    Uses a broad search: looks for any product name/SKU mentioned OR
    returns all products if the question is category-level.
    """
    question_lower = question.lower()

    # Keywords that suggest product-level queries
    product_keywords = [
        "product", "item", "laptop", "server", "switch", "monitor", "keyboard",
        "chair", "desk", "paper", "sku", "price", "stock", "inventory",
        "availability", "market price", "cost", "purchase", "buy", "procurement",
        "sale", "sell", "order"
    ]

    if not any(kw in question_lower for kw in product_keywords):
        return []

    # Fetch all product names and check if any appear in the question
    result = execute_query("SELECT product_id, name, sku FROM products WHERE is_active = TRUE")
    if result["error"] or not result["rows"]:
        return []

    matched_ids = []
    for row in result["rows"]:
        name_lower = row["name"].lower()
        sku_lower  = row["sku"].lower()
        # Partial match on any word of the product name
        for word in name_lower.split():
            if len(word) > 3 and word in question_lower:
                matched_ids.append(row["product_id"])
                break
        if row["product_id"] not in matched_ids and sku_lower in question_lower:
            matched_ids.append(row["product_id"])

    # If question is broadly about products/prices but no specific match,
    # return IDs for the relevant category
    if not matched_ids:
        category_map = {
            "laptop": ["LAP"], "server": ["SRV"], "network": ["NET"],
            "peripheral": ["PER"], "office": ["OFF"], "furniture": ["FRN"],
        }
        for kw, sku_prefixes in category_map.items():
            if kw in question_lower:
                for row in result["rows"]:
                    if any(row["sku"].startswith(p) for p in sku_prefixes):
                        matched_ids.append(row["product_id"])

    return list(set(matched_ids))
