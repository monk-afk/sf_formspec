-- template.lua
local function register_page(sfs)
  local template_pagename = "sfs:template"

  core.register_chatcommand("sfs", {
    description = "Template chat command for sfs",
    privs = {interact = true},
    params = "",
    func = function(player_name)
      local player = core.get_player_by_name(player_name)
      if player then
        sfs.set_page(player, template_pagename)
      end
    end
  })

  return sfs.register_page(template_pagename, {
    title = "Template",
    get = function(self, player, context)
      return sfs.make_formspec(player, context, [[
          label[0.1,0.1;SFs Template]
          button_exit[6,0.1;1.8,1.8;btn_exit;Exit]
        ]], true)
    end
  })
end

return register_page