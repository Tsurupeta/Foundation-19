/client/proc/BCCM_ASNPanel()
	set category = "Server"
	set name = "BCCM ASN Panel"

	if(!check_rights(R_BAN))
		return
	/*
	if(!SSdbcore.Connect())
		to_chat(usr, SPAN_WARNING("Failed to establish database connection"))
		return
	*/

	new /datum/bccm_asn_panel(src)

/datum/bccm_asn_panel
	var/client/holder // client of who is holding this

/datum/bccm_asn_panel/New(user)
	if(user)
		setup(user)
	else
		qdel(src)
		return

/datum/bccm_asn_panel/proc/setup(user) // client or mob
	if(istype(user, /client))
		var/client/user_client = user
		holder = user_client
	else
		var/mob/user_mob = user
		holder = user_mob.client

	if(!check_rights(R_BAN, TRUE, holder))
		qdel(src)
		return
	/*
	if(!SSdbcore.Connect())
		to_chat(holder, SPAN_WARNING("Failed to establish database connection"))
		qdel(src)
		return
	*/

	tgui_interact(holder.mob)

/datum/bccm_asn_panel/tgui_state(mob/user)
	return GLOB.admin_tgui_state // admin only

/datum/bccm_asn_panel/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BCCMASNPanel")
		ui.open()

/proc/get_bccm_asn_panel_example_data()
	. = list()
	.["displayData"] = list(
		list("a_ckey" =  "vonam3d", "timestamp" = "2022-09-01 16:34:48", "asn" = "AS7922 Comcast Cable Communications, LLC"),
		list("a_ckey" =  "vonam3d", "timestamp" = "2022-09-01 16:34:48", "asn" = "AS7922 Comcast Cable Communications, LLC"),
		list("a_ckey" =  "vonam3d", "timestamp" = "2022-09-01 16:34:48", "asn" = "AS7922 Comcast Cable Communications, LLC"),
		list("a_ckey" =  "vonam3d", "timestamp" = "2022-09-01 16:34:48", "asn" = "AS7922 Comcast Cable Communications, LLC"),
		list("a_ckey" =  "vonam3d", "timestamp" = "2022-09-01 16:34:48", "asn" = "AS7922 Comcast Cable Communications, LLC"),
		list("a_ckey" =  "vonam3d", "timestamp" = "2022-09-01 16:34:48", "asn" = "AS7922 Comcast Cable Communications, LLC"),
		list("a_ckey" =  "vonam3d", "timestamp" = "2022-09-01 16:34:48", "asn" = "AS7922 Comcast Cable Communications, LLC"),
		list("a_ckey" =  "vonam3d", "timestamp" = "2022-09-01 16:34:48", "asn" = "AS7922 Comcast Cable Communications, LLC"),
		list("a_ckey" =  "vonam3d", "timestamp" = "2022-09-01 16:34:48", "asn" = "AS7922 Comcast Cable Communications, LLC")
	)

/datum/bccm_asn_panel/tgui_data(mob/user, ui_key)
	. = get_bccm_asn_panel_example_data()


/datum/bccm_asn_panel/tgui_act(action, list/params, datum/tgui/ui, datum/tgui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("asn_remove_entry")
			if(!params["asn"])
				return TRUE
			// you get params["asn"] and params["timestamp"]
			to_chat(world, "[action] called with asn: [params["asn"]] and ts: [params["timestamp"]]")
		if("asn_add_entry")
			if(!params["asn"])
				return TRUE
			// you get params["asn"]
			to_chat(world, "[action] called with asn: [params["asn"]]")


	SStgui.update_user_uis(holder.mob)
	return TRUE

/datum/bccm_asn_panel/tgui_close(mob/user)
	qdel(src)
