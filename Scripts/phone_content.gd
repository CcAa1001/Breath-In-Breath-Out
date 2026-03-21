extends Node

# ================================================================
# PHONE CONTENT MANAGER
# Edit everything here — news, messages, call settings
# Your friend controls all content from this single file
# ================================================================

# -------------------------------------------------------
# NEWS ARTICLES
# Add, remove or edit articles here
# They appear in order from top to bottom in the Berita screen
# -------------------------------------------------------
var news_articles: Array[Dictionary] = [
	{
		"time":  "08:14",
		"title": "BREAKING: Major Landslide on Mountain Road",
		"body":  "A sudden landslide has buried several vehicles on the highland road near KM 47. Rescue teams have been dispatched but access remains extremely difficult due to ongoing soil movement. Authorities urge drivers to avoid the area.",
		"tag":   "BREAKING",
		"urgent": true,
	},
	{
		"time":  "08:31",
		"title": "Rescue Teams Deployed to Scene",
		"body":  "Emergency services confirm at least one vehicle is trapped underground following this morning's landslide. Specialists are using ground-penetrating radar equipment to locate survivors beneath the debris.",
		"tag":   "UPDATE",
		"urgent": false,
	},
	{
		"time":  "08:55",
		"title": "Families Gather at Rescue Site",
		"body":  "Several families have gathered at the rescue perimeter following news of the landslide. Authorities urge anyone with information about missing persons traveling on the highland road this morning to contact emergency services immediately.",
		"tag":   "LIVE",
		"urgent": false,
	},
	{
		"time":  "09:12",
		"title": "Rescue Operation Underway",
		"body":  "Rescue coordinators report signs of life detected beneath the debris. Heavy equipment has been brought in to carefully remove soil layers. Officials say the operation could take several hours.",
		"tag":   "UPDATE",
		"urgent": false,
	},
]

# -------------------------------------------------------
# MESSAGES
# These are sent automatically at the times below
# message_time = seconds after game starts
# Add more messages or change the timing freely
# -------------------------------------------------------
var scheduled_messages: Array[Dictionary] = [
	{
		"sender":  "Mom",
		"message": "Hey, are you coming for dinner tonight? 😊",
		"time":    20.0,
	},
	{
		"sender":  "Jake",
		"message": "Dude where are you?? You were supposed to be here an hour ago",
		"time":    45.0,
	},
	{
		"sender":  "Mom",
		"message": "You're not answering... is everything ok?",
		"time":    75.0,
	},
	{
		"sender":  "Mom",
		"message": "I'm calling the police. Something is wrong. ❤️",
		"time":    110.0,
	},
	{
		"sender":  "Jake",
		"message": "Bro seriously call me back. Everyone is worried.",
		"time":    140.0,
	},
]

# -------------------------------------------------------
# CONTACTS
# These appear in the Telepon screen
# Only "emergency" type contacts can trigger rescue
# type options: "emergency", "personal", "unavailable"
# -------------------------------------------------------
var contacts: Array[Dictionary] = [
	{
		"name":    "112 — Emergency Services",
		"number":  "112",
		"type":    "emergency",
		"note":    "Requires emergency number from glove box",
		"locked":  true,   # true = needs emergency_number item first
	},
	{
		"name":    "Mom",
		"number":  "+62 812 3456 7890",
		"type":    "personal",
		"note":    "No signal underground.",
		"locked":  false,
	},
	{
		"name":    "Jake",
		"number":  "+62 857 9876 5432",
		"type":    "personal",
		"note":    "No signal underground.",
		"locked":  false,
	},
]

# -------------------------------------------------------
# EMERGENCY CALL DIALOGUE
# Edit the questions, answers and wrong answers here
# -------------------------------------------------------
var emergency_dialogue: Array[Dictionary] = [
	{
		"speaker": "Operator",
		"text": "Emergency services. What is your emergency?",
		"type": "player_choice",
		"choices": [
			"There was a landslide and I'm trapped in a buried car.",
			"I need help, I'm stuck somewhere.",
			"Hello? Can anyone hear me?",
		],
		"correct": 0,  # index of correct answer
		"wrong_response": "I'm sorry, could you repeat that? What is your emergency?",
	},
	{
		"speaker": "Operator",
		"text": "What is your location?",
		"type": "player_choice",
		"choices": [
			"A. Linden Street",
			"B. London Street",
			"C. Lindon Street",
			"D. Londen Street",
		],
		"correct": 0,
		"wrong_response": "I'm sorry, I didn't catch that. Can you repeat the street name?",
	},
	{
		"speaker": "Operator",
		"text": "What is your name?",
		"type": "player_input",
		"player_line": "John",   # fixed name — change here anytime
	},
	{
		"speaker": "Operator",
		"text": "Can you tell me what happened?",
		"type": "player_choice",
		"choices": [
			"I was driving and a landslide buried my car.",
			"I don't know what happened.",
			"Something fell on my car.",
		],
		"correct": 0,
		"wrong_response": "Please stay calm. Can you describe what happened?",
	},
	{
		"speaker": "Operator",
		"text": "When did this happen?",
		"type": "player_choice",
		"choices": [
			"Just a few seconds ago.",
			"About an hour ago.",
			"I'm not sure.",
		],
		"correct": 0,
		"wrong_response": "Understood. Can you be more specific about the time?",
	},
	{
		"speaker": "Operator",
		"text": "Help is on the way. Stay safe and keep this line open if you can.",
		"type": "operator_only",  # no player response needed
	},
]

# how long operator waits before speaking (feels more real)
var operator_response_delay: float = 1.5

# -------------------------------------------------------
# CALL SETTINGS
# Control how the emergency call behaves
# -------------------------------------------------------
var call_connecting_time: float  = 3.0    # seconds before call connects
var call_fail_chance: float      = 0.0    # 0.0 = never fails, 1.0 = always fails
var rescue_arrival_time: float   = 120.0  # seconds until rescue arrives

# -------------------------------------------------------
# NEWS TAG COLORS
# Controls color of each tag label
# -------------------------------------------------------
var tag_colors: Dictionary = {
	"BREAKING": Color(1.0, 0.2, 0.2),
	"UPDATE":   Color(0.2, 0.6, 1.0),
	"LIVE":     Color(0.2, 1.0, 0.4),
	"OPINION":  Color(1.0, 0.7, 0.2),
}
