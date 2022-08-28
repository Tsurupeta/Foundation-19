#define DEBUG_C_ADDRESS "70.236.175.81"

GLOBAL_LIST_EMPTY(bccm_ip_cache)
/datum/bccm_info
	var/is_loaded = FALSE

	var/ip
	var/ip_as
	var/ip_mobile
	var/ip_proxy
	var/ip_hosting

/datum/bccm_info/New(_is_loaded, _ip, _ip_as, _ip_mobile, _ip_proxy, _ip_hosting)
	GLOB.bccm_ip_cache[ip] = src
	is_loaded = _is_loaded
	ip = _ip
	ip_as = _ip_as
	ip_mobile = _ip_mobile
	ip_proxy = _ip_proxy
	ip_hosting = _ip_hosting


SUBSYSTEM_DEF(bccm)
	name = "BCCM"
	init_order = SS_INIT_BCCM
	flags = SS_NO_FIRE

	var/max_error_count = 4

	var/is_active = FALSE
	var/error_counter = 0

	var/list/bccm_info

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
	log_debug("BCCM is [is_active ? "enabled" : "disabled"]!")
	return is_active

/datum/controller/subsystem/bccm/proc/CheckDBCon()
	if(is_active && SSdbcore.Connect())
		return TRUE

	is_active = FALSE
	log_and_message_admins("The Database Error has occured. BCCM is disabled.")
	return FALSE


/datum/controller/subsystem/bccm/proc/CollectIpData(ip_address, key)

	if(!DEBUG_C_ADDRESS || DEBUG_C_ADDRESS == "127.0.0.1")
		return

	var/list/response = LoadCachedData(DEBUG_C_ADDRESS)

	//Debug
	if(response)
		log_access("BCCM data for [key] ([DEBUG_C_ADDRESS]) is loaded from cache!")

	while(!response && is_active && error_counter < max_error_count)
		var/list/http = world.Export("http://ip-api.com/json/[DEBUG_C_ADDRESS]?fields=17025024")

		if(!http)
			log_and_message_admins("BCCM: API connection failed, could not check [key], retrying.")
			error_counter += 1
			sleep(2)
			continue

		var/raw_response = file2text(http["CONTENT"])

		try
			response = json_decode(raw_response)
		catch (var/exception/e)
			log_and_message_admins("BCCM: JSON decode error, could not check [key]. JSON decode error: [e.name]")
			return

		if(response["status"] == "fail")
			log_and_message_admins("BCCM: Request error, could not check [key]. CheckIP response: [response["message"]]")
			return

		log_access("BCCM data for [key] ([DEBUG_C_ADDRESS]) is loaded from external API!")
		CacheData(DEBUG_C_ADDRESS, raw_response)

	if(error_counter >= max_error_count && is_active)
		log_and_message_admins("BCCM was disabled due to connection errors!")
		is_active = FALSE
		return

	var/datum/bccm_info/info = new /datum/bccm_info(TRUE, ip_address, response["as"], response["mobile"], response["proxy"], response["hosting"])

	return info

/datum/controller/subsystem/bccm/proc/CheckForAccess(ip_address, key)
	if(!is_active)
		return TRUE

	if(!ip_address || !key)
		return TRUE

	if(CheckWhitelist(key))
		return TRUE

	var/datum/bccm_info/info = CollectIpData(ip_address, key)

	if(info.is_loaded)
		if(!info.ip_proxy && !info.ip_hosting)
			return TRUE
		return FALSE

	log_and_message_admins("BCCM failed to load info for [key].")
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

/datum/controller/subsystem/bccm/proc/AddToWhitelist(ckey, client/Admin)
	ASSERT(istype(Admin))

	if(!is_active)
		return FALSE

	if(!CheckDBCon())
		return FALSE

	var/datum/db_query/_Whitelist_Query = SSdbcore.NewQuery("INSERT INTO bccm_whitelist (`ckey`, `a_ckey`, `timestamp`) VALUES ('[ckey]', '[Admin.ckey]', Now())")
	_Whitelist_Query.Execute()
	qdel(_Whitelist_Query)

	log_and_message_admins("added [ckey] to BCCM whitelist.")

	return TRUE

/client/proc/BCCM_toggle()
	set category = "Server"
	set name = "Toggle BCCM"

	if(!SSdbcore.Connect())
		to_chat(usr, SPAN_NOTICE("The Database is not connected!"))
		return

	var/bccm_status = SSbccm.Toggle()
	log_and_message_admins("has [bccm_status ? "enabled" : "disabled"] the BCCM system!")
