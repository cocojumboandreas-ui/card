#!/usr/bin/env python3
# Wgrywa cardsw/*.png do grupy 175176483 ("Junk to Gold", właściciel placu "karta") przez
# Open Cloud, NIE przez MCP upload_image (ten wgrywa na indywidualne konto Studio, nie grupę --
# patrz CardArtConfig.luau komentarz o cross-owner minie). Zależy od D:\RobloxProjects\oc_upload.py
# (wspólny helper dla wszystkich projektów, GROUP_KEY_ENV mapuje grupę -> nazwę zmiennej z kluczem).
#
# Uwaga: assetType="Decal" zwraca ID Decala, NIE ID gotowe do ImageLabel.Image -- po uploadzie
# odpal resolve_decal_textures.luau w Studio, żeby wyciągnąć prawdziwe Texture ID (druga mina,
# też udokumentowana w CardArtConfig.luau).
import os, sys, json, time, glob

os.environ["ROBLOX_CREATOR_GROUP_ID"] = "175176483"
sys.path.insert(0, r"D:\RobloxProjects")
import oc_upload as oc

print("GROUP_ID:", oc.GROUP_ID, "KEY_ENV_NAME:", oc.KEY_ENV_NAME, "key_set:", bool(oc.KEY))

SRC_DIR = os.path.join(os.path.dirname(__file__), "..", "cardsw")
OUT = os.path.join(os.path.dirname(__file__), "oc_manifest_cards.json")

results = {}
for path in sorted(glob.glob(os.path.join(SRC_DIR, "*.png"))):
    name = os.path.splitext(os.path.basename(path))[0]
    print(f"uploading {name} ...", flush=True)
    res = oc.upload_file(path, asset_type="Decal", display_name=name)
    results[name] = res
    print(" ->", res, flush=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    time.sleep(0.5)

print("DONE ->", OUT)
