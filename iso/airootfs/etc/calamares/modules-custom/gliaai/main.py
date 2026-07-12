# ============================================================
#  gliaai - Calamares job module
#  Version: 0.2 - 2026-07-12
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  Writes to the target system:
#  - /etc/glia/model: the AI model chosen in packagechooser@aimodel
#  - /etc/glia/lang:  mypc UI language (it/de/en) derived from the
#    system locale chosen in Calamares
#  Replaces contextualprocess@aimodel (module not shipped
#  by cachyos-calamares).
# ============================================================
import os
import libcalamares

MODELS = {
    "qwen25coder7b": "qwen2.5-coder:7b",
    "qwen34b": "qwen3:4b",
    "qwen25coder14b": "qwen2.5-coder:14b",
    "keep7b": "qwen2.5-coder:7b",
}
DEFAULT_MODEL = "qwen2.5-coder:7b"


def pretty_name():
    return "Configuring the GLIA AI model"


def run():
    gs = libcalamares.globalstorage
    choice = gs.value("packagechooser_aimodel")
    model = MODELS.get(choice, DEFAULT_MODEL)

    root = gs.value("rootMountPoint")
    if not root:
        return ("No rootMountPoint",
                "GlobalStorage has no rootMountPoint key.")

    etc_glia = os.path.join(root, "etc", "glia")
    os.makedirs(etc_glia, exist_ok=True)
    with open(os.path.join(etc_glia, "model"), "w") as f:
        f.write(model + "\n")

    # mypc UI language from the system locale (supported: it, de, en)
    locale_conf = gs.value("localeConf") or {}
    lang = str(locale_conf.get("LANG") or "en")
    if lang.startswith("it"):
        ui_lang = "it"
    elif lang.startswith("de"):
        ui_lang = "de"
    else:
        ui_lang = "en"
    with open(os.path.join(etc_glia, "lang"), "w") as f:
        f.write(ui_lang + "\n")

    libcalamares.utils.debug(
        "gliaai: model={} (choice={}) lang={} (LANG={})".format(
            model, choice, ui_lang, lang))
    return None
