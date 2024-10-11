local sfs = {
  pages = {},
  pages_unordered = {},
  contexts = {},
}

function sfs.register_page(name, def)
  assert(name, "Invalid sfs page. Requires a name")
  assert(def, "Invalid sfs page. Requires a def[inition] table")
  assert(def.get, "Invalid sfs page. Def requires a get function.")
  assert(not sfs.pages[name], "Attempt to register already registered sfs page " .. dump(name))

  sfs.pages[name] = def
  def.name = name
  table.insert(sfs.pages_unordered, def)
end

function sfs.override_page(name, def)
  assert(name, "Invalid sfs page override. Requires a name")
  assert(def, "Invalid sfs page override. Requires a def[inition] table")
  local page = sfs.pages[name]
  assert(page, "Attempt to override sfs page " .. dump(name) .. " which does not exist.")
  for key, value in pairs(def) do
    page[key] = value
  end
end

local function get_nav_fs(player, context, nav, current_idx)
  -- Only show tabs if there is more than one page
  if #nav > 1 then
    return "tabheader[0,0;sfs_nav_tabs;" .. table.concat(nav, ",") ..
        ";" .. current_idx .. ";true;false]"
  else
    return ""
  end
end

local theme_inv = [[
    list[current_player;main;0,5.2;8,1;]
    list[current_player;main;0,6.35;8,3;8]
  ]]

function sfs.make_formspec(player, context, content, show_inv, size)
  local tmp = {
    size or "size[8,9.1]",
    get_nav_fs(player, context, context.nav_titles, context.nav_idx),
    show_inv and theme_inv or "",
    content
  }
  return table.concat(tmp, "")
end

local function get_homepage_name(player)
  return "sfs:template"
end

local function get_formspec(player, context)
  -- Generate navigation tabs
  local nav = {}
  local nav_ids = {}
  local current_idx = 1
  for i, pdef in pairs(sfs.pages_unordered) do
    if not pdef.is_in_nav or pdef:is_in_nav(player, context) then
      nav[#nav + 1] = pdef.title
      nav_ids[#nav_ids + 1] = pdef.name
      if pdef.name == context.page then
        current_idx = #nav_ids
      end
    end
  end
  context.nav = nav_ids
  context.nav_titles = nav
  context.nav_idx = current_idx

  -- Generate formspec
  local page = sfs.pages[context.page] or sfs.pages["404"]
  if page then
    return page:get(player, context)
  else
    local old_page = context.page
    local home_page = get_homepage_name(player)

    if old_page == home_page then
      minetest.log("error", "[sfs] Couldn't find " .. dump(old_page) ..
          ", which is also the old page")

      return ""
    end

    context.page = home_page
    assert(sfs.pages[context.page], "[sfs] Invalid homepage")
    minetest.log("warning", "[sfs] Couldn't find " .. dump(old_page) ..
        " so switching to homepage")

    return get_formspec(player, context)
  end
end

function sfs.get_or_create_context(player)
  local name = player:get_player_name()
  local context = sfs.contexts[name]
  if not context then
    context = {
      page = get_homepage_name(player)
    }
    sfs.contexts[name] = context
  end
  return context
end

function sfs.set_context(player, context)
  sfs.contexts[player:get_player_name()] = context
end

function sfs.show_player_formspec(player, context)
  local fs = get_formspec(player,
      context or sfs.get_or_create_context(player))
  minetest.after(0.1, minetest.show_formspec,
      player:get_player_name(), context.page, fs)
end

function sfs.set_page(player, pagename)
  local context = sfs.get_or_create_context(player)
  local oldpage = sfs.pages[context.page]
  if oldpage and oldpage.on_leave then
    oldpage:on_leave(player, context)
  end
  context.page = pagename
  local page = sfs.pages[pagename]
  if page.on_enter then
    page:on_enter(player, context)
  end
  sfs.show_player_formspec(player, context)
end

function sfs.get_page(player)
  local context = sfs.contexts[player:get_player_name()]
  return context and context.page or get_homepage_name(player)
end

minetest.register_on_joinplayer(function(player)
  sfs.get_or_create_context(player)
end)

minetest.register_on_leaveplayer(function(player)
  sfs.contexts[player:get_player_name()] = nil
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if not sfs.pages[formname] then
    return false
  end

  -- Get Context
  local name = player:get_player_name()
  local context = sfs.contexts[name]
  if not context then
    sfs.show_player_formspec(player)
    return false
  end

  -- Was a tab selected?
  if fields.sfs_nav_tabs and context.nav then
    local tid = tonumber(fields.sfs_nav_tabs)
    if tid and tid > 0 then
      local id = context.nav[tid]
      local page = sfs.pages[id]
      if id and page then
        sfs.set_page(player, id)
      end
    end
  else
    -- Pass event to page
    local page = sfs.pages[context.page]
    if page and page.on_player_receive_fields then
      return page:on_player_receive_fields(player, context, fields)
    end
  end
end)

return sfs