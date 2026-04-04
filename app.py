"""
app.py  (v2)
Flask application for the ERP AI Chatbot.
"""
import os
import json
from datetime import datetime
from flask import Flask, render_template, request, jsonify, session
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv(override=True)

from chatbot.chain import erp_chat_pipeline
from chatbot.db_utils import verify_tables

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "erp-chatbot-secret-2024")
CORS(app)


# ── Startup check ──────────────────────────────────────────────
def startup_check():
    print("\n" + "="*55)
    print("  ERP Chatbot v2 — Startup Check")
    print("="*55)
    check = verify_tables()
    if check.get("error"):
        print(f"  ✗ DB connection failed: {check['error']}")
        print("    → Check DB_HOST / DB_USER / DB_PASSWORD in .env")
    elif check["ok"]:
        print(f"  ✓ All {len(check['found'])} tables found. Database is ready.")
    else:
        print(f"  ✗ Missing tables: {', '.join(check['missing'])}")
        print("\n  → Run:  python setup_db.py   to create and seed the database.")
        if "product_market_info" in check["missing"]:
            print("  → Also run:  psql -U postgres -d erp_db -f db/migration_v2.sql")
    print("="*55 + "\n")

startup_check()


SAMPLE_QUESTIONS = [
    "Show me laptop prices — compare ERP price vs market price",
    "Which products are below reorder level?",
    "How many employees are in each department?",
    "Show me all pending sales orders with customer names",
    "What is the total revenue from delivered orders?",
    "List the top 5 highest paid employees",
    "Show unpaid invoices and their due dates",
    "What is the market availability of our servers?",
    "Show me all active CRM leads with estimated values",
    "Which customers have the highest credit limits?",
    "Show stock movement for laptops",
    "Compare our cost price vs market price for networking products",
]


# ── Routes ─────────────────────────────────────────────────────
@app.route("/")
def index():
    if "conversation" not in session:
        session["conversation"] = []
    return render_template("index.html", sample_questions=SAMPLE_QUESTIONS)


@app.route("/api/chat", methods=["POST"])
def chat():
    data     = request.get_json()
    question = data.get("question", "").strip()
    if not question:
        return jsonify({"error": "No question provided"}), 400

    if "conversation" not in session:
        session["conversation"] = []

    result = erp_chat_pipeline(question, session["conversation"])

    session["conversation"].append({"role": "user",      "content": question})
    session["conversation"].append({"role": "assistant", "content": result["answer"]})
    session["conversation"] = session["conversation"][-20:]
    session.modified = True

    enrichment = result.get("enrichment", {})
    enrich_note = ""
    if enrichment.get("enriched"):
        enrich_note = f"🔍 Scraped fresh market data for {len(enrichment['enriched'])} product(s)."
    elif enrichment.get("failed"):
        enrich_note = f"⚠ Could not scrape market data for {len(enrichment['failed'])} product(s) (site blocked or offline)."

    return jsonify({
        "question":       question,
        "answer":         result["answer"],
        "sql":            result.get("sql", ""),
        "rowcount":       result.get("result", {}).get("rowcount", 0),
        "columns":        result.get("result", {}).get("columns", []),
        "rows":           result.get("result", {}).get("rows", [])[:20],
        "error":          result.get("error"),
        "timestamp":      datetime.now().strftime("%H:%M"),
        # v2 additions
        "reference_rows": result.get("reference_rows", []),
        "reference_cols": result.get("reference_cols", []),
        "enrich_note":    enrich_note,
    })


@app.route("/api/clear", methods=["POST"])
def clear_conversation():
    session["conversation"] = []
    session.modified = True
    return jsonify({"status": "cleared"})


@app.route("/api/schema", methods=["GET"])
def get_schema():
    from chatbot.db_utils import get_schema_description
    return jsonify({"schema": get_schema_description()})


@app.route("/api/health", methods=["GET"])
def health():
    check = verify_tables()
    return jsonify({
        "status":    "ok" if check.get("ok") else "degraded",
        "db":        "connected" if not check.get("error") else check["error"],
        "tables":    check.get("found", []),
        "missing":   check.get("missing", []),
        "timestamp": datetime.now().isoformat(),
    })


@app.route("/api/scrape-status", methods=["GET"])
def scrape_status():
    """Return scraping status for all products."""
    from chatbot.db_utils import execute_query
    result = execute_query("""
        SELECT
            p.product_id, p.sku, p.name,
            pmi.scrape_status, pmi.scraped_from,
            pmi.market_price_avg, pmi.last_scraped_at
        FROM products p
        LEFT JOIN product_market_info pmi ON p.product_id = pmi.product_id
        ORDER BY p.product_id
    """)
    return jsonify(result)


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
