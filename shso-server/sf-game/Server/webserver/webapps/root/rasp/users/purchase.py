import sys
from javax.servlet.http import HttpServlet
import it.gotoandplay.smartfoxserver.extensions.ExtensionHelper
ex = it.gotoandplay.smartfoxserver.extensions.ExtensionHelper.instance()

sys.path.append('/sfs/Server/webserver/webapps/root/pylibcsp')
import pylibcsp
import economy_config
import economy_service


def request_value(request, wanted):
	for name in request.getParameterNames():
		if name == wanted:
			return request.getParameter(name)
	return None


def write_response(response, status, body):
	w = response.getWriter()
	w.println("<response>")
	w.println("  <status>" + str(status) + "</status>")
	w.println("  <headers><Content-Type>text/html; charset=utf-8</Content-Type></headers>")
	w.println("  <body>" + str(body) + "</body>")
	w.println("</response>")
	w.close()


class purchase(HttpServlet):
	def doGet(self, request, response):
		pass

	def doPost(self, request, response):
		if pylibcsp.ipcheck(False):
			return
		db = ex.getZone('shs.all').dbManager
		session_token = request_value(request, "AS_SESSION_KEY")
		catalog_id = request_value(request, "catalog_ownable_id")
		use_shards = request_value(request, "useShards")
		guid = request_value(request, "guid")
		if guid is None:
			guid = ""
		user_id = economy_service.token_user(db, session_token)
		if user_id is None or catalog_id is None or not str(catalog_id).isdigit():
			write_response(response, 400, "invalid purchase request")
			return

		catalog = db.executeQuery("SELECT name, category, price, shard_price, price_multiplier, subscriber_only, visible, ownable_type_id FROM shso.catalog WHERE catalog_ownable_id=" + str(catalog_id) + " LIMIT 1")
		if catalog is None or catalog.size() == 0:
			write_response(response, 404, "catalog item not found")
			return
		item = catalog[0]
		name = str(item.getItem("name"))
		category = str(item.getItem("category"))
		if economy_config.CONTENT_POLICY["respect_catalog_visibility"] and int(item.getItem("visible")) == 0:
			write_response(response, 403, "catalog item is locked")
			return
		gold_price, fractal_price = economy_config.resolve_catalog_prices(
			name, category, item.getItem("price"), item.getItem("shard_price"), item.getItem("price_multiplier"))
		pay_with_fractals = str(use_shards).lower() in ("1", "true", "yes")
		currency_column = "Gold"
		price = gold_price
		if pay_with_fractals:
			currency_column = "Fractals"
			price = fractal_price
		if price < 0 or (price == 0 and not economy_config.CATALOG_PRICING["allow_zero_price_purchases"]):
			write_response(response, 400, "item is unavailable in the selected currency")
			return
		if category in ("badge", "craft", "bundle"):
			write_response(response, 400, "this catalog category is not implemented")
			return

		db.executeCommand("START TRANSACTION")
		balances = economy_service.user_balances(db, user_id, 1)
		if balances is None:
			db.executeCommand("ROLLBACK")
			write_response(response, 400, "player account not found")
			return
		if economy_config.CONTENT_POLICY["respect_agent_restrictions"] and int(item.getItem("subscriber_only")) > 0 and not economy_config.is_agent(balances["paid"]):
			db.executeCommand("ROLLBACK")
			write_response(response, 403, "Jr. S.H.I.E.L.D. Agent membership required")
			return
		balance_key = "gold"
		if pay_with_fractals:
			balance_key = "fractals"
		if balances[balance_key] < price:
			db.executeCommand("ROLLBACK")
			write_response(response, 400, "not enough " + currency_column.lower())
			return

		grant_sql = ""
		if category == "h":
			owned = db.executeQuery("SELECT 1 FROM shso.heroes WHERE UserID=" + str(user_id) + " AND Name='" + economy_service.sql_text(name) + "' LIMIT 1")
			if owned is not None and owned.size() > 0:
				db.executeCommand("ROLLBACK")
				write_response(response, 409, "hero already owned")
				return
			grant_sql = "INSERT INTO shso.heroes (UserID, Name) VALUES (" + str(user_id) + ", '" + economy_service.sql_text(name) + "')"
		else:
			if category == "m":
				owned = db.executeQuery("SELECT 1 FROM shso.inventory WHERE UserID=" + str(user_id) + " AND type=" + str(item.getItem("ownable_type_id")) + " AND category='m' LIMIT 1")
				if owned is not None and owned.size() > 0:
					db.executeCommand("ROLLBACK")
					write_response(response, 409, "mission already owned")
					return
			grant_sql = "INSERT INTO shso.inventory (UserID, type, category, subscriber_only) VALUES (" + str(user_id) + ", " + str(item.getItem("ownable_type_id")) + ", '" + economy_service.sql_text(category) + "', " + str(item.getItem("subscriber_only")) + ") ON DUPLICATE KEY UPDATE quantity=quantity+1"

		new_balance = balances[balance_key] - price
		debit_sql = "UPDATE shso.user SET " + currency_column + "=" + str(new_balance) + " WHERE ID=" + str(user_id) + " AND " + currency_column + ">=" + str(price)
		if not db.executeCommand(debit_sql) or not db.executeCommand(grant_sql):
			db.executeCommand("ROLLBACK")
			write_response(response, 500, "purchase transaction failed")
			return
		db.executeCommand("COMMIT")

		economy_service.queue_notification(db, user_id, "catalog_purchase_complete", guid, "true", "success", None)
		if not pay_with_fractals:
			economy_service.queue_notification(db, user_id, "gold_balance_update", guid, "true", "success", new_balance)
		# The recovered client currently parses this body as a Fractal balance.
		# Return the unchanged Fractal balance for Gold purchases; the Gold value
		# arrives through gold_balance_update above.
		response_balance = new_balance
		if not pay_with_fractals:
			response_balance = balances["fractals"]
		write_response(response, 200, response_balance)
