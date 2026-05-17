extends HBoxContainer

@onready var rank_label = %RankLabel
@onready var name_label = %NameLabel
@onready var score_label = %ScoreLabel

func setup(rank: int, team_name: String, score: float):
	rank_label.text = "#" + str(rank)
	name_label.text = team_name
	score_label.text = NumberFormatter.format_value(score) + " km"
