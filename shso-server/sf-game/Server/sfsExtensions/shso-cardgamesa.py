# shso cardgamesa
#
# SmartFoxServer PRO extension for CardGameSA
import time
import sys
import random

sessions = {}


def init():
    global db
    global cmdMap
    cmdMap = {
        "ping": handlePing,
        "keepAlive": handleKeepAlive,
        "Ready": handleReady,
        "CardPicked": handleCardPicked,
        "FactorPicked": handleFactorPicked,
        "YesNoPicked": handleYesNoPicked,
        "NumberPicked": handleNumberPicked,
        "PickReady": handlePickReady,
        "Poke": handlePoke,
        "Debug": handleDebug
    }
    db = _server.getDatabaseManager()
    _server.trace("CardGameSA extension loaded")


def destroy():
    _server.trace("CardGameSA extension dying")


def _parse_deck_recipe(recipe):
    cards = []
    if recipe is None:
        return cards
    recipe = str(recipe)
    parts = recipe.split(";")
    for part in parts:
        if len(part) < 1:
            continue
        if ":" in part:
            cid, count = part.split(":", 1)
            try:
                count = int(count)
            except Exception:
                count = 1
            for _ in range(count):
                cards.append(cid)
        else:
            cards.append(part)
    return cards


def _get_room_users(roomId):
    zone = _server.getCurrentZone()
    room = zone.getRoom(roomId)
    if room is None:
        return []
    return room.getAllUsers()


def _send_cardsa(users, cmd, player_id, *args):
    payload = ["cardsa", "server", str(cmd), str(player_id)]
    for arg in args:
        payload.append(str(arg))
    _server.sendResponse(payload, -1, None, users, _server.PROTOCOL_STR)


def _iter_users(session):
    return [p.user for p in session.players.values() if p.user is not None]


def _send_per_user(session, cmd, player_id, args_builder):
    for p in session.players.values():
        if p.user is None:
            continue
        args = args_builder(p)
        _send_cardsa([p.user], cmd, player_id, *args)


def _send_init_cards(session, player_id, min_id, max_id):
    def _args(ps):
        mine = "true" if ps.player_id == player_id else "false"
        return [min_id, max_id, mine]
    _send_per_user(session, "InitCards", player_id, _args)


def _send_move_card(session, player_id, card_id, src, dest, card_type, visibility, src_opponent="false"):
    def _args(ps):
        mine = "true" if ps.player_id == player_id else "false"
        return [card_id, src, dest, mine, card_type, visibility, src_opponent]
    _send_per_user(session, "MoveCard", player_id, _args)


def _send_new_turn(session, player_id):
    def _args(ps):
        mine = "true" if ps.player_id == player_id else "false"
        return [mine]
    _send_per_user(session, "NewTurn", player_id, _args)


def _send_damage(session, defender_id, attack_card_id, casualties, src_deprecated, type_list, inflicted, attempted, become_keeper, kill_keeper):
    def _args(ps):
        mine = "true" if ps.player_id == defender_id else "false"
        return [attack_card_id, _join_list(casualties), src_deprecated, mine, _join_list(type_list), inflicted, attempted, become_keeper, kill_keeper]
    _send_per_user(session, "Damage", defender_id, _args)


def _send_poked(session, poked_player_id, timer_seconds):
    def _args(ps):
        is_local = "true" if ps.player_id == poked_player_id else "false"
        return [timer_seconds, is_local]
    _send_per_user(session, "Poked", poked_player_id, _args)


def _join_list(vals):
    if vals is None:
        return ""
    if len(vals) == 0:
        return ""
    return ";".join([str(v) for v in vals])


class PlayerState(object):
    def __init__(self, user, player_id, hero, deck_recipe, is_ai=False):
        self.user = user
        self.player_id = int(player_id)
        self.hero = hero
        self.deck_recipe = deck_recipe
        self.is_ai = is_ai
        self.stock = []
        self.hand = []
        self.played = []
        self.discard = []
        self.keepers = []


class CardInstance(object):
    def __init__(self, server_id, card_id):
        self.server_id = int(server_id)
        self.card_id = str(card_id)


class GameSession(object):
    def __init__(self, room_id):
        self.room_id = room_id
        self.players = {}
        self.cards = {}
        self.turn_offense = 0
        self.power_level = 1
        self.pending_pick = None
        self.attack_card_id = None
        self.defense_card_id = None

    def add_player(self, player_state):
        self.players[int(player_state.player_id)] = player_state

    def other_player_id(self, pid):
        return 1 if int(pid) == 0 else 0


# Handlers

def handleRequest(cmd, params, who, roomId, protocol):
    _server.trace("CardGameSA request: %s" % cmd)
    if cmd in cmdMap:
        cmdMap[cmd](params, who, roomId)


def handleInternalEvent(evt):
    _server.trace("CardGameSA internal event: %s" % evt.getEventName())


def handlePing(params, who, roomId):
    cliTime = params[0]
    srvTime = str(int(round(time.time())))
    response = ["ping", cliTime, srvTime]
    _server.sendResponse(response, -1, None, [who], _server.PROTOCOL_STR)


def handleKeepAlive(params, who, roomId):
    response = {"_cmd": "keepAlive"}
    _server.sendResponse(response, -1, None, [who])


def _ensure_session(roomId):
    if roomId not in sessions:
        sessions[roomId] = GameSession(roomId)
    return sessions[roomId]


def handleReady(params, who, roomId):
    # params: [playerId, deckRecipe, hero, questCond, questId, my_deck_code, hero_code, ai_deck, ai_deck_code, player_id]
    session = _ensure_session(roomId)
    users = _get_room_users(roomId)
    player_id = int(params[0])
    deck_recipe = params[1] if len(params) > 1 else ""
    hero = params[2] if len(params) > 2 else ""

    ps = PlayerState(who, player_id, hero, deck_recipe, False)
    session.add_player(ps)

    # If solo, create AI player
    if len(users) == 1 and 1 not in session.players:
        ai_deck = ""
        if len(params) > 7:
            ai_deck = params[7]
        if not ai_deck:
            ai_deck = deck_recipe
        ai_player = PlayerState(None, 1, "AI", ai_deck, True)
        session.add_player(ai_player)

    if len(session.players) < 2:
        return

    _initialize_game(session, users)


def _initialize_game(session, users):
    # Build decks
    for pid, player in session.players.items():
        deck = _parse_deck_recipe(player.deck_recipe)
        server_id = 0
        for cid in deck:
            ci = CardInstance(server_id, cid)
            session.cards[(pid, server_id)] = ci
            player.stock.append(server_id)
            server_id += 1
        random.shuffle(player.stock)

        # InitCards: min=0, max=deck-1, mine=true
        if len(player.stock) > 0:
            _send_init_cards(session, pid, 0, len(player.stock) - 1)

    # Deal initial hands (4 cards)
    for pid, player in session.players.items():
        for _ in range(4):
            if len(player.stock) == 0:
                break
            cid = player.stock.pop(0)
            player.hand.append(cid)
            cinst = session.cards[(pid, cid)]
            _send_move_card(session, pid, cid, 0, 1, cinst.card_id, 1, "false")

    # Coin flip / power level
    coin = random.random() < 0.5
    session.power_level = 1 if coin else 0
    for pid in session.players.keys():
        _send_cardsa(users, "SetPower", pid, session.power_level, str(coin).lower())

    # First turn
    session.turn_offense = 0
    _send_new_turn(session, session.turn_offense)
    _prompt_attack(session, users)


def _prompt_attack(session, users):
    pid = session.turn_offense
    player = session.players[pid]
    valid = list(player.hand)
    session.pending_pick = {
        "player_id": pid,
        "pick_type": "Attack",
        "valid": valid,
        "can_pass": True,
        "opposing": -1,
        "pass_button_id": 0
    }
    _send_cardsa(users, "PickCard", pid, _join_list(valid), "true", 0, -1, 0)
    if player.is_ai:
        _ai_pick(session, users)


def handleCardPicked(params, who, roomId):
    session = _ensure_session(roomId)
    users = _get_room_users(roomId)
    if session.pending_pick is None:
        return
    pid = int(params[0])
    card_id = params[1] if len(params) > 1 else ""
    pass_str = params[2] if len(params) > 2 else "false"
    do_pass = str(pass_str).lower() == "true"

    if pid != session.pending_pick["player_id"]:
        return

    pick_type = session.pending_pick["pick_type"]

    if do_pass:
        if pick_type == "Attack":
            session.turn_offense = pid
            _advance_turn(session, users)
            return
        elif pick_type == "Block":
            _resolve_damage(session, users, block_pass=True)
            return

    # Selected a card
    try:
        card_id = int(card_id)
    except Exception:
        return

    if card_id not in session.pending_pick["valid"]:
        return

    if pick_type == "Attack":
        _handle_attack_pick(session, users, pid, card_id)
        return

    if pick_type == "Block":
        _handle_block_pick(session, users, pid, card_id)
        return


def _handle_attack_pick(session, users, pid, card_id):
    player = session.players[pid]
    if card_id in player.hand:
        player.hand.remove(card_id)
        player.played.append(card_id)
    cinst = session.cards[(pid, card_id)]
    _send_move_card(session, pid, card_id, 1, 2, cinst.card_id, 1, "false")
    session.attack_card_id = card_id

    defender_id = session.other_player_id(pid)
    defender = session.players[defender_id]
    # Client-side rules decide what is truly valid; server allows all defender hand cards.
    valid_blocks = list(defender.hand)

    session.pending_pick = {
        "player_id": defender_id,
        "pick_type": "Block",
        "valid": valid_blocks,
        "can_pass": True,
        "opposing": card_id,
        "pass_button_id": 0
    }
    _send_cardsa(users, "PickCard", defender_id, _join_list(valid_blocks), "true", 1, card_id, 0)
    if defender.is_ai:
        _ai_pick(session, users)


def _handle_block_pick(session, users, pid, card_id):
    defender = session.players[pid]
    if card_id in defender.hand:
        defender.hand.remove(card_id)
        defender.played.append(card_id)
    bc = session.cards[(pid, card_id)]
    _send_move_card(session, pid, card_id, 1, 2, bc.card_id, 1, "false")
    _send_cardsa(users, "Block", pid, session.attack_card_id, card_id, "true")

    _end_turn_after_block(session, users)


def _resolve_damage(session, users, block_pass=False):
    defender_id = session.pending_pick["player_id"] if session.pending_pick else session.other_player_id(session.turn_offense)
    attacker_id = session.other_player_id(defender_id)
    defender = session.players[defender_id]

    # Server uses minimal damage; client-side rules/animations interpret results.
    damage = 1

    casualties = []
    type_list = []

    while damage > 0 and len(defender.stock) > 0:
        cid = defender.stock.pop(0)
        casualties.append(cid)
        type_list.append(session.cards[(defender_id, cid)].card_id)
        damage -= 1

    while damage > 0 and len(defender.hand) > 0:
        cid = defender.hand.pop(0)
        casualties.append(cid)
        type_list.append(session.cards[(defender_id, cid)].card_id)
        damage -= 1

    inflicted = len(casualties)
    attempted = 1

    _send_damage(session, defender_id, session.attack_card_id, casualties, 0, type_list, inflicted, attempted, "false", "false")
    _send_cardsa(users, "Info", defender_id, 142, 1, 0)

    # Move attack card to discard
    _end_turn_after_damage(session, users)


def _end_turn_after_block(session, users):
    attacker_id = session.other_player_id(session.pending_pick["player_id"])
    defender_id = session.pending_pick["player_id"]

    # move played cards to discard
    if session.attack_card_id is not None:
        attacker = session.players[attacker_id]
        if session.attack_card_id in attacker.played:
            attacker.played.remove(session.attack_card_id)
        _send_move_card(session, attacker_id, session.attack_card_id, 2, 5, session.cards[(attacker_id, session.attack_card_id)].card_id, 1, "false")
    if len(session.players[defender_id].played) > 0:
        dcid = session.players[defender_id].played.pop(0)
        _send_move_card(session, defender_id, dcid, 2, 5, session.cards[(defender_id, dcid)].card_id, 1, "false")

    _advance_turn(session, users)


def _end_turn_after_damage(session, users):
    attacker_id = session.other_player_id(session.pending_pick["player_id"])
    if session.attack_card_id is not None:
        attacker = session.players[attacker_id]
        if session.attack_card_id in attacker.played:
            attacker.played.remove(session.attack_card_id)
        _send_move_card(session, attacker_id, session.attack_card_id, 2, 5, session.cards[(attacker_id, session.attack_card_id)].card_id, 1, "false")

    # check game over
    for pid, p in session.players.items():
        if len(p.stock) == 0 and len(p.hand) == 0:
            winner = session.other_player_id(pid)
            _send_cardsa(users, "GameOver", winner, 0, "true")
            _send_cardsa(users, "GameOver", pid, 0, "false")
            session.pending_pick = None
            return

    _advance_turn(session, users)


def _advance_turn(session, users):
    session.turn_offense = session.other_player_id(session.turn_offense)
    # draw one card at start of turn
    player = session.players[session.turn_offense]
    if len(player.stock) > 0:
        cid = player.stock.pop(0)
        player.hand.append(cid)
        cinst = session.cards[(session.turn_offense, cid)]
        _send_move_card(session, session.turn_offense, cid, 0, 1, cinst.card_id, 1, "false")
    _send_new_turn(session, session.turn_offense)
    _prompt_attack(session, users)


def handleFactorPicked(params, who, roomId):
    # placeholder for future rule resolution
    pass


def handleYesNoPicked(params, who, roomId):
    # placeholder for future rule resolution
    pass


def handleNumberPicked(params, who, roomId):
    # placeholder for future rule resolution
    pass


def handlePickReady(params, who, roomId):
    # client indicates readiness; no-op for now
    pass


def handlePoke(params, who, roomId):
    session = _ensure_session(roomId)
    users = _get_room_users(roomId)
    poked_player_id = 0
    if params and len(params) > 0:
        try:
            poked_player_id = int(params[0])
        except Exception:
            poked_player_id = 0
    _send_poked(session, poked_player_id, 20)
    _send_cardsa(users, "PokeAppear", 0)


def handleDebug(params, who, roomId):
    _server.trace("CardGameSA Debug: %s" % str(params))


def _ai_pick(session, users):
    if session.pending_pick is None:
        return
    pid = session.pending_pick["player_id"]
    player = session.players[pid]
    if not player.is_ai:
        return
    valid = session.pending_pick["valid"]
    if len(valid) == 0:
        handleCardPicked([str(pid), "", "true"], None, session.room_id)
        return
    choice = valid[0]
    handleCardPicked([str(pid), str(choice), "false"], None, session.room_id)
