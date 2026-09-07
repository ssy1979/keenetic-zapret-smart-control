from pathlib import Path


def pre_find_module_path(hook_api):
    hook_api.search_dirs = [str(Path(__file__).resolve().parents[2] / "vendor")]
