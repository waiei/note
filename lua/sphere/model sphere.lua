-- 3D球体
local id, model = ...
local modelResolution = model.Resolution or 8
local modelSize       = model.Size or 100
local modelTexture    = model.Texture
local modelColor      = model.Color or color('#ffffffff')
local modelSlice      = model.Slice

local modelRadius = modelSize/2

local texFile = nil
local _LEFT_   = 1
local _TOP_    = 2
local _RIGHT_  = 3
local _BOTTOM_ = 4
local texUv       = {0, 0, 1, 1}
local texTopUv    = {}
local texBottomUv = {}

if modelTexture then
	texFile = modelTexture.File or nil
	-- 全体のUV
	if modelTexture.Uv then
		texUv[_LEFT_]   = modelTexture.Uv[1] or 0
		texUv[_TOP_]    = modelTexture.Uv[2] or 0
		texUv[_RIGHT_]  = modelTexture.Uv[3] or 1
		texUv[_BOTTOM_] = modelTexture.Uv[4] or 1
	end
	-- Sliceでカットした時の上部のUV
	if modelTexture.TopUv then
		texTopUv[_LEFT_]   = modelTexture.TopUv[1] or 0
		texTopUv[_TOP_]    = modelTexture.TopUv[2] or 0
		texTopUv[_RIGHT_]  = modelTexture.TopUv[3] or 1
		texTopUv[_BOTTOM_] = modelTexture.TopUv[4] or 1
	end
	-- Sliceでカットした時の下部のUV
	if modelTexture.BottomUv then
		texBottomUv[_LEFT_]   = modelTexture.BottomUv[1] or 0
		texBottomUv[_TOP_]    = modelTexture.BottomUv[2] or 0
		texBottomUv[_RIGHT_]  = modelTexture.BottomUv[3] or 1
		texBottomUv[_BOTTOM_] = modelTexture.BottomUv[4] or 1
	end
end
local texUvH  = texUv[_BOTTOM_] - texUv[_TOP_]

-- 上下カット
local sliceTop    = 0
local sliceBottom = 1
if modelSlice then
	sliceTop    = math.min(math.max(modelSlice[1] or 0, 0), 1)
	sliceBottom = math.min(math.max(modelSlice[2] or 1, sliceTop), 1)
end

local modelActor = Def.ActorFrame{}
local resolution = math.ceil(modelResolution/2)
-- 座表計算用基準位置
local basePosition = -0.5 * modelSize

local function ModelLid(posY, slice, i, sliceUv)
	local sliceScale = (slice < 0.5) and modelRadius*((0.5-slice)*2) or modelRadius*((slice-0.5)*2)
	return LoadActor('model lid')..{
		SphereModelCreateMessageCommand = function(self, params)
			if params.Id ~= id then
				return
			end
			local texture  = params.Texture
			local uvScaleW = texture and params.TexW / texture:GetTextureWidth() or 1
			local uvScaleH = texture and params.TexH / texture:GetTextureHeight() or 1
			self:y(posY)
			self:playcommand('SetVertices', {
				Scale   = math.sqrt(modelRadius*modelRadius - sliceScale*sliceScale) * 2,
				Number  = modelResolution,
				Color   = modelColor,
				--Color   = i>10 and Color('Red') or modelColor,
				Texture = params.Texture,
				Uv      = {
					uvScaleW * sliceUv[_LEFT_],
					uvScaleH * sliceUv[_TOP_],
					uvScaleW * sliceUv[_RIGHT_],
					uvScaleH * sliceUv[_BOTTOM_],
				},
			})
		end,
	}
end

local sliceTopY    = basePosition + modelSize * sliceTop
local sliceBottomY = basePosition + modelSize * sliceBottom
for i = 0, resolution-1 do
	local prevY    = basePosition*math.cos(math.pi*i/resolution)
	local nextY    = basePosition*math.cos(math.pi*(i+1)/resolution)
	-- スライス後描画対象部分のみ作成
	local isSlicedTop     = false
	local isSlicedBottom  = false
	if nextY > sliceTopY and prevY < sliceBottomY then
		-- スライスによって端数になった箇所を計算
		-- 上面
		if prevY < sliceTopY then
			prevY       = sliceTopY
			isSlicedTop = true
			-- 蓋モデル
			if modelTexture.TopUv then
				modelActor[#modelActor + 1] = ModelLid(sliceTopY, sliceTop, i, texTopUv)
			end
		end
		-- 下面
		if nextY > sliceBottomY then
			nextY          = sliceBottomY
			isSlicedBottom = true
			-- 蓋モデル
			if modelTexture.BottomUv then
				modelActor[#modelActor + 1] = ModelLid(sliceBottomY, sliceBottom, i, texBottomUv)
			end
		end
		local height   = (nextY - prevY)
		-- 筒状のモデル
		modelActor[#modelActor + 1] = LoadActor('model ring')..{
			SphereModelCreateMessageCommand = function(self, params)
				if params.Id ~= id then
					return
				end
				local uvT      = (math.tan(math.pi/2*i/resolution - math.pi/4)/2+0.5) * texUvH + texUv[_TOP_]
				local uvB      = (math.tan(math.pi/2*(i+1)/resolution - math.pi/4)/2+0.5) * texUvH + texUv[_TOP_]
				local texture  = params.Texture
				local uvScaleW = texture and params.TexW / texture:GetTextureWidth() or 1
				local uvScaleH = texture and params.TexH / texture:GetTextureHeight() or 1
				self:y(prevY + (nextY - prevY) / 2)
				self:playcommand('SetVertices', {
					Scale = {
						(i <= 0 and not isSlicedTop)               and 0 or math.sqrt(modelRadius*modelRadius-prevY*prevY) * 2,
						(i >= resolution-1 and not isSlicedBottom) and 0 or math.sqrt(modelRadius*modelRadius-nextY*nextY) * 2,
					},
					Height  = height,
					Number  = modelResolution,
					Color   = modelColor,
					Texture = params.Texture,
					Uv      = {
								uvScaleW * texUv[_LEFT_], uvScaleH * uvT, uvScaleW * texUv[_RIGHT_],
								uvScaleH * uvB
							},
				})
			end,
		}
	end
end

return Def.ActorFrame{
	InitCommand = function(self)
		local child = self:GetChild('Sprite')
		self:ztest(true)
		self:zwrite(true)
		self:playcommand('SphereModelCreate', {
			Id = id,
			Texture = child:GetTexture(),
			TexW    = child:GetWidth() or 1,
			TexH    = child:GetHeight() or 1,
		})
	end,
	Def.Sprite({
		Name = 'Sprite',
		InitCommand = function(self)
			if modelTexture then
				self:Load(texFile)
				self:rate(1.0 / resolution)
			end
			self:visible(false)
		end;
	}),
	modelActor,
}