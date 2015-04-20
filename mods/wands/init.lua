local file = io.open(minetest.get_worldpath() .. "/wands", "r")
if (file) then
	print "reading wands..."
	wands = minetest.deserialize(file:read("*all"))
	file:close()
end
wands = wands or { }
wands.spells = { }
wands.unlocked_spells = wands.unlocked_spells or { }
wands.selected_spells = wands.selected_spells or { }
wands.formspec_lists = {}


-- registeres a spell with the name name
-- name should follow the naming conventions modname:spellname
--
-- spellspec is a table of the format:
-- { title       = "the visible name of the spell",
--   description = "a small description of the spell",
--   type        = "nothing" for yourself, "node" for the environment or "object" for objects, see pointed_thing,
--   cost        = amount of mana to get consumend
--   func        = function(player, pointed_thing) function to get called.
-- }
function wands.register_spell(name, spellspec)
	if (wands.spells[name] ~= nil) then
		print "There is already a spell with this name."
		return false
	end
	wands.spells[name] = {  title = spellspec.title or "missing title",
				description = spellspec.description or "missing description",
				type = spellspec.type,
				cost = spellspec.cost or 0,
				func = spellspec.func or nil }
end

-- unlocks the spell spell for the player playername
function wands.unlock_spell(playername, spell) 
	wands.unlocked_spells[playername] = wands.unlocked_spells[playername] or { }
	wands.unlocked_spells[playername][spell] = true
end

-- locks the spell spell for the player playername
function wands.lock_spell(playername, spell) 
	wands.unlocked_spells[playername] = wands.unlocked_spells[playername] or { }
	wands.unlocked_spells[playername][spell] = nil
end

-- test whether spell is unlocked for playername
function wands.is_unlocked(playername, spell) 
	if (wands.unlocked_spells[playername] ~= nil and wands.unlocked_spells[playername][spell]) then
		return true
	end
	return false
end

minetest.register_on_shutdown(function()
	print "writing wands..."
	local file = io.open(minetest.get_worldpath() .. "/wands", "w")
	if (file) then
		file:write(minetest.serialize({ selected_spells = wands.selected_spells,
						unlocked_spells = wands.unlocked_spells}))
		file:close()
	end
end)




-- register the wand
function wands.register_wand(wandname, wanddef)
	wanddef.image = wanddef.image or "wands_wand.png"
	wanddef.mana_multiplier = wanddef.mana_multiplier or 1
	wanddef.range = wanddef.range or 20
	wanddef.uses = wanddef.uses or 100

	local use = function(itemstack, user, pointed_thing)
		local playername = user:get_player_name()
		if (not playername) then
			return itemstack
		end
		if (not(wands.selected_spells[playername]) or not(wands.selected_spells[playername].list)) then
			return itemstack
		end
		local selected = tonumber(itemstack:get_metadata()) or 1
		if (not wands.selected_spells[playername].list[selected] or wands.spells[wands.selected_spells[playername].list[selected]] == nil) then
			return itemstack
		end
		if (not wands.unlocked_spells[playername][wands.selected_spells[playername].list[selected]]) then
			return
		end
		if (pointed_thing.type == wands.spells[wands.selected_spells[playername].list[selected]].type or wands.spells[wands.selected_spells[playername].list[selected]].type == "anything") then
			if (wands.spells[wands.selected_spells[playername].list[selected]].func ~= nil) then
				if (mana.subtract(playername, wands.spells[wands.selected_spells[playername].list[selected]].cost * wanddef.mana_multiplier)) then
					if (wands.spells[wands.selected_spells[playername].list[selected]].func(user, pointed_thing)) then
						if (wanddef.uses > 0) then
							itemstack:add_wear(math.ceil(65534 / wanddef.uses))
						end
					else
						mana.add_up_to(playername, wands.spells[wands.selected_spells[playername].list[selected]].cost * wanddef.mana_multiplier)
					end
				end
			end
		end
		return itemstack
	end
	local place = function(itemstack, placer, pointed_thing)
		local playername = placer:get_player_name()
		if (not playername) then
			return itemstack
		end
		if (not wands.selected_spells[playername] or not wands.selected_spells[playername].list) then
			return itemstack
		end
		local selected = tonumber(itemstack:get_metadata()) or 1
		selected = selected + 1
		if (selected > 5 or selected > #wands.selected_spells[playername].list) then
			selected = 1
		end
		itemstack:set_name(wandname.. "_" ..selected)
		itemstack:set_metadata(selected)
		return itemstack
	end

	for i = 1,5 do
		minetest.register_tool(wandname .. "_" ..i, {
			description = wanddef.description,
			inventory_image = wanddef.image .. "^wands_"..i..".png",
			wield_image = wanddef.image,
			stack_max = 1,
			range = wanddef.range,
			on_use = use,
			on_place = place
		})
	end
end

-- register some wands
wands.register_wand("wands:wand_normal", {uses = 100, range=20, mana_multiplier=1,
						image = "wands_normal_wand.png",
						description = "A medium strength wand"})
minetest.register_craftitem("wands:orb_normal", {
	description = "Core of a normal wand",
	inventory_image = "wands_normal_orb.png"
})
minetest.register_craft({
	output = "wands:orb_normal",
	recipe = {
		{"",				"default:esem_crystal_fragment", 	""},
		{"default:esem_crystal_fragment", "default:diamond", "default:esem_crystal_fragment" },
		{"",		"default:esem_crystal_fragment", 		""}
	}
})
minetest.register_craft({
	output = "wands:wand_normal_1",
	recipe = {
		{"group:stick",	"wands:orb_normal", 	"group:stick"},
		{"",		"group:stick", 		""},
		{"",		"group:stick", 		""}
	}
})

wands.register_wand("wands:wand_apprentice", {uses = 50, range=15, mana_multiplier=2,
						image = "wands_apprentice_wand.png",
						description = "Apprentice wand: Breaks fast, uses uch mana"})
minetest.register_craftitem("wands:orb_apprentice", {
	description = "Core of an apprentice wand",
	inventory_image = "wands_apprentice_orb.png"
})
minetest.register_craft({
	output = "wands:orb_apprentice",
	recipe = {
		{"",				"default:esem_crystal_fragment", 	""},
		{"default:esem_crystal_fragment", "default:gold_lump", "default:esem_crystal_fragment" },
		{"",		"default:esem_crystal_fragment", 		""}
	}
})
minetest.register_craft({
	output = "wands:wand_apprentice_1",
	recipe = {
		{"group:stick",	"wands:orb_apprentice",	"group:stick"},
		{"",		"group:stick", 		""},
		{"",		"group:stick", 		""}
	}
})



local function unlocker_formspec(playername) 
	local formspec = "size[10,10]"
	local x, y = 0, 0
	for spellname,spec in pairs(wands.spells) do
		formspec = formspec .. "button["..x..","..y..";3,1;"..spellname..";"
		if (wands.is_unlocked(playername, spellname)) then
			formspec = formspec .."lock "
		else
			formspec = formspec .. "unlock "
		end
		formspec = formspec ..spec.title.."]"
		y = y + 1
		if (y >= 10) then
			y = 0
			x = x + 3
		end
	end
	minetest.show_formspec(playername, "spells_unlocker", formspec)
end

minetest.register_node("wands:unlocker", {
	tiles = {"default_stone.png^wands_wand.png"},
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if (clicker == nil and not clicker:is_player()) then
			return itemstack
		end
		local playername = clicker:get_player_name()
		if (not playername) then
			return itemstack
		end
		unlocker_formspec(playername)
		return itemstack
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fieldname)
	if (formname == "spells_unlocker") then
		if (player == nil) then
			return
		end
		local playername = player:get_player_name()
		for spell,_ in pairs(fieldname) do
			if (wands.is_unlocked(playername, spell)) then
				wands.lock_spell(playername, spell)
			else
				wands.unlock_spell(playername, spell)
			end
		end
		if (not fieldname["exit"]) then
			unlocker_formspec(playername)
		end
	end
end)

local function spelllist(playername, uidx, sidx) 
	local formspec = "size[7.5,8]" ..
			 "label[.25,0;known spells:]" .. 
			 "textlist[.25,.5;3,7;known_spells;"
	if (wands.unlocked_spells[playername] == nil) then
		wands.unlocked_spells[playername] = {}
	end
	local unlocked_list = {}
	local has_unlocked_spells = false
	for spell,_ in pairs(wands.unlocked_spells[playername]) do
		if (wands.spells[spell] ~= nil) then
			formspec = formspec .. wands.spells[spell].title .. ","
			table.insert(unlocked_list, spell)
			has_unlocked_spells = true
		end
	end
	print(has_unlocked_spells)
	if (has_unlocked_spells) then
		formspec = string.sub(formspec, 1, -2)
	end
	formspec = formspec .. ";" .. (uidx or 1) .. "]" ..
			 "label[4.25,0;selected spells:]" .. 
			"textlist[4.25,.5;3,7;selected_spells;"
	if (wands.selected_spells[playername] == nil) then
		wands.selected_spells[playername] = { list = { } }
	end
	local selected_list = {}
	for _,spell in ipairs(wands.selected_spells[playername].list) do
		formspec = formspec .. (wands.spells[spell] or {title = "unknown"}).title .. ","
		table.insert(selected_list, spell)
	end
	formspec = formspec .. ";" .. (sidx or 1) .. "]"

	formspec = formspec .. "button[3.35,2;1,.6;add_spell;+]" ..
			       "button[3.35,4;1,.6;remove_spell;-]"
	wands.formspec_lists[playername] = { unlocked_spells = unlocked_list,
					     unlocked_idx    = uidx or 1,
					     selected_spells = selected_list,
					     selected_idx    = sidx or 1 }

	return formspec
end

-- register the spellbook
minetest.register_tool("wands:spellbook", {
	description = "A book filled with spells",
	inventory_image = "wands_spellbook.png",
	stack_max = 1,
	on_use = function(itemstack, user, pointed_thing) 
		local playername = user:get_player_name()
		if (not playername) then
			return itemstack
		end
		minetest.show_formspec(playername, "wands:spelllist", spelllist(playername))
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local playername = player:get_player_name()
	if (formname == "wands:spelllist") then
		if (fields["add_spell"]) then
			wands.selected_spells[playername] = wands.selected_spells[playername] or { list = { } }
			if (#wands.selected_spells[playername].list < 5) then
				table.insert(wands.selected_spells[playername].list, wands.formspec_lists[playername].unlocked_spells[wands.formspec_lists[playername].unlocked_idx]) 
			end
			minetest.show_formspec(playername, "wands:spelllist", spelllist(playername, wands.formspec_lists[playername].unlocked_idx, wands.formspec_lists[playername].selected_idx))
			return
		end
		if (fields["remove_spell"]) then
			wands.selected_spells[playername] = wands.selected_spells[playername] or { list = { } }
			table.remove(wands.selected_spells[playername].list,wands.formspec_lists[playername].selected_idx)
			minetest.show_formspec(playername, "wands:spelllist", spelllist(playername, wands.formspec_lists[playername].unlocked_idx))
			return
		end
		if (fields["known_spells"]) then
			local event = minetest.explode_textlist_event(fields.known_spells)
			wands.formspec_lists[playername].unlocked_idx = tonumber(event.index)
			return
		end
		if (fields["selected_spells"]) then
			local event = minetest.explode_textlist_event(fields.selected_spells)
			wands.formspec_lists[playername].selected_idx = tonumber(event.index)
			return
		end
	end
end)
