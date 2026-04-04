"""
chain.py  (v2)
LangChain pipeline using Gemini 2.5 Flash.

NEW in v2:
  - Detect product queries → enrich from web if market data missing
  - Include reference records (ground truth table) in every response
  - Answer prompt now aware of market data columns
"""
import os
import re
import json
import logging
from dotenv import load_dotenv

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import SystemMessage, HumanMessage

from chatbot.db_utils import execute_query, get_schema_description
from chatbot.market_enricher import enrich_products_if_needed, get_product_ids_from_question

load_dotenv(override=True)
logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
# LLM
# ──────────────────────────────────────────────
def get_llm(temperature: float = 0.1) -> ChatGoogleGenerativeAI:
    return ChatGoogleGenerativeAI(
        model="gemini-2.5-flash",
        google_api_key=os.getenv("GEMINI_API_KEY"),
        temperature=temperature,
    )


# ──────────────────────────────────────────────
# Step 1: SQL generation
# ──────────────────────────────────────────────
SQL_SYSTEM = """You are an expert PostgreSQL query writer for an ERP system.

{schema}

ADDITIONAL TABLE (v2):
- **product_market_info** (info_id, product_id, market_price_min, market_price_max, market_price_avg,
  currency, availability, supplier_name, supplier_url, product_url, specifications JSONB,
  scraped_from, scrape_status, scrape_error, last_scraped_at, created_at)
  → Links to products.product_id. Contains live market pricing scraped from the web.

- **v_products_with_market** — VIEW with columns: product_id, sku, product_name, erp_unit_price, erp_cost_price, qty_in_stock, reorder_level, category, market_price_min, market_price_max, market_price_avg, market_availability, market_supplier, product_url, scraped_from, scrape_status. Use erp_unit_price (NOT unit_price) and erp_cost_price (NOT cost_price) when querying this view.
  Use this view when the question involves both ERP stock data AND market pricing.

TASK: Convert the user's natural language question into a valid PostgreSQL SELECT query.

STRICT RULES:
1. Output ONLY the raw SQL query — no explanation, no markdown, no backticks.
2. Only SELECT statements. Never DML/DDL.
3. LIMIT 100 unless aggregates/counts.
4. Use table aliases in JOINs.
5. Round monetary values to 2 decimal places.
6. If unanswerable, output exactly: CANNOT_ANSWER
7. Use ILIKE for case-insensitive string matching.
8. For full employee names: (first_name || ' ' || last_name).
9. When comparing ERP price vs market price, use v_products_with_market view.
"""

SQL_HUMAN = "Question: {question}"


def generate_sql(question: str) -> str:
    llm = get_llm(temperature=0.0)
    messages = [
        SystemMessage(content=SQL_SYSTEM.format(schema=get_schema_description())),
        HumanMessage(content=SQL_HUMAN.format(question=question)),
    ]
    response = llm.invoke(messages)
    sql = response.content.strip()
    sql = re.sub(r"^```(?:sql)?\s*", "", sql, flags=re.IGNORECASE)
    sql = re.sub(r"\s*```$", "", sql)
    return sql.strip()


# ──────────────────────────────────────────────
# Step 2: Natural language answer
# ──────────────────────────────────────────────
ANSWER_SYSTEM = """You are a helpful ERP business analyst assistant.
You have executed a SQL query and received results from an ERP database.
Your job: answer the user's question in a clear, concise, business-friendly way.

Guidelines:
- Be conversational but precise.
- Format numbers with Indian comma format (e.g., ₹1,50,000).
- Use ₹ for currency.
- Summarize patterns for large result sets rather than listing every row.
- Keep answer under 400 words unless data demands more.
- Do NOT mention SQL, queries, or database internals.
- If market data (scraped prices) is present in the results, compare ERP price vs market price
  and highlight if the ERP is over/under market rate.
- End your answer with a line: "📋 Reference records are shown below for ground truth."
"""

ANSWER_HUMAN = """User question: {question}

SQL executed: {sql}

Query results ({rowcount} rows):
{results}

Answer the question based on these results."""


def generate_answer(question: str, sql: str, query_result: dict) -> str:
    llm = get_llm(temperature=0.3)

    if query_result.get("error"):
        results_text = f"ERROR: {query_result['error']}"
    elif not query_result["rows"]:
        results_text = "No data returned."
    else:
        results_text = json.dumps(query_result["rows"][:50], indent=2, default=str)

    messages = [
        SystemMessage(content=ANSWER_SYSTEM),
        HumanMessage(content=ANSWER_HUMAN.format(
            question=question,
            sql=sql,
            rowcount=query_result.get("rowcount", 0),
            results=results_text,
        )),
    ]
    return llm.invoke(messages).content.strip()


# ──────────────────────────────────────────────
# Main pipeline  (v2)
# ──────────────────────────────────────────────
def erp_chat_pipeline(question: str, conversation_history: list = None) -> dict:
    """
    Full v2 pipeline:
      1. Detect if question involves products
      2. Enrich any missing/stale market data via web scraping
      3. Generate SQL (now aware of product_market_info)
      4. Execute SQL
      5. Generate NL answer
      6. Return answer + reference rows for ground-truth table in UI

    Returns:
    {
        "sql":            str,
        "result":         dict,
        "answer":         str,
        "error":          str | None,
        "enrichment":     dict,   # scrape summary
        "reference_rows": list,   # raw rows for UI ground-truth table
        "reference_cols": list,
    }
    """
    output = {
        "sql":            "",
        "result":         {},
        "answer":         "",
        "error":          None,
        "enrichment":     {},
        "reference_rows": [],
        "reference_cols": [],
    }

    #  Step 1: Product enrichment check 
    product_ids = get_product_ids_from_question(question)
    if product_ids:
        logger.info(f"Question touches products: {product_ids}")
        enrichment = enrich_products_if_needed(product_ids)
        output["enrichment"] = enrichment
        if enrichment["enriched"]:
            logger.info(f"Scraped fresh data for {len(enrichment['enriched'])} products")

    #  Step 2: SQL generation
    try:
        context_question = question
        if conversation_history:
            history_text = "\n".join([
                f"{'User' if m['role'] == 'user' else 'Assistant'}: {m['content']}"
                for m in conversation_history[-6:]
            ])
            context_question = f"Conversation so far:\n{history_text}\n\nCurrent question: {question}"

        sql = generate_sql(context_question)
        output["sql"] = sql
    except Exception as exc:
        output["error"]  = f"SQL generation failed: {str(exc)}"
        output["answer"] = "I encountered an error generating the query. Please rephrase your question."
        return output

    #  Safety check 
    if sql == "CANNOT_ANSWER":
        output["answer"] = (
            "I'm unable to answer that with the available ERP data. "
            "Please ask about employees, sales, inventory, finance, procurement, or CRM."
        )
        return output

    first_word = sql.strip().upper().split()[0] if sql.strip() else ""
    if first_word != "SELECT":
        output["error"]  = "Non-SELECT query blocked for safety."
        output["answer"] = "That operation is not permitted. I can only read data, not modify it."
        return output

    #  Step 3: Execute 
    result = execute_query(sql)
    output["result"] = result

    if result.get("error"):
        # Self-correct once
        try:
            correction_prompt = (
                f"The following SQL has an error:\n\nSQL: {sql}\nError: {result['error']}\n\n"
                "Fix it. Return ONLY the corrected SQL, no explanation."
            )
            llm = get_llm(temperature=0.0)
            corrected = llm.invoke([
                SystemMessage(content=SQL_SYSTEM.format(schema=get_schema_description())),
                HumanMessage(content=correction_prompt),
            ]).content.strip()
            corrected = re.sub(r"^```(?:sql)?\s*", "", corrected, flags=re.IGNORECASE)
            corrected = re.sub(r"\s*```$", "", corrected)
            output["sql"] = corrected.strip()
            result = execute_query(corrected)
            output["result"] = result
        except Exception:
            pass

        if result.get("error"):
            output["error"]  = result["error"]
            output["answer"] = f"I ran into a database error: {result['error']}. Please try rephrasing."
            return output

    # ── Step 4: Reference rows (ground truth) ─────────────────
    if result.get("rows"):
        output["reference_rows"] = result["rows"][:20]   # cap at 20 for UI
        output["reference_cols"] = result.get("columns", [])

    # Step 5: Generate answer
    try:
        output["answer"] = generate_answer(question, output["sql"], result)
    except Exception as exc:
        output["error"]  = f"Answer generation failed: {str(exc)}"
        output["answer"] = "I retrieved the data but couldn't generate a summary. Please try again."

    return output
