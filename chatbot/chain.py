"""
chain.py
LangChain pipeline using Gemini 2.5 Flash for:
  1. Natural language → SQL generation
  2. SQL result → Natural language answer
"""
import os
import re
import json
from dotenv import load_dotenv

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.prompts import ChatPromptTemplate, SystemMessagePromptTemplate, HumanMessagePromptTemplate
from langchain.schema.output_parser import StrOutputParser
from langchain_core.messages import SystemMessage, HumanMessage

from chatbot.db_utils import execute_query, get_schema_description

load_dotenv()

# ---------------------------------------------------------------------------
# Gemini 2.5 Flash LLM
# ---------------------------------------------------------------------------
def get_llm(temperature: float = 0.1) -> ChatGoogleGenerativeAI:
    return ChatGoogleGenerativeAI(
        model="gemini-2.5-flash",
        google_api_key=os.getenv("GEMINI_API_KEY"),
        temperature=temperature,
    )


# ---------------------------------------------------------------------------
# Step 1: Generate SQL from natural language
# ---------------------------------------------------------------------------
SQL_SYSTEM = """You are an expert PostgreSQL query writer for an ERP system.

{schema}

TASK: Convert the user's natural language question into a valid PostgreSQL SELECT query.

STRICT RULES:
1. Output ONLY the raw SQL query — no explanation, no markdown, no backticks.
2. Only use SELECT statements. Never use DML or DDL (no INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE).
3. Always add LIMIT 100 unless the user asks for aggregates or counts.
4. Use table aliases in JOINs (e.g., e for employees, d for departments).
5. For monetary values, round to 2 decimal places using ROUND(..., 2).
6. If the question is unanswerable with the schema, output exactly: CANNOT_ANSWER
7. Use ILIKE for case-insensitive string matching.
8. For employee full names, use CONCAT(first_name, ' ', last_name) or (first_name || ' ' || last_name).
"""

SQL_HUMAN = "Question: {question}"


def generate_sql(question: str) -> str:
    """Generate a SQL query from the natural language question."""
    llm = get_llm(temperature=0.0)

    messages = [
        SystemMessage(content=SQL_SYSTEM.format(schema=get_schema_description())),
        HumanMessage(content=SQL_HUMAN.format(question=question)),
    ]

    response = llm.invoke(messages)
    sql = response.content.strip()

    # Strip any accidental markdown fences
    sql = re.sub(r"^```(?:sql)?\s*", "", sql, flags=re.IGNORECASE)
    sql = re.sub(r"\s*```$", "", sql)
    return sql.strip()


# ---------------------------------------------------------------------------
# Step 2: Generate natural language answer from SQL result
# ---------------------------------------------------------------------------
ANSWER_SYSTEM = """You are a helpful ERP business analyst assistant.
You have executed a SQL query against the ERP database and received the results.
Your job is to answer the user's original question in a clear, concise, business-friendly way.

Guidelines:
- Be conversational but precise.
- If results are empty, say so clearly and explain likely reasons.
- Format numbers with commas (e.g., ₹1,50,000).
- Use Indian currency format (₹) where applicable.
- For lists of data, present them in a clean readable format.
- If there are many rows, summarize patterns rather than listing all.
- Keep the answer under 400 words unless the data demands more.
- Do NOT mention SQL, queries, or database technical details in your answer.
"""

ANSWER_HUMAN = """User question: {question}

SQL executed: {sql}

Query results ({rowcount} rows returned):
{results}

Please answer the user's question based on these results."""


def generate_answer(question: str, sql: str, query_result: dict) -> str:
    """Generate a natural language answer from the SQL result."""
    llm = get_llm(temperature=0.3)

    # Format results for the prompt
    if query_result.get("error"):
        results_text = f"ERROR: {query_result['error']}"
    elif not query_result["rows"]:
        results_text = "No data returned."
    else:
        # Truncate to first 50 rows for the prompt context
        rows = query_result["rows"][:50]
        results_text = json.dumps(rows, indent=2, default=str)

    messages = [
        SystemMessage(content=ANSWER_SYSTEM),
        HumanMessage(content=ANSWER_HUMAN.format(
            question=question,
            sql=sql,
            rowcount=query_result.get("rowcount", 0),
            results=results_text,
        )),
    ]

    response = llm.invoke(messages)
    return response.content.strip()


# ---------------------------------------------------------------------------
# Main pipeline: question → SQL → execute → answer
# ---------------------------------------------------------------------------
def erp_chat_pipeline(question: str, conversation_history: list = None) -> dict:
    """
    Full pipeline:
      1. Generate SQL from question (with optional conversation context)
      2. Execute SQL safely (SELECT only)
      3. Generate natural language answer from results

    Returns:
      {
        "sql": str,
        "result": dict,
        "answer": str,
        "error": str | None
      }
    """
    output = {
        "sql": "",
        "result": {},
        "answer": "",
        "error": None,
    }

    # --- Step 1: Generate SQL ---
    try:
        # If there's conversation history, include it in context
        context_question = question
        if conversation_history:
            history_text = "\n".join([
                f"{'User' if m['role'] == 'user' else 'Assistant'}: {m['content']}"
                for m in conversation_history[-6:]  # last 3 turns
            ])
            context_question = f"Conversation so far:\n{history_text}\n\nCurrent question: {question}"

        sql = generate_sql(context_question)
        output["sql"] = sql
    except Exception as exc:
        output["error"] = f"SQL generation failed: {str(exc)}"
        output["answer"] = "I encountered an error generating the query. Please rephrase your question."
        return output

    # --- Safety check: reject non-SELECT ---
    if sql == "CANNOT_ANSWER":
        output["answer"] = (
            "I'm unable to answer that question with the available ERP data. "
            "Please ask about employees, sales, inventory, finance, procurement, or CRM."
        )
        return output

    first_word = sql.strip().upper().split()[0] if sql.strip() else ""
    if first_word != "SELECT":
        output["error"] = "Non-SELECT query blocked for safety."
        output["answer"] = "That operation is not permitted. I can only read data, not modify it."
        return output

    # --- Step 2: Execute query ---
    result = execute_query(sql)
    output["result"] = result

    if result.get("error"):
        # Try to self-correct once
        try:
            correction_prompt = f"""The following SQL query has an error:

SQL: {sql}
Error: {result['error']}

Fix the SQL query. Return ONLY the corrected SQL, no explanation."""
            llm = get_llm(temperature=0.0)
            messages = [
                SystemMessage(content=SQL_SYSTEM.format(schema=get_schema_description())),
                HumanMessage(content=correction_prompt),
            ]
            corrected_sql = llm.invoke(messages).content.strip()
            corrected_sql = re.sub(r"^```(?:sql)?\s*", "", corrected_sql, flags=re.IGNORECASE)
            corrected_sql = re.sub(r"\s*```$", "", corrected_sql)
            output["sql"] = corrected_sql.strip()

            result = execute_query(corrected_sql)
            output["result"] = result
        except Exception:
            pass

        if result.get("error"):
            output["error"] = result["error"]
            output["answer"] = f"I ran into a database error: {result['error']}. Please try rephrasing your question."
            return output

    # --- Step 3: Generate answer ---
    try:
        answer = generate_answer(question, output["sql"], result)
        output["answer"] = answer
    except Exception as exc:
        output["error"] = f"Answer generation failed: {str(exc)}"
        output["answer"] = "I retrieved the data but couldn't generate a summary. Please try again."

    return output
