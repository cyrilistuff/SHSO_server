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


def queue_notification(db, user_id, message_type, guid, success, error_code, balance):
	value = "NULL"
	if balance is not None:
		value = str(int(balance))
	sql = "INSERT INTO shso.pending_rtc_notifications (PlayerID, MessageType, Guid, Success, ErrorCode, Balance) VALUES (" + str(user_id) + ", '" + sql_text(message_type) + "', '" + sql_text(guid) + "', '" + sql_text(success) + "', '" + sql_text(error_code) + "', " + value + ")"
	return db.executeCommand(sql)
