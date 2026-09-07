import sys
from javax.servlet.http import HttpServlet
import it.gotoandplay.smartfoxserver.extensions.ExtensionHelper
ex = it.gotoandplay.smartfoxserver.extensions.ExtensionHelper.instance()

sys.path.append('/sfs/Server/webserver/webapps/root/pylibcsp')
import pylibcsp
import economy_service


class currency(HttpServlet):
	def doGet(self, request, response):
		pass

	def doPost(self, request, response):
		if pylibcsp.ipcheck(False):
			return
		db = ex.getZone('shs.all').dbManager
		session_token = None
		for name in request.getParameterNames():
			if name == "AS_SESSION_KEY":
				session_token = request.getParameter(name)
		user_id = economy_service.token_user(db, session_token)
		balances = None
		if user_id is not None:
			balances = economy_service.user_balances(db, user_id, 0)
		w = response.getWriter()
		w.println("<response>")
		if balances is None:
			w.println("  <status>400</status><headers></headers><body>invalid session</body>")
		else:
			w.println("  <status>200</status>")
			w.println("  <headers><Content-Type>text/html; charset=utf-8</Content-Type></headers>")
			w.println("  <body>")
			w.println("  &lt;currency&gt;")
			w.println("    &lt;tokens&gt;2&lt;/tokens&gt;")
			w.println("    &lt;coins&gt;" + str(balances["gold"]) + "&lt;/coins&gt;")
			w.println("    &lt;tickets&gt;2&lt;/tickets&gt;")
			w.println("    &lt;shards&gt;" + str(balances["fractals"]) + "&lt;/shards&gt;")
			w.println("  &lt;/currency&gt;")
			w.println("  </body>")
		w.println("</response>")
		w.close()
