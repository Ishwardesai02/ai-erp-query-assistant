"""
app.py
Flask application for the ERP AI Chatbot.
"""
import os
import json
from datetime import datetime
from flask import Flask, render_template, request, jsonify, session
from flask_cors import CORS
from dotenv import load_dotenv

from chatbot.chain import erp_chat_pipeline

load_dotenv(override=True)

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "erp-chatbot-secret-2024")
CORS(app)

# ---------------------------------------------------------------------------
# Sample questions for the UI
# ---------------------------------------------------------------------------
SAMPLE_QUESTIONS = [
    "How many employees are in each department?",
    "Show me all pending sales orders with customer names",
    "Which products are below reorder level?",
    "What is the total revenue from delivered orders?",
    "List the top 5 highest paid employees",
    "Show unpaid invoices and their due dates",
    "Which employees have pending leave requests?",
    "What is the total value of purchase orders this month?",
    "Show me all active CRM leads with estimated values",
    "What is the payroll expense for last month?",
    "Which customers have the highest credit limits?",
    "Show stock movement for laptops",
]


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    """Main chat interface."""
    if "conversation" not in session:
        session["conversation"] = []
    return render_template("index.html", sample_questions=SAMPLE_QUESTIONS)


@app.route("/api/chat", methods=["POST"])
def chat():
    """Process a chat message and return the response."""
    data = request.get_json()
    question = data.get("question", "").strip()

    if not question:
        return jsonify({"error": "No question provided"}), 400

    # Retrieve conversation history from session
    if "conversation" not in session:
        session["conversation"] = []

    conversation_history = session["conversation"]

    # Run the ERP pipeline
    result = erp_chat_pipeline(question, conversation_history)

    # Update conversation history
    conversation_history.append({"role": "user",      "content": question})
    conversation_history.append({"role": "assistant", "content": result["answer"]})

    # Keep only last 20 messages to avoid session bloat
    session["conversation"] = conversation_history[-20:]
    session.modified = True

    # Prepare response payload
    response_data = {
        "question":  question,
        "answer":    result["answer"],
        "sql":       result.get("sql", ""),
        "rowcount":  result.get("result", {}).get("rowcount", 0),
        "columns":   result.get("result", {}).get("columns", []),
        "rows":      result.get("result", {}).get("rows", [])[:20],  # max 20 rows in UI table
        "error":     result.get("error"),
        "timestamp": datetime.now().strftime("%H:%M"),
    }
    return jsonify(response_data)


@app.route("/api/clear", methods=["POST"])
def clear_conversation():
    """Clear the conversation history."""
    session["conversation"] = []
    session.modified = True
    return jsonify({"status": "cleared"})


@app.route("/api/schema", methods=["GET"])
def get_schema():
    """Return the database schema overview for the UI."""
    from chatbot.db_utils import get_schema_description
    return jsonify({"schema": get_schema_description()})


@app.route("/api/health", methods=["GET"])
def health():
    """Health check endpoint."""
    from chatbot.db_utils import execute_query
    result = execute_query("SELECT COUNT(*) as total_employees FROM employees")
    db_ok = not bool(result.get("error"))
    return jsonify({
        "status": "ok" if db_ok else "degraded",
        "db": "connected" if db_ok else f"error: {result.get('error')}",
        "timestamp": datetime.now().isoformat(),
    })


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
