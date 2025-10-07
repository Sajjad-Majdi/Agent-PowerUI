import os
from langchain.tools import tool
from langchain_tavily import TavilySearch
from datetime import datetime
import json
from typing import Optional
from config import Config


@tool
def search_web(query: str, num_results: int = 5) -> str:
    """
    search the web for information,

    Note: 
        - use keywords as query, not a full question (example: "capital of France?", "weather in Tokyo?", "latest news on AI")
    Args:
        - query (str): The search query.
        - num_results (int): The number of results to return."""
    search = TavilySearch(
        max_results=num_results,
        api_key=os.environ.get("TAVILY_API_KEY")
    )
    results = search.run(query)
    results = results["results"]

    formated_results = "\n================= Search results ===================\n"
    for i, result in enumerate(results):
        formated_results += f"""---- Result {i + 1} --------------------------------
            *title:* {result['title']}
            *url:* {result['url']}
            *content:* {result['content']}\n"""
    return formated_results


@tool
def update_memory(fact: str, category: str, fact_id: Optional[int] = None) -> str:
    """
    Adds new fact to your memory, or updates an old one
    Only set the fact_id parameter in case the new fact is in conflict with an old one.

    Args:
        fact (str): The fact to update or add to your memory.
        category (str): The category of the fact.
        fact_id (int): The id of the conflicting fact to update.
    """
    # Resolve absolute path and ensure file exists
    memory_path = Config.memory_path
    os.makedirs(os.path.dirname(memory_path), exist_ok=True)
    if not os.path.exists(memory_path):
        # initialize empty memory structure
        with open(memory_path, "w") as f:
            json.dump({}, f)
    with open(memory_path, "r") as f:
        try:
            memory = json.load(f)
        except json.JSONDecodeError:
            memory = {}

    if category not in memory:
        memory[category] = []

    if fact_id is None:
        id = len(memory[category]) + 1

        new_fact = {
            "id": id,
            "fact": fact,
            "timestamp": datetime.now().isoformat()
        }
        memory[category].append(new_fact)
    else:
        for i, item in enumerate(memory[category]):
            if item["id"] == fact_id:
                memory[category][i] = {
                    "id": fact_id,
                    "fact": fact,
                    "timestamp": datetime.now().isoformat()
                }
                break

    # Save back to file
    with open(memory_path, "w") as f:
        json.dump(memory, f, indent=4)

    return "memory updated successfully"


if __name__ == "__main__":
    update_memory("Sajjad is a programmer", "User Information")
