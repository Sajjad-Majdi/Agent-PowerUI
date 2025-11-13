"""Manual tester for streamable HTTP MCP servers.

Run this script with `python backend/tests/manual_mcp_streamable_http.py` to
verify that a remote MCP endpoint is reachable using langchain-mcp-adapters.
"""

import asyncio
import json
import traceback
from typing import Any, Dict

from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.tools import load_mcp_tools


async def probe_server(server_name: str, server_config: Dict[str, Any]) -> None:
    client = MultiServerMCPClient({server_name: server_config})
    print(
        f"Connecting to {server_name} with config:\n{json.dumps(server_config, indent=2)}")

    async with client.session(server_name) as session:
        tools = await load_mcp_tools(session)
        print(f"Discovered {len(tools)} tools:")
        for tool in tools:
            print(f"  - {tool.name}: {getattr(tool, 'description', '')}")


def main() -> None:
    server_name = "hugging_face"
    server_config: Dict[str, Any] = {
        "url": "https://huggingface.co/mcp",
        "transport": "streamable_http",
        "headers": {
            "Authorization": "Bearer YOUR_HF_TOKEN_HERE"
        }
    }

    try:
        asyncio.run(probe_server(server_name, server_config))
    except Exception as exc:  # noqa: BLE001 - manual diagnostic script
        print("\n--- Connection failed ---")
        traceback.print_exception(exc)


if __name__ == "__main__":
    main()
