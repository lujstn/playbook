#!/usr/bin/env python3
# @nonobvious(forced-by) headless Claude Code offers AskUserQuestion only when a permission host can answer it; a PreToolUse hook does not count
"""Permission host for routing-shape probes: a stdio MCP server whose one tool answers every
AskUserQuestion with the option marked "(Recommended)", the way a user who takes the
recommendation would, and refuses every other permission request. Each request is appended
to $PICKER_HOST_LOG when it is set."""
import json
import os
import sys

LOG = os.environ.get("PICKER_HOST_LOG")


def send(msg):
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


def log(entry):
    if LOG:
        with open(LOG, "a") as f:
            f.write(json.dumps(entry) + "\n")


def pick(question):
    options = question.get("options") or []
    labels = [o.get("label", "") for o in options]
    recommended = [l for l in labels if "recommended" in l.lower()]
    if recommended:
        return recommended[0]
    return labels[0] if labels else ""


def decide(tool, tool_input):
    if tool == "AskUserQuestion":
        answers = {q.get("question", ""): pick(q) for q in tool_input.get("questions") or []}
        return {"behavior": "allow", "updatedInput": dict(tool_input, answers=answers)}
    return {"behavior": "deny", "message": "routing-shape harness: nobody is here to approve this; carry on without it."}


TOOL = {
    "name": "answer",
    "description": "Answers permission prompts and questions for a routing-shape probe.",
    "inputSchema": {
        "type": "object",
        "properties": {"tool_name": {"type": "string"}, "input": {"type": "object"}, "tool_use_id": {"type": "string"}},
        "required": ["tool_name", "input"],
    },
}

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        msg = json.loads(line)
    except ValueError:
        continue
    mid, method = msg.get("id"), msg.get("method")
    if method == "initialize":
        version = (msg.get("params") or {}).get("protocolVersion", "2024-11-05")
        send({"jsonrpc": "2.0", "id": mid, "result": {"protocolVersion": version, "capabilities": {"tools": {}},
                                                      "serverInfo": {"name": "picker-host", "version": "1"}}})
    elif method == "tools/list":
        send({"jsonrpc": "2.0", "id": mid, "result": {"tools": [TOOL]}})
    elif method == "tools/call":
        args = (msg.get("params") or {}).get("arguments") or {}
        decision = decide(args.get("tool_name", ""), args.get("input") or {})
        log({"tool": args.get("tool_name"), "input": args.get("input"), "decision": decision})
        send({"jsonrpc": "2.0", "id": mid, "result": {"content": [{"type": "text", "text": json.dumps(decision)}]}})
    elif mid is not None:
        send({"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": "method not found"}})
