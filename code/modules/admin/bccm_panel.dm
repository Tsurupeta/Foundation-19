/client/proc/BCCM_WhitelistPanel()
	set category = "Server"
	set name = "BCCM WL Panel"

	new /datum/bccm_wl_panel(src)

/datum/bccm_wl_panel
	var/client/holder // client of who is holding this

/datum/bccm_wl_panel/New(user)
	if(user)
		setup(user)

/datum/bccm_wl_panel/proc/setup(user) // client or mob
	if(istype(user, /client))
		var/client/user_client = user
		holder = user_client
	else
		var/mob/user_mob = user
		holder = user_mob.client

	tgui_interact(holder.mob)

/datum/bccm_wl_panel/tgui_state(mob/user)
	return GLOB.admin_tgui_state // admin only

/datum/bccm_wl_panel/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BCCMWhitelistPanel")
		ui.open()

/proc/get_bccm_wl_panel_example_data()
	. = list()
	.["displayData"] = list(
		list("ckey" = "JohnBidne", "timestamp" = "2022-03-14 13:43:22", "a_ckey" = "vastspace01344"),
		list("ckey" = "JohnBidet", "timestamp" = "2022-07-07 16:24:11", "a_ckey" = "voidshiki"),
		list("ckey" = "JohnBidnet", "timestamp" = "2022-03-14 13:43:22", "a_ckey" = "vastspace01344"),
		list("ckey" = "JohnBidett", "timestamp" = "2022-07-07 16:24:11", "a_ckey" = "voidshiki"),
		list("ckey" = "JohnBidnette", "timestamp" = "2022-03-14 13:43:22", "a_ckey" = "vastspace01344"),
		list("ckey" = "JohnBidetttet", "timestamp" = "2022-07-07 16:24:11", "a_ckey" = "voidshiki"),
		list("ckey" = "MACIEKBAKI1", "timestamp" = "2022-09-01 16:34:48", "a_ckey" = "MACIEKBAKI"),
		list("ckey" = "MACIEKBAKI2", "timestamp" = "2022-09-01 16:34:48", "a_ckey" = "MACIEKBAKI"),
		list("ckey" = "JohnBidnettettete", "timestamp" = "2022-03-14 13:43:22", "a_ckey" = "vastspace01344"),
		list("ckey" = "JohnBidetete", "timestamp" = "2022-07-07 16:24:11", "a_ckey" = "voidshiki"),
		list("ckey" = "JohnBidno", "timestamp" = "2022-03-14 13:43:22", "a_ckey" = "vastspace01344"),
		list("ckey" = "JohnBidetoto", "timestamp" = "2022-07-07 16:24:11", "a_ckey" = "voidshiki"),
		list("ckey" = "JohnBidneot", "timestamp" = "2022-03-14 13:43:22", "a_ckey" = "vastspace01344"),
		list("ckey" = "JohnBidettott0", "timestamp" = "2022-07-07 16:24:11", "a_ckey" = "voidshiki"),
		list("ckey" = "MACIEKBAKI3", "timestamp" = "2022-09-01 16:34:48", "a_ckey" = "MACIEKBAKI"),
		list("ckey" = "JohnBidnee", "timestamp" = "2022-03-14 13:43:22", "a_ckey" = "vastspace01344"),
		list("ckey" = "JohnBidetee", "timestamp" = "2022-07-07 16:24:11", "a_ckey" = "voidshiki"),
		list("ckey" = "JohnBidneeee", "timestamp" = "2022-03-14 13:43:22", "a_ckey" = "vastspace01344"),
		list("ckey" = "JohnBideteeee", "timestamp" = "2022-07-07 16:24:11", "a_ckey" = "voidshiki"),
		list("ckey" = "JohnBidneeeeee", "timestamp" = "2022-03-14 13:43:22", "a_ckey" = "vastspace01344"),
		list("ckey" = "JohnBidettetetetet", "timestamp" = "2022-07-07 16:24:11", "a_ckey" = "voidshiki"),
		list("ckey" = "MACIEKBAKI4", "timestamp" = "2022-09-01 16:34:48", "a_ckey" = "MACIEKBAKI")
	)

/datum/bccm_wl_panel/tgui_data(mob/user, ui_key)
	. = get_bccm_wl_panel_example_data()


/datum/bccm_wl_panel/tgui_act(action, list/params, datum/tgui/ui, datum/tgui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("wl_remove_entry")
			if(!params["ckey"])
				return TRUE
			// you get params["ckey"]
			to_chat(world, "[action] called with ckey: [params["ckey"]]")
		if("wl_add_ckey")
			if(!params["ckey"])
				return TRUE
			// you get params["ckey"]
			to_chat(world, "[action] called with ckey: [params["ckey"]]")


	SStgui.update_user_uis(holder.mob)
	return TRUE

/datum/bccm_wl_panel/tgui_close(mob/user)
	qdel(src)
