import asyncio
from typing import AsyncIterator

from langgraph.checkpoint.sqlite import SqliteSaver


class AsyncCompatibleSqliteSaver(SqliteSaver):
    """SqliteSaver with async methods bridged via threads for LangGraph tools."""

    async def aget_tuple(self, config):
        return await asyncio.to_thread(self.get_tuple, config)

    async def alist(self, config, *, filter=None, before=None, limit=None) -> AsyncIterator:
        rows = await asyncio.to_thread(
            lambda: list(super().list(config, filter=filter,
                         before=before, limit=limit))
        )
        for row in rows:
            yield row

    async def aput(self, config, checkpoint, metadata, new_versions):
        return await asyncio.to_thread(
            super().put, config, checkpoint, metadata, new_versions
        )

    async def aput_writes(self, config, writes, task_id, task_path=""):
        await asyncio.to_thread(
            super().put_writes, config, writes, task_id, task_path
        )

    async def adelete_thread(self, thread_id: str) -> None:
        await asyncio.to_thread(super().delete_thread, thread_id)
