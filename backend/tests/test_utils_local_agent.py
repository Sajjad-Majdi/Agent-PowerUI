from backend import online_agent as backend_online_agent
from backend import local_agent as backend_local_agent
from backend import config as backend_config
import importlib
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

PROJECT_ROOT = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)


sys.modules.setdefault("config", backend_config)


sys.modules.setdefault("local_agent", backend_local_agent)
sys.modules.setdefault("online_agent", backend_online_agent)


class UtilsLocalAgentTests(unittest.TestCase):
    MODEL_NAME = "test-restart-model.gguf"

    @classmethod
    def setUpClass(cls):
        from backend import config

        cls.models_folder = config.Config.get_models_folder()
        os.makedirs(cls.models_folder, exist_ok=True)
        cls.model_path = os.path.join(cls.models_folder, cls.MODEL_NAME)
        with open(cls.model_path, "wb") as handle:
            handle.write(b"test")

    @classmethod
    def tearDownClass(cls):
        if os.path.exists(cls.model_path):
            os.remove(cls.model_path)

    def setUp(self):
        if "backend.utils" in importlib.sys.modules:
            importlib.reload(importlib.import_module("backend.utils"))

    def _import_utils(self):
        return importlib.import_module("backend.utils")

    def test_restart_after_explicit_stop_creates_fresh_instance(self):
        utils = self._import_utils()

        with patch("backend.utils.LocalAgent") as mock_local_agent:
            instance_one = MagicMock()
            instance_one.is_running.return_value = False
            instance_two = MagicMock()
            instance_two.is_running.return_value = False
            mock_local_agent.side_effect = [instance_one, instance_two]

            utils.initialize_local_agent(model_name=self.MODEL_NAME)
            utils.stop_local_agent()
            utils.initialize_local_agent(model_name=self.MODEL_NAME)

            self.assertEqual(mock_local_agent.call_count, 2)
            self.assertIs(utils.local_agent, instance_two)

    def test_restart_when_existing_agent_not_running(self):
        utils = self._import_utils()

        with patch("backend.utils.LocalAgent") as mock_local_agent:
            instance = MagicMock()
            instance.is_running.return_value = False
            mock_local_agent.return_value = instance

            utils.initialize_local_agent(model_name=self.MODEL_NAME)
            # Simulate manual stop without clearing global
            instance.is_running.return_value = False
            utils.initialize_local_agent(model_name=self.MODEL_NAME)

            self.assertEqual(mock_local_agent.call_count, 2)
            self.assertIs(utils.local_agent, instance)


if __name__ == "__main__":
    unittest.main()
