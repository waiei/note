-- 3Dリング
return Def.ActorMultiVertex({
	--[[
		params.Scale  = {int TopSize, int BottomSize}
		params.Height = int Height
		params.Number = int verticesNumber
		params.Color  = color faceColor
		params.Texture = RageTexture Texture
		params.Uv      = {int uvLeft, int uvTop, int uvRight, int uvBottom}
	--]]
	SetVerticesMessageCommand = function(self, params)
		local scale     = params.Scale or {100, 100}
		local number    = params.Number or 8
		local height    = params.Height or 50
		local faceColor = params.Color or Color('White')
		local texture   = params.Texture
		local texUv     = params.Uv
		local uv        = {}
		if #scale ~= 2 then
			self:visible(false)
			return
		end
		if texture then
			self:SetTexture(texture)
			uv = {texUv[1], texUv[2], texUv[3], texUv[4]}
		else
			uv = {0, 0, 0, 0}
		end
		self:visible(true)
		local vertices  = {}
		if (scale[1] <= 0 or scale[2] <= 0) and not texture then
			local isTop = scale[1] <= 0
			self:SetDrawState({ Mode = 'DrawMode_Fan' })
			vertices[#vertices + 1] = {
				{
					0,
					(isTop and -1 or 1) * height / 2,
					0,
				},
				faceColor,
				{0, 0},
			}
		else
			self:SetDrawState({ Mode = 'DrawMode_QuadStrip' })
		end
		for i = 0, number do
			--if scale[1] > 0 or texture then
				vertices[#vertices + 1] = {
					{
						math.sin(2.0 * math.pi * i / number) * scale[1] / 2,
						-height / 2,
						math.cos(2.0 * math.pi * i / number) * scale[1] / 2,
					},
					faceColor,
					{(uv[3] - uv[1]) * i / number + uv[1], uv[2]},
				}
			--end
			if scale[2] > 0 or texture then
				vertices[#vertices + 1] = {
					{
						math.sin(2.0 * math.pi * i / number) * scale[2] / 2,
						height / 2,
						math.cos(2.0 * math.pi * i / number) * scale[2] / 2,
					},
					faceColor,
					{(uv[3] - uv[1]) * i / number + uv[1], uv[4]},
				}
			end
		end
		if vertices and #vertices > 0 then
			self:SetVertices(vertices)
		end
	end,
})
