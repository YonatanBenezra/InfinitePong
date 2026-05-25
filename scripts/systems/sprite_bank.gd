## ============================================================
## SPRITE BANK — single place to add, rename, or resize every sprite.
## Drop PNGs into  res://assets/sprites/  and the game switches from
## procedural drawing to sprite rendering automatically. If a file is
## missing the system silently falls back to the old polygon drawing.
##
## DESIGN NOTES
## • Wall / platform tiles should be GREYSCALE or WHITE so WorldPainter
##   can tint them with world-theme colours via modulate.
## • Flipper / spike / exit sprites can use full colour; modulate is only
##   applied when the code explicitly passes a colour.
## • Icon sprites should be WHITE so UITheme.accent tinting works.
##
## ══════════════════════════════════════════════════════════════════
## NEEDED SPRITES — create these files at the paths shown below.
## ══════════════════════════════════════════════════════════════════
##
## LEVEL GEOMETRY  (WorldPainter — every wall and platform in every chunk)
##   wall_tile.png            64 × 64 px
##       Seamlessly tileable vertically and horizontally.
##       Suggested values: bright top edge (highlight), mid-grey body,
##       dark bottom edge (shadow). Keep it greyscale.
##
##   platform_tile.png        64 × 32 px
##       Seamlessly tileable. Bright top face, mid body, dark bottom trim.
##       Keep it greyscale; WorldPainter tints it with the world palette.
##
## PLAYER FLIPPERS
##   flipper_bar.png          96 × 30 px
##       Tapered bar: thicker at the left (pivot) end, thinner at the tip.
##       The sprite is scaled horizontally to match bar_length at runtime.
##
##   flipper_pivot.png        24 × 24 px
##       Small round or hex pivot disc placed at the bar's rotation origin.
##
##   flat_flipper.png        184 × 48 px
##       Flat rectangular plate. Optional grip marks or panel lines.
##       Used by the sliding plate flipper (flipper_flat scenes).
##
## HAZARDS
##   spike.png                40 × 44 px
##       Two spikes on a small mounting base. Tip at the TOP of the image,
##       base block at the BOTTOM. Sprite is centered on the scene node.
##
## LEVEL EXIT  (script applies green modulate for the glow animation)
##   exit_gate.png           200 × 64 px
##       Horizontal portal / gate strip. Keep the art bright / near-white
##       so the green modulate applied by the exit script reads well.
##
## UI NAVIGATION ICONS  (greyscale / white; tinted by UITheme.accent)
##   icon_play.png            26 × 26 px   Right-pointing triangle.
##   icon_continue.png        26 × 26 px   Play arrow (or play + step glyph).
##   icon_levels.png          26 × 26 px   2 × 2 grid of squares.
##   icon_skins.png           26 × 26 px   Circle with a small shadow cutout.
##   icon_stats.png           26 × 26 px   Three vertical bar-chart bars.
##   icon_trophy.png          26 × 26 px   Trophy cup silhouette.
##   icon_settings.png        26 × 26 px   Gear / cog.
##   icon_back.png            26 × 26 px   Left-pointing chevron / arrow.
## ══════════════════════════════════════════════════════════════════

class_name SpriteBank

const BASE := "res://assets/sprites/"

# Level geometry
const WALL_TILE     := BASE + "wall_tile.png"
const PLATFORM_TILE := BASE + "platform_tile.png"

# Flippers
const FLIPPER_BAR   := BASE + "flipper_bar.png"
const FLIPPER_PIVOT := BASE + "flipper_pivot.png"
const FLAT_FLIPPER  := BASE + "flat_flipper.png"

# Hazards
const SPIKE         := BASE + "spike.png"

# Level exit
const EXIT_GATE     := BASE + "exit_gate.png"

# Navigation icons
const ICON_PLAY     := BASE + "icon_play.png"
const ICON_CONTINUE := BASE + "icon_continue.png"
const ICON_LEVELS   := BASE + "icon_levels.png"
const ICON_SKINS    := BASE + "icon_skins.png"
const ICON_STATS    := BASE + "icon_stats.png"
const ICON_TROPHY   := BASE + "icon_trophy.png"
const ICON_SETTINGS := BASE + "icon_settings.png"
const ICON_BACK     := BASE + "icon_back.png"


## Returns the texture at path, or null if the file doesn't exist yet.
## Use this instead of load() so missing sprites degrade gracefully.
static func get_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Tiled Sprite2D that repeats the texture to fill (width × height) px.
## Returns null when the PNG isn't in place yet — callers fall back to
## procedural drawing in that case.
static func make_tiled(path: String, width: float, height: float,
		col: Color = Color.WHITE) -> Sprite2D:
	var tex := get_texture(path)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(0.0, 0.0, width, height)
	spr.centered = true
	spr.modulate = col
	return spr


## Stretched Sprite2D scaled to exactly (width × height) px.
## Returns null when the PNG isn't in place yet.
static func make_scaled(path: String, width: float, height: float,
		col: Color = Color.WHITE) -> Sprite2D:
	var tex := get_texture(path)
	if tex == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(width / float(tex.get_width()), height / float(tex.get_height()))
	spr.centered = true
	spr.modulate = col
	return spr


## Returns the sprite path for a nav-icon kind string, or "" if unknown.
static func icon_path(kind: String) -> String:
	match kind:
		"play":     return ICON_PLAY
		"continue": return ICON_CONTINUE
		"levels":   return ICON_LEVELS
		"skins":    return ICON_SKINS
		"stats":    return ICON_STATS
		"trophy":   return ICON_TROPHY
		"settings": return ICON_SETTINGS
		"back":     return ICON_BACK
	return ""
