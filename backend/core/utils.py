import json
import os


def get_memory():
    memory_path = os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), 'memory', 'fact.json')
    with open(memory_path, "r") as f:
        memory = json.load(f)

    text = ""
    for category in memory:
        text += f"Category: {category}\n"
        for fact in memory[category]:
            text += f"  - Fact {fact['id']}: {fact['fact']}\n"
            text += f"  - Last updated: {fact['timestamp']}\n"
        text += "\n"

    return text
