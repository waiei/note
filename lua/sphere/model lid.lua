-- 3D蓋
return Def.ActorMultiVertex({
	--[[
		params.Scale   = {int TopSize, int BottomSize}
		params.Height  = int Height
		params.Number  = int verticesNumber
		params.Color   = color faceColor
		params.Texture = RageTexture Texture
		params.Uv      = {int uvLeft, int uvTop, int uvRight, int uvBottom}
	--]]
	SetVerticesMessageCommand = function(self, params)
		local scale     = params.Scale or 100
		local number    = params.Number or 8
		local faceColor = params.Color or Color('White')
		local texture   = params.Texture
		local texUv     = params.Uv
		local uv        = {}
		if texture then
			self:SetTexture(texture)
			uv = {texUv[1], texUv[2], texUv[3], texUv[4]}
		else
			uv = {0, 0, 0, 0}
		end
		self:visible(true)
		local vertices  = {}
		self:SetDrawState({ Mode = 'DrawMode_Fan' })
		vertices[#vertices + 1] = {
			{
				0,
				0,
				0,
			},
			faceColor,
			{(uv[3]-uv[1])/2 + uv[1], (uv[4]-uv[2])/2 + uv[2]},
		}
		for i = 0, number do
			local uvX = 1.0 * (uv[3]-uv[1])/2 * math.sin(math.pi*i*2/number) + (uv[3]-uv[1])/2 + uv[1]
			local uvY = -1.0 * (uv[4]-uv[2])/2 * math.cos(math.pi*i*2/number) + (uv[4]-uv[2])/2 + uv[2]
			vertices[#vertices + 1] = {
				{
					math.sin(2.0 * math.pi * i / number) * scale / 2,
					0,
					math.cos(2.0 * math.pi * i / number) * scale / 2,
				},
				faceColor,
				{uvX, uvY},
			}
		end
		if vertices and #vertices > 0 then
			self:SetVertices(vertices)
		end
	end,
})
