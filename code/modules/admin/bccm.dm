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

	var/list/client/client_queue = new

/datum/controller/subsystem/bccm/Initialize(timeofday)
	if(!config.bccm)
		return ..()

	if(!sqlenabled)
		log_debug("BCCM could not be loaded without SQL enabled")
		return ..()

	Toggle()
	return ..()

/datum/controller/subsystem/bccm/proc/Toggle(mob/user)
	if (!initialized && user)
		return

	if(!is_active && !SSdbcore.Connect())
		log_debug("BCCM could not be loaded because the DB connection could not be established.")
		return

	is_active = !is_active
	if(is_active)
		var/list/clients_to_check = client_queue.Copy()
		client_queue.Cut()
		for (var/client/C in clients_to_check)
			CollectClientData(C)
			CHECK_TICK
	log_debug("BCCM is [is_active ? "enabled" : "disabled"]!")
	return is_active

/datum/controller/subsystem/bccm/proc/CheckDBCon()
	if(is_active && SSdbcore.Connect())
		return TRUE

	is_active = FALSE
	log_and_message_admins("The Database Error has occured. BCCM is disabled.")
	return FALSE


/datum/controller/subsystem/bccm/proc/CollectClientData(client/C)
	ASSERT(istype(C))

	if(!is_active)
		client_queue.Add(C)
		return

	C.bccm_info.is_whitelisted = CheckWhitelist(C)

	if(!C.address || C.address == "127.0.0.1")
		return

	var/list/response = LoadCachedData(C.address)

	//Debug
	if(response)
		log_access("BCCM data for [C] ([C.address]) is loaded from cache!")

	while(!response && is_active && error_counter < max_error_count)
		var/list/http = world.Export("http://ip-api.com/json/[C.address]?fields=17025024")

		if(!http)
			log_and_message_admins("BCCM: API connection failed, could not check [C.key], retrying.")
			error_counter += 1
			sleep(2)
			continue

		var/raw_response = file2text(http["CONTENT"])

		try
			response = json_decode(raw_response)
		catch (var/exception/e)
			log_and_message_admins("BCCM: JSON decode error, could not check [C.key]. JSON decode error: [e.name]")
			return

		if(response["status"] == "fail")
			log_and_message_admins("BCCM: Request error, could not check [C.key]. CheckIP response: [response["message"]]")
			return

		log_access("BCCM data for [C] ([C.address]) is loaded from external API!")
		CacheData(C.address, raw_response)

	if(error_counter >= max_error_count && is_active)
		log_and_message_admins("BCCM was disabled due to connection errors!")
		is_active = FALSE
		return


	C.bccm_info.ip = C.address
	C.bccm_info.ip_as = response["as"]
	C.bccm_info.ip_mobile = response["mobile"]
	C.bccm_info.ip_proxy = response["proxy"]
	C.bccm_info.ip_proxy = response["hosting"]

	C.bccm_info.is_loaded = TRUE
	return

/datum/controller/subsystem/bccm/proc/CheckForAccess(client/C)
	ASSERT(istype(C))
	if(!is_active)
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

/datum/controller/subsystem/bccm/proc/CheckWhitelist(client/C)
	ASSERT(istype(C))

	if(!CheckDBCon())
		return FALSE

	var/datum/db_query/query = SSdbcore.NewQuery("SELECT ckey FROM bccm_whitelist_ckey WHERE ckey = '[C.ckey] LIMIT 0,1")
	query.Execute()

/datum/controller/subsystem/bccm/proc/LoadCachedData(ip)
	ASSERT(istext(ip))

	if(!CheckDBCon())
		return FALSE

	var/datum/db_query/_Cache_select_query = SSdbcore.NewQuery("SELECT response FROM bccm_ip_cache WHERE ip = '[ip]' LIMIT 1")
	_Cache_select_query.Execute()
	qdel(_Cache_select_query)

	if(!_Cache_select_query.NextRow())
		return FALSE

	return json_decode(_Cache_select_query.item[1])

/datum/controller/subsystem/bccm/proc/CacheData(ip, raw_response)
	ASSERT(istext(ip))
	ASSERT(istext(raw_response))

	if(!CheckDBCon())
		return FALSE

	var/datum/db_query/_Cache_insert_query = SSdbcore.NewQuery("INSERT INTO bccm_ip_cache (`ip`, `response`) VALUES [ip], [raw_response]")
	_Cache_insert_query.Execute()
	qdel(_Cache_insert_query)

	return TRUE

/client/proc/BCCM_toggle()
	set category = "Server"
	set name = "Toggle BCCM"

	if(!SSdbcore.Connect())
		to_chat(usr, SPAN_NOTICE("The Database is not connected!"))
		return

	var/bccm_status = SSbccm.Toggle()
	log_and_message_admins("has [bccm_status ? "enabled" : "disabled"] the BCCM system!")
