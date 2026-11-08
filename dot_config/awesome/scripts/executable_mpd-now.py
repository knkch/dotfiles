#!/usr/bin/env python3
"""rmpc から MPD の状態を読み、Awesome 用に「キー<TAB>値」の行で出力する。

  mpd-now.py        再生状態と曲情報
  mpd-now.py art    今の曲のアートワークをキャッシュに保存し、そのパスを出力 (無ければ空)
"""
import hashlib, json, os, subprocess, sys

CACHE = os.path.expanduser("~/.cache/awesome/mpd-art")


def rmpc(*args):
    r = subprocess.run(["rmpc", *args], capture_output=True, text=True, timeout=5)
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)
    except ValueError:
        return None


def tag(meta, *names):
    for n in names:
        v = meta.get(n) or meta.get(n.capitalize())
        if isinstance(v, list):
            v = ", ".join(map(str, v))
        if v:
            return str(v)
    return ""


def secs(v):
    if isinstance(v, dict):
        return v.get("secs", 0) + v.get("nanos", 0) / 1e9
    return float(v or 0)


def out(k, v):
    print(f"{k}\t{str(v).replace(chr(10), ' ').replace(chr(9), ' ')}")


def status():
    st = rmpc("status")
    if st is None:
        out("state", "offline")
        return
    out("state", str(st.get("state", "stop")).lower())
    out("elapsed", int(secs(st.get("elapsed"))))
    out("duration", int(secs(st.get("duration"))))
    if st.get("songid") is None:
        return
    song = rmpc("song") or {}
    meta = song.get("metadata") or {}
    f = song.get("file", "")
    out("file", f)
    out("title", tag(meta, "title") or os.path.splitext(os.path.basename(f))[0])
    out("artist", tag(meta, "artist", "albumartist"))
    out("album", tag(meta, "album"))


def art():
    song = rmpc("song") or {}
    f = song.get("file")
    if not f:
        return
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, hashlib.md5(f.encode()).hexdigest() + ".img")
    if not os.path.exists(path):
        r = subprocess.run(["rmpc", "albumart", "-o", path], capture_output=True, timeout=10)
        if r.returncode != 0 or not os.path.exists(path):
            return
    print(path)


if __name__ == "__main__":
    try:
        art() if sys.argv[1:] == ["art"] else status()
    except Exception:
        out("state", "offline")
