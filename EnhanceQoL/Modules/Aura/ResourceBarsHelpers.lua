local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local ResourceBars = addon.Aura and addon.Aura.ResourceBars
if not ResourceBars then return end

local function normalizeGradientColor(value)
	if type(value) == "table" then
		if value.r ~= nil then return value.r or 1, value.g or 1, value.b or 1, value.a or 1 end
		return value[1] or 1, value[2] or 1, value[3] or 1, value[4] or 1
	end
	return 1, 1, 1, 1
end

local function isGradientDebugEnabled()
	if _G and _G.EQOL_DEBUG_RB_GRADIENT == true then return true end
	return addon and addon.db and addon.db.debugResourceBarsGradient == true
end

local function formatColor(r, g, b, a)
	return string.format("%.2f/%.2f/%.2f/%.2f", r or 0, g or 0, b or 0, a or 1)
end

local function debugGradient(bar, reason, cfg, baseR, baseG, baseB, baseA, sr, sg, sb, sa, er, eg, eb, ea, force)
	if not isGradientDebugEnabled() then return end
	local now = GetTime and GetTime() or 0
	if bar then
		bar._rbGradDebugNext = bar._rbGradDebugNext or 0
		if now < bar._rbGradDebugNext then return end
		bar._rbGradDebugNext = now + 0.75
	end
	local name = (bar and bar.GetName and bar:GetName()) or tostring(bar) or "bar"
	local cfgStart, cfgEnd = "nil", "nil"
	if cfg then
		local csr, csg, csb, csa = normalizeGradientColor(cfg.gradientStartColor)
		local cer, ceg, ceb, cea = normalizeGradientColor(cfg.gradientEndColor)
		cfgStart = formatColor(csr, csg, csb, csa)
		cfgEnd = formatColor(cer, ceg, ceb, cea)
	end
	local msg = string.format(
		"grad %s %s base=%s cfgStart=%s cfgEnd=%s outStart=%s outEnd=%s force=%s",
		reason or "?",
		name,
		formatColor(baseR, baseG, baseB, baseA),
		cfgStart,
		cfgEnd,
		formatColor(sr, sg, sb, sa),
		formatColor(er, eg, eb, ea),
		force and "1" or "0"
	)
	print("|cff00ff98Enhance QoL|r: " .. msg)
end

local function resolveGradientColors(cfg, baseR, baseG, baseB, baseA)
	local sr, sg, sb, sa = normalizeGradientColor(cfg and cfg.gradientStartColor)
	local er, eg, eb, ea = normalizeGradientColor(cfg and cfg.gradientEndColor)
	local br, bg, bb, ba = baseR or 1, baseG or 1, baseB or 1, baseA or 1
	return br * sr, bg * sg, bb * sb, (ba or 1) * (sa or 1), br * er, bg * eg, bb * eb, (ba or 1) * (ea or 1)
end

local function clearGradientState(bar)
	bar._rbGradientEnabled = nil
	bar._rbGradientTex = nil
	bar._rbGradSR = nil
	bar._rbGradSG = nil
	bar._rbGradSB = nil
	bar._rbGradSA = nil
	bar._rbGradER = nil
	bar._rbGradEG = nil
	bar._rbGradEB = nil
	bar._rbGradEA = nil
end

function ResourceBars.ApplyBarGradient(bar, cfg, baseR, baseG, baseB, baseA, force)
	if not bar or not cfg or cfg.useGradient ~= true then return false end
	local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if not tex or not tex.SetGradient then return false end
	local sr, sg, sb, sa, er, eg, eb, ea = resolveGradientColors(cfg, baseR, baseG, baseB, baseA)
	if
		not force
		and
		bar._rbGradientEnabled
		and bar._rbGradientTex == tex
		and bar._rbGradSR == sr
		and bar._rbGradSG == sg
		and bar._rbGradSB == sb
		and bar._rbGradSA == sa
		and bar._rbGradER == er
		and bar._rbGradEG == eg
		and bar._rbGradEB == eb
		and bar._rbGradEA == ea
	then
		return true
	end
	tex:SetGradient("VERTICAL", CreateColor(sr, sg, sb, sa), CreateColor(er, eg, eb, ea))
	debugGradient(bar, "apply", cfg, baseR, baseG, baseB, baseA, sr, sg, sb, sa, er, eg, eb, ea, force)
	bar._rbGradientEnabled = true
	bar._rbGradientTex = tex
	bar._rbGradSR, bar._rbGradSG, bar._rbGradSB, bar._rbGradSA = sr, sg, sb, sa
	bar._rbGradER, bar._rbGradEG, bar._rbGradEB, bar._rbGradEA = er, eg, eb, ea
	return true
end

function ResourceBars.SetStatusBarColorWithGradient(bar, cfg, r, g, b, a)
	if not bar then return end
	local alpha = a or 1
	bar:SetStatusBarColor(r, g, b, alpha)
	bar._lastColor = bar._lastColor or {}
	bar._lastColor[1], bar._lastColor[2], bar._lastColor[3], bar._lastColor[4] = r, g, b, alpha
	if cfg and cfg.useGradient == true then
		ResourceBars.ApplyBarGradient(bar, cfg, r, g, b, alpha, true)
	elseif bar._rbGradientEnabled then
		debugGradient(bar, "clear", cfg, r, g, b, a)
		clearGradientState(bar)
	end
end

function ResourceBars.RefreshStatusBarGradient(bar, cfg, r, g, b, a)
	if not bar then return end
	if cfg and cfg.useGradient == true then
		local br, bg, bb, ba = r, g, b, a
		if br == nil then
			if bar._lastColor then
				br, bg, bb, ba = bar._lastColor[1], bar._lastColor[2], bar._lastColor[3], bar._lastColor[4]
			elseif bar.GetStatusBarColor then
				br, bg, bb, ba = bar:GetStatusBarColor()
			end
		end
		ResourceBars.ApplyBarGradient(bar, cfg, br or 1, bg or 1, bb or 1, ba or 1, true)
	elseif bar._rbGradientEnabled then
		local br, bg, bb, ba = r, g, b, a
		if br == nil then
			if bar._lastColor then
				br, bg, bb, ba = bar._lastColor[1], bar._lastColor[2], bar._lastColor[3], bar._lastColor[4]
			elseif bar.GetStatusBarColor then
				br, bg, bb, ba = bar:GetStatusBarColor()
			end
		end
		if br ~= nil then bar:SetStatusBarColor(br, bg or 1, bb or 1, ba or 1) end
		clearGradientState(bar)
	end
end

function ResourceBars.ResolveRuneCooldownColor(cfg)
	local fallback = 0.35
	local c = cfg and cfg.runeCooldownColor
	return c and (c[1] or fallback) or fallback, c and (c[2] or fallback) or fallback, c and (c[3] or fallback) or fallback, c and (c[4] or 1) or 1
end
