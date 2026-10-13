local timeline = {}


function timeline.predict(health, regen, barrier, now, impact, events)
	local low, high = health, health
	local lowBarrier, highBarrier = barrier, barrier
	local previous, collision = now, false
	for _, event in ipairs(events) do
		if event.impact > now and event.impact <= impact + 1 / 30 then
			local elapsed = math.max(0, event.impact - previous)
			low, high = low + regen * elapsed, high + regen * elapsed
			previous = event.impact
			if math.abs(event.impact - impact) <= 1 / 30 then collision = true end
			local minDamage, maxDamage = event.minimum, event.maximum
			low = low - math.max(0, maxDamage - lowBarrier)
			high = high - math.max(0, minDamage - highBarrier)
			lowBarrier, highBarrier = math.max(0, lowBarrier - maxDamage), math.max(0, highBarrier - minDamage)
			if low <= 0 then return low, high, true end
		end
	end
	local elapsed = math.max(0, impact - previous)
	return low + regen * elapsed, high + regen * elapsed + highBarrier, collision
end

function timeline.canKill(low, high, collision, damage)
	return low > 0 and high <= damage and not collision
end

function timeline.choose(candidates, now, attackPeriod, moveSpeed)
	local best, bestScore
	for _, first in ipairs(candidates) do
		local confidence = first.contest and first.impact >= first.contest - 1 / 30 and 0.3 or 1
		local score = first.value * confidence / (1 + (first.impact - now) * 0.5) - first.approach * 8
		local followValue = 0
		local missedLastHit = 0
		for _, second in ipairs(candidates) do
			if first ~= second then
				local dx, dy = first.x - second.x, first.y - second.y
				local travel = math.sqrt(dx * dx + dy * dy) / moveSpeed
				local impact = math.max(first.start + attackPeriod, first.release + travel) + second.delay + 0.08
				local follows = false
				if impact <= now + 3 then
					local low, high, collision = timeline.predict(second.health, second.regen, second.barrier, now, impact, second.events)
					if timeline.canKill(low, high, collision, second.damage) then
						follows = not second.contest or impact < second.contest - 1 / 30
						local available = second.contest and impact >= second.contest - 1 / 30 and 0.3 or 1
						followValue = math.max(followValue, second.value * available * 0.65 / (1 + impact - now))
					end
				end
				if first.allied and not second.allied and not follows and second.impact <= first.start + attackPeriod + second.delay + travel
					and (not second.contest or second.impact < second.contest - 1 / 30) then missedLastHit = math.max(missedLastHit, second.value) end
			end
		end
		score = score + followValue + (first.focus and 12 * confidence or 0) - missedLastHit * 1.5
		if not bestScore or score > bestScore then best, bestScore = first, score end
	end
	return best
end

return timeline
