local capi = {screen=screen,client=client}
local wibox = require("wibox")
local awful = require("awful")
local cairo        = require( "lgi"              ).cairo
local color        = require( "gears.color"      )
local beautiful    = require( "beautiful"        )
local surface      = require( "gears.surface"    )
local layout       = require( "collision.layout" )
local util         = require( "collision.util"   )
local pango = require("lgi").Pango
local pangocairo = require("lgi").PangoCairo
local module = {}

local w = nil
local rad = 10
local border = 3

local function init()
  w = wibox{}
  w.ontop = true
  w.visible = true
end

local function get_round_rect(width,height,bg)
  local img2 = cairo.ImageSurface(cairo.Format.ARGB32, width,height)
  local cr2 = cairo.Context(img2)
  cr2:set_source_rgba(0,0,0,0)
  cr2:paint()
  cr2:set_source(bg)
  cr2:arc(rad,rad,rad,0,2*math.pi)
  cr2:arc(width-rad,rad,rad,0,2*math.pi)
  cr2:arc(rad  ,height-rad,rad,0,2*math.pi)
  cr2:fill()
  cr2:arc(width-rad,height-rad,rad,0,2*math.pi)
  cr2:rectangle(rad,0,width-2*rad,height)
  cr2:rectangle(0,rad,rad,height-2*rad)
  cr2:rectangle(width-rad,rad,rad,height-2*rad)
  cr2:fill()
  return img2
end

local margin = 15
local function create_arrow(cr,x,y,width, height,direction)
  cr:save()
  cr:translate(x,y)
  if direction then
    cr:translate(width,height)
    cr:rotate(math.pi)
  end
  cr:move_to(x,y)
  local r,g,b = util.get_rgb()
  cr:set_source_rgba(r,g,b,0.15)
  cr:set_antialias(1)
  cr:rectangle(2*margin,2*(height/7),width/3,3*(height/7))
  cr:fill()
  cr:move_to(2*margin+width/3,(height/7))
  cr:line_to(width-2*margin,height/2)
  cr:line_to(2*margin+width/3,6*(height/7))
  cr:line_to(2*margin+width/3,(height/7))
  cr:close_path()
  cr:fill()
  cr:restore()
end

local pango_l = nil
local function draw_shape(s,collection,current_idx,icon_f,y,text_height)
  local geo = capi.screen[s].geometry
  local wa  =capi.screen[s].workarea

  --Compute thumb dimensions
  local margins = 2*20 + (#collection-1)*20
  local width = (geo.width - margins) / #collection
  local ratio = geo.height/geo.width
  local height = width*ratio
  local dx = 20

  -- Do not let the thumb get too big
  if height > 150 then
    height = 150
    width = 150 * (1.0/ratio)
    dx = (wa.width-margins-(#collection*width))/2 + 20
  end

  -- Resize the wibox
  w.x,w.y,w.width,w.height = geo.x,y or (wa.y+wa.height) - margin - height,geo.width,height

  local img = cairo.ImageSurface(cairo.Format.ARGB32, geo.width,geo.height)
  local img3 = cairo.ImageSurface(cairo.Format.ARGB32, geo.width,geo.height)
  local cr = cairo.Context(img)
  local cr3 = cairo.Context(img3)
  cr:set_source_rgba(0,0,0,0)
  cr:paint()

  local white,bg = color("#FFFFFF"),color(beautiful.menu_bg_normal or beautiful.bg_normal)
  local img2 = get_round_rect(width,height,white)
  local img4 = get_round_rect(width-6,height-6,bg)

  if not pango_l then
    local pango_crx = pangocairo.font_map_get_default():create_context()
    pango_l = pango.Layout.new(pango_crx)
    pango_l:set_font_description(beautiful.get_font(font))
    pango_l:set_alignment("CENTER")
    pango_l:set_wrap("CHAR")
  end

  local nornal,focus = color(beautiful.fg_normal),color(beautiful.bg_urgent)
  for k,v in ipairs(collection) do
    -- Shape bounding
    cr:set_source_surface(img2,dx,0)
    cr:paint()

    -- Borders
    cr3:set_source(k==current_idx and focus or nornal)
    cr3:rectangle(dx,0,width,height)
    cr3:fill()
    cr3:set_source_surface(img4,dx+border,border)
    cr3:paint()

    -- Print the icon
    local icon = icon_f(v,width-20,height-20-text_height)
    if icon then
      cr3:save()
      cr3:translate(dx+10,10)
      cr3:set_source_surface(icon)
      cr3:paint_with_alpha(0.7)
      cr3:restore()
    end

    -- Print a pretty line
    local r,g,b = util.get_rgb()
    cr3:set_source_rgba(r,g,b,0.7)
    cr3:set_line_width(1)
    cr3:move_to(dx+margin,height - text_height-border)
    cr3:line_to(dx+margin+width-2*margin,height - text_height-border)
    cr3:stroke()

    -- Pring the text
    pango_l.text = v.name
    pango_l.width = pango.units_from_double(width-16)
    pango_l.height = pango.units_from_double(height-text_height-10)
    cr3:move_to(dx+8,height-text_height-0)
    cr3:show_layout(pango_l)

    -- Draw an arrow
    if k == current_idx-1 then
      create_arrow(cr3,dx,0,width,height,1)
    elseif k == current_idx+1 then
      create_arrow(cr3,dx,0,width,height,nil)
    end

    dx = dx + width + 20
  end

  w:set_bg(cairo.Pattern.create_for_surface(img3))
  w.shape_bounding = img._native
  w.visible = true
end

function module.hide()
  w.visible = false
end

--Client related
local function client_icon(c,width,height)
  -- Get the content
  --TODO detect pure black frames
  local img = cairo.ImageSurface(cairo.Format.ARGB32, width, height)
  local cr = cairo.Context(img)

  local geom = c:geometry()
  local scale = width/geom.width
  if geom.height*scale > height then
    scale = height/geom.height
  end
  local w,h = geom.width*scale,geom.height*scale

  -- Create a mask
  cr:save()
  cr:translate((width-w)/2,(height-h)/2)
  cr:arc(10,10,10,0,math.pi*2)
  cr:fill()
  cr:arc(w-10,10,10,0,math.pi*2)
  cr:fill()
  cr:arc(w-10,h-10,10,0,math.pi*2)
  cr:fill()
  cr:arc(10,h-10,10,0,math.pi*2)
  cr:fill()
  cr:rectangle(10,0,w-20,h)
  cr:rectangle(0,10,w,h-20)
  cr:fill()

  -- Create a matrix to scale down the screenshot
  cr:save()
  cr:scale(scale,scale)

  -- Paint the screenshot in the rounded rectangle
  cr:set_source_surface(surface(c.content))
  cr:set_operator(cairo.Operator.IN)
  cr:paint()
  cr:restore()
  cr:restore()

  -- Add icon on top, "solve" the black window issue
  local icon = surface(c.icon)
  local w,h = icon:get_width(),icon:get_height()
  local aspect,aspect_h = width / w,(height) / h
  if aspect > aspect_h then aspect = aspect_h end
  cr:translate((width-w*aspect)/2,(height-h*aspect)/2)
  cr:scale(aspect, aspect)
  cr:set_source_surface(icon)
  cr:paint_with_alpha(0.5)

  return img
end

function module.display_clients(s,direction)
  if not w then
    init()
  end
  if direction then
    awful.client.focus.byidx(direction == "right" and 1 or -1)
    capi.client.focus:raise()
  end
  local clients = awful.client.tiled(s)
  local fk = awful.util.table.hasitem(clients,capi.client.focus)
  draw_shape(s,clients,fk,client_icon,nil,50)
end

function module.change_focus(mod,key,event,direction,is_swap,is_max)
  awful.client.focus.byidx(direction == "right" and 1 or -1)
  local c = capi.client.focus
  local s = c.screen
  c:raise()
  local clients = awful.client.tiled(s)
  local fk = awful.util.table.hasitem(clients,c)
  draw_shape(s,clients,fk,client_icon,nil,50)
  return true
end

--Tag related
local function tag_icon(t,width,height)
  local img = cairo.ImageSurface(cairo.Format.ARGB32, width, height)
  local cr = cairo.Context(img)

  local has_layout = layout.draw(t,cr,width,height)

  -- Create a monochrome representation of the icon
  local icon_orig = surface(awful.tag.geticon(t))
    if icon_orig then
    local icon = cairo.ImageSurface(cairo.Format.ARGB32, icon_orig:get_width(), icon_orig:get_height())
    local cr2 = cairo.Context(icon)
    cr2:set_source_surface(icon_orig)
    cr2:paint()

    cr2:set_source(color(beautiful.fg_normal))
    cr2:set_operator(cairo.Operator.IN)
    cr2:paint()

    local w,h = icon:get_width(),icon:get_height()
    local aspect,aspect_h = width / w,(height) / h
    if aspect > aspect_h then aspect = aspect_h end
    cr:translate((width-w*aspect)/2,(height-h*aspect)/2)
    cr:scale(aspect, aspect)
    cr:set_source_surface(icon)
    cr:paint_with_alpha(has_layout and 0.75 or 1)
  end
  return img
end

local tmp_screen = nil
function module.display_tags(s,direction)
  if not w then
    init()
  end
  tmp_screen = s
  if direction then
    awful.tag[direction == "left" and "viewprev" or "viewnext"](s)
  end
  local tags = awful.tag.gettags(s)
  local fk = awful.util.table.hasitem(tags,awful.tag.selected(s))
  draw_shape(s,tags,fk,tag_icon,capi.screen[s].workarea.y + 15,20)
end

function module.change_tag(mod,key,event,direction,is_swap,is_max)
  local s = tmp_screen or capi.client.focus.screen
  awful.tag[direction == "left" and "viewprev" or "viewnext"](s)
  local tags = awful.tag.gettags(s)
  local fk = awful.util.table.hasitem(tags,awful.tag.selected(s))
  draw_shape(s,tags,fk,tag_icon,capi.screen[s].workarea.y + 15,20)
  return true
end

return module
-- kate: space-indent on; indent-width 2; replace-tabs on;