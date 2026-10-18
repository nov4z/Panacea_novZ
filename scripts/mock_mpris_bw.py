#!/usr/bin/env python3
import sys
import os
import time
from pathlib import Path
import dbus
import dbus.service
import dbus.exceptions
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)

_repo_root = Path(__file__).resolve().parent.parent
_bw_cover = _repo_root / "screenshots" / "bw_cover.png"
if not _bw_cover.exists():
    _bw_cover = Path(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))) / "panacea" / "screenshots" / "bw_cover.png"
_bw_cover_url = f"file://{_bw_cover.resolve()}"

class MprisPlayer(dbus.service.Object):
    def __init__(self, bus_name):
        super().__init__(bus_name, '/org/mpris/MediaPlayer2')
        self.status = "Playing"
        self.position = 45000000
        self.metadata = {
            'mpris:trackid': dbus.ObjectPath('/org/mpris/MediaPlayer2/Track/1', variant_level=1),
            'mpris:length': dbus.Int64(215000000, variant_level=1),
            'mpris:artUrl': dbus.String(_bw_cover_url, variant_level=1),
            'xesam:album': dbus.String('Monochrome Sessions', variant_level=1),
            'xesam:albumArtist': dbus.Array(['Panacea Studio'], signature='s', variant_level=1),
            'xesam:artist': dbus.Array(['Nova & Panacea'], signature='s', variant_level=1),
            'xesam:title': dbus.String('Pure Radiant White (Acoustic B&W)', variant_level=1),
            'xesam:url': dbus.String(_bw_cover_url, variant_level=1)
        }

    @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='ss', out_signature='v')
    def Get(self, interface, prop):
        props = self.GetAll(interface)
        if prop in props:
            return props[prop]
        raise dbus.exceptions.DBusException(f"Property '{prop}' not found on '{interface}'", name='org.freedesktop.DBus.Error.UnknownProperty')

    @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='s', out_signature='a{sv}')
    def GetAll(self, interface):
        if interface == 'org.mpris.MediaPlayer2':
            return {
                'CanQuit': dbus.Boolean(False),
                'CanRaise': dbus.Boolean(False),
                'HasTrackList': dbus.Boolean(False),
                'Identity': dbus.String('MonochromeStudio'),
                'SupportedUriSchemes': dbus.Array([], signature='s'),
                'SupportedMimeTypes': dbus.Array([], signature='s')
            }
        elif interface == 'org.mpris.MediaPlayer2.Player':
            return {
                'PlaybackStatus': dbus.String(self.status),
                'LoopStatus': dbus.String('None'),
                'Rate': dbus.Double(1.0),
                'Shuffle': dbus.Boolean(False),
                'Metadata': dbus.Dictionary(self.metadata, signature='sv'),
                'Volume': dbus.Double(1.0),
                'Position': dbus.Int64(self.position),
                'MinimumRate': dbus.Double(1.0),
                'MaximumRate': dbus.Double(1.0),
                'CanControl': dbus.Boolean(True),
                'CanPlay': dbus.Boolean(True),
                'CanPause': dbus.Boolean(True),
                'CanSeek': dbus.Boolean(True),
                'CanGoNext': dbus.Boolean(True),
                'CanGoPrevious': dbus.Boolean(True)
            }
        return {}

    @dbus.service.method('org.mpris.MediaPlayer2.Player')
    def Next(self): pass

    @dbus.service.method('org.mpris.MediaPlayer2.Player')
    def Previous(self): pass

    @dbus.service.method('org.mpris.MediaPlayer2.Player')
    def Pause(self):
        self.status = "Paused"

    @dbus.service.method('org.mpris.MediaPlayer2.Player')
    def PlayPause(self):
        self.status = "Paused" if self.status == "Playing" else "Playing"

    @dbus.service.method('org.mpris.MediaPlayer2.Player')
    def Stop(self):
        self.status = "Stopped"

    @dbus.service.method('org.mpris.MediaPlayer2.Player')
    def Play(self):
        self.status = "Playing"

def main():
    bus = dbus.SessionBus()
    name = dbus.service.BusName('org.mpris.MediaPlayer2.MonochromeStudio', bus)
    player = MprisPlayer(name)
    print("MonochromeStudio MPRIS service running...", flush=True)
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    main()
