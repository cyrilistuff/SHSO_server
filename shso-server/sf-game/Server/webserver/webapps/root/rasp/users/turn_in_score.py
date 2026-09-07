import sys
from javax.servlet.http import HttpServlet
import it.gotoandplay.smartfoxserver.extensions.ExtensionHelper
ex = it.gotoandplay.smartfoxserver.extensions.ExtensionHelper.instance()

sys.path.append('/sfs/Server/webserver/webapps/root/pylibcsp')
import pylibcsp
import economy_config
import economy_service


def request_value(request, wanted, default_value):
	for name in request.getParameterNames():
		if name == wanted:
			return request.getParameter(name)
	return default_value


def write_response(response, status, body):
	w = response.getWriter()
	w.println("<response><status>" + str(status) + "</status>")
	w.println("<headers><Content-Type>text/html; charset=utf-8</Content-Type></headers>")
	w.println("<body>" + str(body) + "</body></response>")
	w.close()


def add_rewards(db, user_id, hero_name, xp, fractals):
	if not db.executeCommand("UPDATE shso.user SET Fractals=Fractals+" + str(int(fractals)) + " WHERE ID=" + str(user_id)):
		return 0
	if not db.executeCommand("UPDATE shso.heroes SET Xp=Xp+" + str(int(xp)) + " WHERE UserID=" + str(user_id) + " AND Name='" + economy_service.sql_text(hero_name) + "'"):
		return 0
	rows = db.executeQuery("SELECT Xp, Tier FROM shso.heroes WHERE UserID=" + str(user_id) + " AND Name='" + economy_service.sql_text(hero_name) + "' LIMIT 1")
	if rows is not None and rows.size() > 0:
		total_xp = int(rows[0].getItem("Xp"))
		tier = int(rows[0].getItem("Tier"))
		new_tier = tier
		if total_xp >= 8100 and new_tier < 1:
			new_tier = 1
		if total_xp >= 40000 and new_tier < 2:
			new_tier = 2
		if new_tier != tier:
			db.executeCommand("UPDATE shso.heroes SET Tier=" + str(new_tier) + " WHERE UserID=" + str(user_id) + " AND Name='" + economy_service.sql_text(hero_name) + "'")
	return 1


class turn_in_score(HttpServlet):
	def doGet(self, request, response):
		pass

	def doPost(self, request, response):
		if pylibcsp.ipcheck(False):
			return
		db = ex.getZone('shs.all').dbManager
		user_id = economy_service.token_user(db, request_value(request, "AS_SESSION_KEY", None))
		if user_id is None:
			write_response(response, 400, "invalid session")
			return
		active = db.executeQuery("SELECT MissionID FROM shso.active_missions WHERE UserID=" + str(user_id) + " LIMIT 1")
		if active is None or active.size() == 0:
			write_response(response, 409, "no active mission")
			return
		mission_id = str(active[0].getItem("MissionID"))
		if economy_config.CONTENT_POLICY["respect_mission_availability"]:
			if not economy_service.user_owns_mission(db, user_id, mission_id):
				write_response(response, 403, "mission is not owned")
				return
		medal = int(request_value(request, "medal", 0))
		score = int(request_value(request, "score", 0))
		account = economy_service.user_balances(db, user_id, 0)
		if account is None:
			write_response(response, 400, "player account not found")
			return
		daily = db.executeQuery("SELECT mission_name FROM shso.daily_missions WHERE name='daily_mission_name' LIMIT 1")
		is_daily = daily is not None and daily.size() > 0 and str(daily[0].getItem("mission_name")) == mission_id
		fractals, xp = economy_config.mission_reward(mission_id, medal, score, account["paid"], is_daily)
		equipped = db.executeQuery("SELECT hero_name FROM shso.equips WHERE UserID=" + str(user_id) + " LIMIT 1")
		if equipped is None or equipped.size() == 0:
			write_response(response, 409, "no equipped hero")
			return
		hero_name = str(equipped[0].getItem("hero_name"))
		potion = db.executeQuery("SELECT IF(TIMESTAMPDIFF(MINUTE,start_timestamp,CURRENT_TIMESTAMP)>60,'T','F') FROM shso.active_potion_effects WHERE userid=" + str(user_id) + " AND ownable_type_id=298429 LIMIT 1")
		if potion is not None and potion.size() > 0:
			if str(potion[0].getItem(0)) == "F":
				xp = int(round(float(xp) * 1.25))
			else:
				db.executeCommand("DELETE FROM shso.active_potion_effects WHERE userid=" + str(user_id) + " AND ownable_type_id=298429")
		db.executeCommand("START TRANSACTION")
		if not add_rewards(db, user_id, hero_name, xp, fractals):
			db.executeCommand("ROLLBACK")
			write_response(response, 500, "reward transaction failed")
			return
		multiplayer = int(request_value(request, "squad_count", 1)) > 1
		db.executeCommand("INSERT INTO shso.leaderboard (UserID, MissionID, score, Hero, Multiplayer) VALUES (" + str(user_id) + ", '" + economy_service.sql_text(mission_id) + "', " + str(score) + ", '" + economy_service.sql_text(hero_name) + "', " + str(int(multiplayer)) + ")")
		db.executeCommand("DELETE FROM shso.active_missions WHERE UserID=" + str(user_id))
		db.executeCommand("COMMIT")
		write_response(response, 200, str(fractals) + "," + str(xp))
