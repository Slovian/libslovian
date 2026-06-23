-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local WeightedRandom = require("libslovian.core.WeightedRandom")
-----------------------------------------------------------------------------------------
-- Weighted random choice utilities.
--
-- Usage:
--   local pick = require("libslovian.core.WeightedRandom").pick
--   local choice = pick({
--       { value = "a", weight = 1 },
--       { value = "b", weight = 3 },
--       { value = "c", weight = 6 },
--   })

local WeightedRandom = {}

--- One-pass weighted reservoir sampling.
-- @param list Array of entries. Each entry can be:
--   * a plain value (weight defaults to 1), or
--   * a table with `weight` and optionally `value`, or
--   * a table with `weight` and `Mod`/`Spec` (legacy wrapper shape).
-- @return The chosen value, or nil if the list is empty.
function WeightedRandom.pick(list)
	if not list or #list == 0 then
		return nil
	end

	local chosen, total = nil, 0.0
	for i = 1, #list do
		local entry = list[i]
		local spec, weight

		if type(entry) == "table" then
			spec   = entry.Mod or entry.Spec or entry
			weight = entry.weight or spec.weight or 1
		else
			spec   = entry
			weight = 1
		end

		if weight > 0 then
			total = total + weight
			-- choose this item with probability weight/total
			if math.random() * total < weight then
				chosen = spec
			end
		end
	end

	-- Fallback (shouldn't hit if list non-empty)
	if not chosen then
		local last = list[#list]
		chosen = type(last) == "table" and (last.Mod or last.Spec or last) or last
	end

	return chosen
end

return WeightedRandom
