// BCCM (Ban Counter Counter Measures system) ((Name subject to change)), originally inspired by EAMS (Epic Anti-Multiaccount System), by Epicus
//version 0.8.13

/datum/bccm_info
	var/is_loaded = FALSE
	var/is_whitelisted = FALSE

	var/ip
	var/ip_as
	var/ip_mobile
	var/ip_proxy
	var/ip_hosting

/client
	var/datum/bccm_info/bccm_info = new

SUBSYSTEM_DEF(bccm)
	name = "BCCM"
	init_order = SS_INIT_BCCM
	flags = SS_NO_FIRE

	var/max_error_count = 4

	var/is_active = FALSE
	var/error_counter = 0

	var/list/client/postponed_client_queue = new

/datum/controller/subsystem/bccm/Initialize(timeofday)
	if(!config.bccm)
		return ..()

	if(!sqlenabled)
		log_debug("BCCM could not be loaded without SQL enabled")
		return ..()

	Toggle()
	return ..()

/datum/controller/subsystem/bccm/stat_entry(msg)
	if(is_active)
		msg = "ACTIVE"
	else
		msg = "OFFLINE"
	return msg

/datum/controller/subsystem/bccm/proc/Toggle(mob/user)
	if (!initialized && user)
		return

	if(!is_active && !SSdbcore.Connect())
		log_debug("BCCM could not be loaded because the DB connection could not be established.")
		return

	is_active = !is_active
	log_debug("BCCM is [is_active ? "enabled" : "disabled"]!")
	if(is_active)
		var/list/clients_to_check = postponed_client_queue.Copy()
		postponed_client_queue.Cut()
		for (var/client/C in clients_to_check)
			CollectClientData(C)
			HandleClientAccessCheck(C, postponed = TRUE)
			HandleASNbanCheck(C, postponed = TRUE)
			CHECK_TICK
	return is_active

/datum/controller/subsystem/bccm/proc/CheckDBCon()
	if(is_active && SSdbcore.Connect())
		return TRUE

	is_active = FALSE
	log_and_message_admins("The Database Error has occured. BCCM is disabled.")
	return FALSE


/datum/controller/subsystem/bccm/proc/CollectClientData(client/C)
	ASSERT(istype(C))

	var/_ip_addr = C.address

	if(!is_active)
		postponed_client_queue.Add(C)
		return

	if(!CheckDBCon())
		return

	C.bccm_info.is_whitelisted = CheckWhitelist(C.ckey)

	if(!_ip_addr || _ip_addr == "127.0.0.1")
		return

	var/list/response = GetAPIresponse(_ip_addr, C)

	if(!response)
		return

	C.bccm_info.ip = _ip_addr
	C.bccm_info.ip_as = response["as"]
	C.bccm_info.ip_mobile = response["mobile"]
	C.bccm_info.ip_proxy = response["proxy"]
	C.bccm_info.ip_hosting = response["hosting"]

	C.bccm_info.is_loaded = TRUE
	return

/datum/controller/subsystem/bccm/proc/GetAPIresponse(ip, client/C = null)
	var/list/response = LoadCachedData(ip)

	if(response && C)
		log_access("BCCM data for [C] ([ip]) is loaded from cache!")

	while(!response && is_active && error_counter < max_error_count)
		var/list/http = world.Export("http://ip-api.com/json/[ip]?fields=17025024")

		if(!http)
			if(C)
				log_and_message_admins("BCCM: API connection failed, could not check [C], retrying.")
			else
				log_and_message_admins("BCCM: API connection failed, could not check [ip], retrying.")
			error_counter += 1
			sleep(2)
			continue

		var/raw_response = file2text(http["CONTENT"])

		try
			response = json_decode(raw_response)
		catch (var/exception/e)
			log_and_message_admins("BCCM: JSON decode error, could not check [C]. JSON decode error: [e.name]")
			return

		if(response["status"] == "fail")
			log_and_message_admins("BCCM: Request error, could not check [C]. CheckIP response: [response["message"]]")
			return

		if(C)
			log_access("BCCM data for [C]([ip]) is loaded from external API!")
		CacheData(ip, raw_response)

	if(error_counter >= max_error_count && is_active)
		log_and_message_admins("BCCM was disabled due to connection errors!")
		is_active = FALSE
		return

	return response

/datum/controller/subsystem/bccm/proc/CheckForAccess(client/C)
	ASSERT(istype(C))

	if(!is_active)
		return TRUE

	if(!CheckDBCon())
		return TRUE

	if(!C.address || C.holder)
		return TRUE

	if(C.bccm_info.is_whitelisted)
		return TRUE

	if(C.bccm_info.is_loaded)
		if(!C.bccm_info.ip_proxy && !C.bccm_info.ip_hosting)
			return TRUE
		return FALSE

	log_and_message_admins("BCCM failed to load info for [C.ckey].")
	return TRUE

/datum/controller/subsystem/bccm/proc/CheckWhitelist(ckey)
	. = FALSE

	if(!CheckDBCon())
		return

	var/datum/db_query/query = SSdbcore.NewQuery("SELECT ckey FROM bccm_whitelist WHERE ckey = '[ckey]'")
	query.Execute()

	if(query.NextRow())
		. = TRUE

	qdel(query)

	return

/datum/controller/subsystem/bccm/proc/CheckASNban(client/C)
	ASSERT(istype(C))

	. = TRUE

	if(!is_active)
		return

	if(!CheckDBCon())
		return

	var/datum/db_query/query = SSdbcore.NewQuery("SELECT `asn` FROM bccm_asn_ban WHERE asn = '[C.bccm_info.ip_as]'")
	query.Execute()

	if(query.NextRow())
		. = FALSE

	qdel(query)

	return

/datum/controller/subsystem/bccm/proc/LoadCachedData(ip)
	ASSERT(istext(ip))

	if(!CheckDBCon())
		return FALSE

	var/datum/db_query/_Cache_select_query = SSdbcore.NewQuery("SELECT response FROM bccm_ip_cache WHERE ip = '[ip]'")
	_Cache_select_query.Execute()

	if(!_Cache_select_query.NextRow())
		. = FALSE
	else
		. = json_decode(_Cache_select_query.item[1])

	qdel(_Cache_select_query)
	return

/datum/controller/subsystem/bccm/proc/CacheData(ip, raw_response)
	ASSERT(istext(ip))
	ASSERT(istext(raw_response))

	if(!CheckDBCon())
		return FALSE

	var/datum/db_query/_Cache_insert_query = SSdbcore.NewQuery("INSERT INTO bccm_ip_cache (`ip`, `response`) VALUES ('[ip]', '[raw_response]')")
	_Cache_insert_query.Execute()
	qdel(_Cache_insert_query)

	return TRUE

/datum/controller/subsystem/bccm/proc/AddToWhitelist(ckey, client/Admin)
	ASSERT(istype(Admin))

	if(!CheckDBCon())
		return FALSE

	var/datum/db_query/_Whitelist_Query = SSdbcore.NewQuery("INSERT INTO bccm_whitelist (`ckey`, `a_ckey`, `timestamp`) VALUES ('[ckey]', '[Admin.ckey]', Now())")
	_Whitelist_Query.Execute()
	qdel(_Whitelist_Query)

	log_and_message_admins("added [ckey] to BCCM whitelist.")

	return TRUE

/datum/controller/subsystem/bccm/proc/RemoveFromWhitelist(ckey)
	if(!CheckDBCon())
		return FALSE

	if(!CheckWhitelist(ckey))
		return

	var/datum/db_query/_Whitelist_Query = SSdbcore.NewQuery("DELETE FROM bccm_whitelist WHERE `ckey` = '[ckey]'")
	_Whitelist_Query.Execute()
	qdel(_Whitelist_Query)

	log_and_message_admins("removed [ckey] from BCCM whitelist.")

	return TRUE

/datum/controller/subsystem/bccm/proc/AddASNban(ip, client/Admin)
	if(!CheckDBCon())
		return

	var/list/response = GetAPIresponse(ip)

	var/ip_as = response["as"]

	var/datum/db_query/_ASban_Insert_Query = SSdbcore.NewQuery("INSERT INTO bccm_asn_ban (`asn`, `a_ckey`, `timestamp`) VALUES ('[ip_as]', '[Admin.ckey]', Now())")
	_ASban_Insert_Query.Execute()
	qdel(_ASban_Insert_Query)

	log_and_message_admins("has added '[ip_as]' to the BCCM ASN banlist.")


/datum/controller/subsystem/bccm/proc/HandleClientAccessCheck(client/C, postponed = 0)
	if(!SSbccm.CheckForAccess(C) && !(C.ckey in GLOB.admin_datums))
		if(!postponed)
			C.log_client_to_db_connection_log()
		log_and_message_admins(SPAN_NOTICE("BCCM: Failed Login: [C.key]/[C.ckey]([C.address])([C.computer_id]) failed to pass BCCM check."))
		qdel(C)
		return

/datum/controller/subsystem/bccm/proc/HandleASNbanCheck(client/C, postponed = 0)
	if(!SSbccm.CheckASNban(C) && !(C.ckey in GLOB.admin_datums))
		if(!postponed)
			C.log_client_to_db_connection_log()
		log_and_message_admins(SPAN_NOTICE("BCCM: Failed Login: [C.key]/[C.ckey]([C.address])([C.computer_id]) failed to pass ASN ban check."))
		qdel(C)
		return

/datum/controller/subsystem/bccm/Topic(href, href_list)

/datum/controller/subsystem/bccm/proc/WhitelistPanel(ckey = null, a_ckey = null)
	if(!usr.client)
		return

	if(!check_rights(R_BAN))
		return

	if(!SSdbcore.Connect())
		to_chat(usr, "<span class='warning'>Failed to establish database connection</span>")
		return

	var/output = "<!doctype html><html lang=\"en\"><head><meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\"><meta charset=\"utf-8\"><title>BCCM Whitelist panel</title><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><link rel=\"stylesheet\" href=\"https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css\"><link href=\"css/bootstrap-ie8.css\" rel=\"stylesheet\"><script src=\"https://cdn.jsdelivr.net/g/html5shiv@3.7.3\"></script><style>label{font-size: 16px;}h3{font-size: 20px;}</style></head>"

	output += "<div class=\"container\"><h3>BCCM Whitelist panel</h3>"
	output += "<form method='GET' action='?src=\ref[src]'>"
	output += "<input type='hidden' name='src' value='\ref[src]'>"
	output += "<table width='100%'><tr>"
	output += "<td width='65%'><div class=\"form-group\"><label for=\"bccmaddckey\">Ckey</label><input type='text' name='bccmaddckey'class=\"form-control form-control-sm\" id=\"bccmaddckey\"></div></td>"
	output += "<div class=\"row\"><div class=\"col-lg-3\"><input type='submit' class=\"btn btn-danger\" value='Add ban'></div></div></div></form>"



		dat += text("<tr><td><A href='?src=[ref];unbanf=[key][id]'>(U)</A><A href='?src=[ref];unbane=[key][id]'>(E)</A> Key: <B>[key]</B></td><td>ComputerID: <B>[id]</B></td><td>IP: <B>[ip]</B></td><td> [expiry]</td><td>(By: [by])</td><td>(Reason: [reason])</td></tr>")

	dat += "</table>"
	dat = "<HR><B>Bans:</B> <FONT COLOR=blue>(U) = Unban , (E) = Edit Ban</FONT> - <FONT COLOR=green>([count] Bans)</FONT><HR><table border=1 rules=all frame=void cellspacing=0 cellpadding=3 >[dat]"
	show_browser(usr, dat, "window=unbanp;size=875x400")

	if(ckey || a_ckey)
		output += "test"

	show_browser(usr, output,"window=bccmwhitelist;size=500x300")

/client/proc/BCCM_toggle()
	set category = "Server"
	set name = "Toggle BCCM"

	if(!SSdbcore.Connect())
		to_chat(usr, SPAN_NOTICE("The Database is not connected!"))
		return

	var/bccm_status = SSbccm.Toggle()
	log_and_message_admins("has [bccm_status ? "enabled" : "disabled"] the BCCM system!")

/client/proc/BCCM_whitelist()
	set category = "Server"
	set name = "Add to BCCM whitelist"

	if(!check_rights(R_BAN))
		return

	var/ckey_input = sql_sanitize_text(ckey(input("Add CKEY to BCCM whitelist")))
	if(ckey_input && istext(ckey_input))
		SSbccm.AddToWhitelist(ckey_input, src)

/client/proc/BCCM_ASNban()
	set category = "Server"
	set name = "Add ASN ban"

	if(!check_rights(R_SERVER) || !check_rights(R_BAN))
		return

	var/ip_input = sql_sanitize_text(input("Input IP address, ASN provider of which you want to ban."))
	if(ip_input && istext(ip_input))
		SSbccm.AddASNban(ip_input, src)

/client/proc/BCCM_WhitelistPanel()
	set category = "Server"
	set name = "BCCM WL Panel"

	SSbccm.WhitelistPanel()
