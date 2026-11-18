## Signals of PS1Events (static classes can't have signals).
##   PS1Events.signals().event_started.connect(func(): player.frozen = true)
class_name PS1EventSignals
extends RefCounted

signal var_changed(name: String, value: int)
signal event_started
signal event_finished
