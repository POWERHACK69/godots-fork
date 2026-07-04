class_name RssFeedItemControl
extends HBoxListItem

signal tag_clicked(tag: String)

@onready var _title_label := %TitleLabel as Label
@onready var _source_label := %SourceLabel as Label
@onready var _date_label := %DateLabel as Label
@onready var _open_button := %OpenButton as Button

var _item: RssFeed.FeedItem
var _tags: Array = []


func init(item: RssFeed.FeedItem) -> void:
	_item = item
	_tags = [item.source_name]

	_title_label.text = item.title
	_source_label.text = item.source_name
	_date_label.text = _format_date(item.published)

	_open_button.icon = get_theme_icon("ExternalLink", "EditorIcons")	
	_open_button.pressed.connect(func() -> void: OS.shell_open(item.link))


func apply_filter(filter: Callable) -> bool:
	return filter.call({
		'name': _item.title,
		'path': _item.source_name,
		'tags': _tags
	})


func get_sort_data() -> Dictionary:
	return {'ref': self, 'published': _item.published}


func _format_date(date_str: String) -> String:
	if date_str.is_empty():
		return ""
	# ISO 8601: 2026-03-10T14:30:00+00:00
	if "T" in date_str:
		var parts := date_str.split("T")
		var date_parts := parts[0].split("-")
		if date_parts.size() >= 3:
			return "%s-%s-%s" % [date_parts[0], date_parts[1], date_parts[2]]
	# RFC 2822: Mon, 10 Mar 2026 14:30:00 +0000
	if "," in date_str:
		var comma_parts := date_str.split(",")
		if comma_parts.size() > 1:
			return comma_parts[1].strip_edges().left(16)
	return date_str
