"""Small database-facing helpers shared by SHSO economy endpoints."""

import economy_config


def sql_text(value):
	return str(value).replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"')


def token_user(db, session_token):
	if session_token is None:
		return None
	rows = db.executeQuery("SELECT userID FROM shso.tokens WHERE token='" + sql_text(session_token) + "' LIMIT 1")
	if rows is None or rows.size() == 0:
		return None
	return str(rows[0].getItem("userID"))


def user_balances(db, user_id, lock_row):
	suffix = ""
	if lock_row:
		suffix = " FOR UPDATE"
	rows = db.executeQuery("SELECT Gold, Fractals, Paid FROM shso.user WHERE ID=" + str(user_id) + suffix)
	if rows is None or rows.size() == 0:
		return None
	row = rows[0]
	return {
		"gold": int(row.getItem("Gold")),
		"fractals": int(row.getItem("Fractals")),
		"paid": int(row.getItem("Paid")),
	}


def user_owns_mission(db, user_id, mission_name):
	rows = db.executeQuery(
		"SELECT 1 FROM shso.missions m "
		"INNER JOIN shso.inventory i ON i.type=m.ownable_type_id "
		"WHERE i.UserID=" + str(user_id)
		+ " AND i.category='m' AND m.name='" + sql_text(mission_name) + "' LIMIT 1")
	return rows is not None and rows.size() > 0


def initialize_new_account(db, user_id):
	"""Idempotently grants only the configured starter content.

	Balances and Agent status are normally supplied by database column defaults;
	this helper exists for registration paths and tests that create the user row
	before granting starter ownables.
	"""
	for hero_name in economy_config.STARTER_CONTENT["heroes"]:
		if not db.executeCommand(
			"INSERT IGNORE INTO shso.heroes (UserID, Name) VALUES ("
			+ str(user_id) + ", '" + sql_text(hero_name) + "')"):
			return 0
	for mission in economy_config.STARTER_CONTENT["missions"]:
		mission_type = int(mission[1])
		if not db.executeCommand(
			"INSERT IGNORE INTO shso.inventory (UserID, type, category, subscriber_only) VALUES ("
			+ str(user_id) + ", " + str(mission_type) + ", 'm', 0)"):
			return 0
	return 1


def queue_notification(db, user_id, message_type, guid, success, error_code, balance):
	value = "NULL"
	if balance is not None:
		value = str(int(balance))
	sql = "INSERT INTO shso.pending_rtc_notifications (PlayerID, MessageType, Guid, Success, ErrorCode, Balance) VALUES (" + str(user_id) + ", '" + sql_text(message_type) + "', '" + sql_text(guid) + "', '" + sql_text(success) + "', '" + sql_text(error_code) + "', " + value + ")"
	return db.executeCommand(sql)
