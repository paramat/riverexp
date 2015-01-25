-- Parameters

local YWATER = 1
local YSAND = 4
local YTERCEN = 0
local TERSCA = 256
local BASAMP = 0.2

local TSTONE = 0.01
local TRIVER = 0.01
local VALAMP = 100
local VALEXP = 2
local RIVAMP = 1

-- Noise parameters

-- 2D noise

local np_valleyhi = {
	offset = 0,
	scale = 1,
	spread = {x=768, y=768, z=768},
	seed = -100,
	octaves = 5,
	persist = 0.6,
	lacunarity = 2.0,
	--flags = ""
}

local np_valleyhi2 = {
	offset = 0,
	scale = 1,
	spread = {x=768, y=768, z=768},
	seed = 95556,
	octaves = 5,
	persist = 0.6,
	lacunarity = 2.0,
	--flags = ""
}

local np_valleylo = {
	offset = 0,
	scale = 1,
	spread = {x=768, y=768, z=768},
	seed = -100,
	octaves = 3,
	persist = 0.5,
	lacunarity = 2.0,
	--flags = ""
}

local np_valleylo2 = {
	offset = 0,
	scale = 1,
	spread = {x=768, y=768, z=768},
	seed = 95556,
	octaves = 3,
	persist = 0.5,
	lacunarity = 2.0,
	--flags = ""
}

local np_base = {
	offset = 0,
	scale = 1,
	spread = {x=1536, y=1536, z=1536},
	seed = 188,
	octaves = 3,
	persist = 0.4,
	lacunarity = 2.0,
	--flags = ""
}

--local np_ = {
--	offset = 0,
--	scale = 1,
--	spread = {x=, y=, z=},
--	seed = ,
--	octaves = ,
--	persist = 0.5,
--	lacunarity = 2.0,
--	--flags = ""
--}

-- Stuff

dofile(minetest.get_modpath("riverexp").."/nodes.lua")

-- Set mapgen parameters

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode", flags="nolight"})
end)

-- Initialize noise objects to nil

local nobj_valleyhi = nil
local nobj_valleyhi2 = nil
local nobj_valleylo = nil
local nobj_valleylo2 = nil
local nobj_base = nil

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	local t0 = os.clock()
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	print ("[riverexp] chunk minp ("..x0.." "..y0.." "..z0..")")
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	
	local c_stone = minetest.get_content_id("default:stone")
	local c_water = minetest.get_content_id("default:water_source")
	local c_sand  = minetest.get_content_id("default:sand")
	
	local c_grass      = minetest.get_content_id("riverexp:grass")
	local c_freshwater = minetest.get_content_id("riverexp:freshwater")

	local sidelen = x1 - x0 + 1
	local ystride = sidelen + 32
	--local zstride = ystride ^ 2
	--local chulens3d = {x=sidelen, y=sidelen+17, z=sidelen}
	local chulens2d = {x=sidelen, y=sidelen, z=1}
	--local minpos3d = {x=x0, y=y0-16, z=z0}
	local minpos2d = {x=x0, y=z0}
	
	nobj_valleyhi = nobj_valleyhi or minetest.get_perlin_map(np_valleyhi, chulens2d)
	local nvals_valleyhi = nobj_valleyhi:get2dMap_flat(minpos2d)

	nobj_valleyhi2 = nobj_valleyhi2 or minetest.get_perlin_map(np_valleyhi2, chulens2d)
	local nvals_valleyhi2 = nobj_valleyhi2:get2dMap_flat(minpos2d)

	nobj_valleylo = nobj_valleylo or minetest.get_perlin_map(np_valleylo, chulens2d)
	local nvals_valleylo = nobj_valleylo:get2dMap_flat(minpos2d)

	nobj_valleylo2 = nobj_valleylo2 or minetest.get_perlin_map(np_valleylo2, chulens2d)
	local nvals_valleylo2 = nobj_valleylo2:get2dMap_flat(minpos2d)

	nobj_base = nobj_base or minetest.get_perlin_map(np_base, chulens2d)
	local nvals_base = nobj_base:get2dMap_flat(minpos2d)

	--nobj_ = nobj_ or minetest.get_perlin_map(np_, chulens2d)
	--local nvals_ = nobj_:get2dMap_flat(minpos2d)

	--local ni3d = 1
	local ni2d = 1
	for z = z0, z1 do
		for y = y0 - 16, y1 + 1 do
			local vi = area:index(x0, y, z)
			for x = x0, x1 do

				local n_base = nvals_base[ni2d]
				local blend = math.min(math.max(n_base * 3 - 1, 0), 1)
				local triver = TRIVER * (1 - blend * 0.5)
				local valamp = VALAMP * (1 - blend * 0.8)
				local valexp = VALEXP

				local n_valleylo = nvals_valleylo[ni2d]
				local n_valleyhi = nvals_valleyhi[ni2d]
				local n_valleymix = n_valleylo * (1 - blend) + n_valleyhi * blend

				local n_valleylo2 = nvals_valleylo2[ni2d]
				local n_valleyhi2 = nvals_valleyhi2[ni2d]
				local n_valleymix2 = n_valleylo2 * (1 - blend) + n_valleyhi2 * blend

				local grad = (YTERCEN - y) / TERSCA
				local densitybase = n_base * BASAMP + grad
				local densityval = math.abs(n_valleymix * n_valleymix2) - triver
				if densityval > 0 then
					densityval = math.min(densityval ^ valexp * valamp,
							0.4 + blend)
				else -- river channel shape
					densityval = densityval * RIVAMP
				end
				local density = densityval + densitybase

				if density >= TSTONE then
					data[vi] = c_stone
				elseif density > 0 and density < TSTONE then
					if y <= YSAND or densitybase > 0.001 then
						data[vi] = c_sand
					else
						data[vi] = c_grass
					end
				elseif y <= YWATER then
					data[vi] = c_water
				elseif densitybase > 0 then
					data[vi] = c_freshwater
				end

				--ni3d = ni3d + 1
				ni2d = ni2d + 1
				vi = vi + 1
			end
			ni2d = ni2d - sidelen
		end
		ni2d = ni2d + sidelen
	end
	
	vm:set_data(data)
	vm:calc_lighting()
	vm:write_to_map(data)
	vm:update_liquids()

	local chugent = math.ceil((os.clock() - t0) * 1000)
	print ("[riverexp] "..chugent.." ms")
end)

