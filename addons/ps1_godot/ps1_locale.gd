## Translations made easy. One CSV holds every language (Godot imports it into .translation
## files automatically):
##
##   keys,pt,en,es
##   "Abrir o baú","Abrir o baú","Open the chest","Abrir el cofre"
##
## The KEY can be the original sentence itself (gettext style): your code and events stay
## readable (`tr("Abrir o baú")`) and a missing translation simply shows the original.
##
##   PS1Locale.setup("res://lang/strings.csv")     # once, at startup (loads every column)
##   PS1Locale.set_language("en")                  # saved by PS1Settings ("general/language")
##   PS1Locale.languages()                         # ["pt", "en", "es"]
##   PS1Locale.t("Abrir o baú")                    # anywhere, also in static code
##
## Event texts, choices and prompts (PS1Event) are translated automatically. Editor: Project >
## Tools > "PS1: Update translation CSV" collects every event text and every tr("...") /
## PS1Locale.t("...") in your scripts into the CSV, keeping what was already translated.
class_name PS1Locale
extends RefCounted

const NATIVE_NAMES := {pt = "Português", en = "English", es = "Español", fr = "Français", de = "Deutsch",
	it = "Italiano", ja = "日本語", ru = "Русский", zh = "中文", ko = "한국어", pl = "Polski", tr = "Türkçe"}

## Language of the original text (the CSV keys). Used when the OS language isn't available.
static var source_language := "en"
static var csv_path := ""
static var _languages: PackedStringArray = []
static var _signals: PS1LocaleSignals

static func signals() -> PS1LocaleSignals:
	if _signals == null:
		_signals = PS1LocaleSignals.new()
	return _signals

## Loads the translations imported from `csv` (files <name>.<lang>.translation next to it).
## source: language of the keys.
static func setup(csv: String, source := "") -> void:
	_load_csv_translations("res://addons/ps1_godot/lang/ps1_ui.csv", false)   # the toolkit's own menus
	csv_path = csv
	if source != "":
		source_language = source
	_languages = [source_language]
	for lang in _load_csv_translations(csv, true):
		if not lang in _languages:
			_languages.append(lang)

static var _loaded := {}

## Adds the imported translations of a CSV; returns their languages.
static func _load_csv_translations(csv: String, warn: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := csv.get_base_dir()
	var base := csv.get_file().get_basename()
	var da := DirAccess.open(dir)
	if da == null:
		if warn: push_warning("PS1Locale: folder not found: " + dir)
		return out
	for f in da.get_files():
		f = f.trim_suffix(".remap")
		if f.begins_with(base + ".") and f.ends_with(".translation"):
			var lang := f.trim_prefix(base + ".").trim_suffix(".translation")
			var path := dir.path_join(f)
			if not _loaded.has(path):
				var t := load(path) as Translation
				if t:
					TranslationServer.add_translation(t)
					_loaded[path] = true
			out.append(lang)
	return out

static func languages() -> PackedStringArray:
	return _languages

static func native_name(lang: String) -> String:
	return NATIVE_NAMES.get(lang.substr(0, 2), lang)

static func language() -> String:
	return TranslationServer.get_locale().substr(0, 2)

static func set_language(lang: String) -> void:
	if lang == "":
		lang = default_language()
	TranslationServer.set_locale(lang)
	signals().changed.emit(lang)

## The OS language if we have it, else the source language.
static func default_language() -> String:
	var os := OS.get_locale_language()
	return os if os in _languages else source_language

## Marks a text for translation WITHOUT translating it (gettext's N_): for constants, save
## keys, texts translated later at display time. The collector finds it like tr("...").
static func mark(text: String) -> String:
	return text

## Translate (works in static code too). Same as Node.tr().
static func t(text: String) -> String:
	if text == "":
		return text
	return String(TranslationServer.translate(text))

# ---------------- editor: collect the texts ----------------

## Collects translatable texts: every PS1Event in the scenes (pages' prompts, Show Text,
## choices...) and every tr("...") / PS1Locale.t("...") / tr_n literal in scripts under `roots`.
## Returns the unique texts in discovery order.
static func collect(roots: PackedStringArray = ["res://"]) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("(?:\\btr|PS1Locale\\.t|PS1Locale\\.mark)\\(\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	for root in roots:
		for f in _files(root):
			if f.ends_with(".gd"):
				var src := FileAccess.get_file_as_string(f)
				for m in re.search_all(src):
					_add(out, m.get_string(1).c_unescape())
			elif f.ends_with(".tscn") or f.ends_with(".tres"):
				var txt := FileAccess.get_file_as_string(f)
				if not ("ps1_event" in txt or "PS1Cmd" in txt or "ps1_cmd" in txt):
					continue
				var res = load(f)
				if res is PackedScene:
					var inst := (res as PackedScene).instantiate()
					for ev in inst.find_children("*", "PS1Event", true, false) + ([inst] if inst is PS1Event else []):
						for p in ev.pages:
							if p:
								_add(out, p.prompt)
								_collect_list(p.commands, out)
					inst.free()
	return out

static func _collect_list(list: Array, out: PackedStringArray) -> void:
	for c in list:
		if c == null:
			continue
		for prop in ["text", "speaker", "question", "message", "texto"]:
			var v = c.get(prop)
			if v is String:
				_add(out, v)
		var br = c.get("branches")
		if br is Array:
			for b in br:
				if b:
					_add(out, b.label)
					_collect_list(b.commands, out)
			continue
		for blk in c.blocks():
			var l = blk[1].get(blk[2])
			if l is Array:
				_collect_list(l, out)

static func _add(out: PackedStringArray, s: String) -> void:
	if s.strip_edges() != "" and not s in out and not s.begins_with("res://"):
		out.append(s)

static func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for d in da.get_directories():
		if d.begins_with(".") or d == "addons" and dir == "res://":
			continue
		out.append_array(_files(dir.path_join(d)))
	for f in da.get_files():
		out.append(dir.path_join(f))
	return out

## Creates/updates the CSV: new texts are appended (source column = the text), translations
## already there are kept, texts no longer used stay (marked in the report). Returns a report.
static func update_csv(csv: String, langs: PackedStringArray, source: String, roots: PackedStringArray = ["res://"]) -> Dictionary:
	var rows := {}            # key -> {lang: text}
	var order := PackedStringArray()
	var header := PackedStringArray(["keys"])
	if FileAccess.file_exists(csv):
		var f := FileAccess.open(csv, FileAccess.READ)
		header = f.get_csv_line()
		while not f.eof_reached():
			var line := f.get_csv_line()
			if line.size() < 1 or line[0] == "":
				continue
			var d := {}
			for i in range(1, mini(line.size(), header.size())):
				d[header[i]] = line[i]
			rows[line[0]] = d
			order.append(line[0])
	for l in [source] + Array(langs):
		if not l in header:
			header.append(l)
	var found := collect(roots)
	var added := 0
	for s in found:
		if not rows.has(s):
			rows[s] = {source: s}
			order.append(s)
			added += 1
	var missing := {}
	for k in order:
		for l in header.slice(1):
			if l != source and String(rows[k].get(l, "")) == "":
				missing[l] = missing.get(l, 0) + 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(csv.get_base_dir()))
	var w := FileAccess.open(csv, FileAccess.WRITE)
	w.store_csv_line(header)
	for k in order:
		var line := PackedStringArray([k])
		for l in header.slice(1):
			line.append(rows[k].get(l, ""))
		w.store_csv_line(line)
	w.close()
	var unused := 0
	for k in order:
		if not k in found:
			unused += 1
	return {texts = order.size(), added = added, missing = missing, unused = unused}
