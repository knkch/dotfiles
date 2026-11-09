#!/usr/bin/env python3
"""バーのトレイから一部のアプリのアイコンを消すための、最小限の StatusNotifierWatcher。

fcitx5 などは「StatusNotifierWatcher (新しい方式のトレイの受付)」があるとそちらに登録し、
古い方式 (XEmbed) のトレイにはアイコンを出さなくなる。この受付は ACCEPT に書いたアプリだけを受け付け、
ほかのアプリは断るので、今まで通りトレイに出る。受け付けたアイコンはどこにも表示しない
(状態はバーの自作アイコンで出している: modules/widgets/indicators.lua)。
"""
import os

from gi.repository import Gio, GLib

# 受け付ける (= トレイから消す) アプリ。コマンド名 (python で動くものはスクリプト名) で判断する
ACCEPT = {"fcitx5", "nm-applet", "blueman-tray"}

XML = """
<node>
  <interface name="org.kde.StatusNotifierWatcher">
    <method name="RegisterStatusNotifierItem"><arg name="service" type="s" direction="in"/></method>
    <method name="RegisterStatusNotifierHost"><arg name="service" type="s" direction="in"/></method>
    <property name="RegisteredStatusNotifierItems" type="as" access="read"/>
    <property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
    <property name="ProtocolVersion" type="i" access="read"/>
    <signal name="StatusNotifierItemRegistered"><arg type="s"/></signal>
    <signal name="StatusNotifierItemUnregistered"><arg type="s"/></signal>
    <signal name="StatusNotifierHostRegistered"/>
  </interface>
</node>
"""

items = []


def names_of(conn, sender):
    """登録してきたプロセスのコマンド名 (最初の 2 つの引数のファイル名)"""
    try:
        pid = conn.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                             "GetConnectionUnixProcessID", GLib.Variant("(s)", (sender,)),
                             GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, 500, None).unpack()[0]
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            args = f.read().split(b"\0")[:2]
        return {os.path.basename(a.decode(errors="replace")) for a in args if a}
    except Exception:
        return set()


def on_call(conn, sender, path, iface, method, params, invocation):
    if method == "RegisterStatusNotifierItem":
        if not names_of(conn, sender) & ACCEPT:
            # 断ると、アプリは古い方式のトレイにアイコンを出す
            invocation.return_dbus_error("org.freedesktop.DBus.Error.NotSupported", "not handled here")
            return
        service = params.unpack()[0]
        name = service if service.startswith(":") else sender + service if service.startswith("/") else service
        if name not in items:
            items.append(name)
        invocation.return_value(None)
        conn.emit_signal(None, path, iface, "StatusNotifierItemRegistered", GLib.Variant("(s)", (name,)))
    else:
        invocation.return_value(None)


def on_get(conn, sender, path, iface, prop):
    if prop == "RegisteredStatusNotifierItems":
        return GLib.Variant("as", items)
    if prop == "IsStatusNotifierHostRegistered":
        # 引き受けるアプリには「表示する側がいる」と答えて登録させる (nm-applet はこれを見る)。
        # ほかのアプリ (Chrome・Electron など) には「いない」と答え、今まで通り古い方式のトレイを使わせる
        return GLib.Variant("b", bool(names_of(conn, sender) & ACCEPT))
    return GLib.Variant("i", 0)


def on_bus(conn, name):
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    conn.register_object("/StatusNotifierWatcher", node.interfaces[0], on_call, on_get, None)


Gio.bus_own_name(Gio.BusType.SESSION, "org.kde.StatusNotifierWatcher", Gio.BusNameOwnerFlags.NONE,
                 on_bus, None, lambda *_: GLib.MainLoop().quit())
GLib.MainLoop().run()
