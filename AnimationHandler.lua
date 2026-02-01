-- ctto @unosize
---------- SERVICES ----------
local RS = game:GetService('ReplicatedStorage')
local Debris = game:GetService('Debris')

---------- VARIABLES ----------
local animationassets = RS:WaitForChild('AnimationAssets')
local remotes = animationassets:WaitForChild('Remotes')
local animations = animationassets:WaitForChild('Animations')
local dancemodule = require(animationassets:WaitForChild('DanceModule')) -- locate your dance module here.

local commandprefix = "@"
local FADE_TIME = 0.3

---------- FUNCTIONS ----------
local function get_animator(player)
	local char = player.Character
	local hum = char and char:FindFirstChild('Humanoid')
	return hum and hum:FindFirstChild('Animator')
end

local function check_ifPlaying(animator, animationName)
	local allanimations = animator:GetPlayingAnimationTracks()
	for _, v in pairs(allanimations) do
		if v.Name == animationName then
			return true
		end
	end
	return false
end

local function stop_otherDances(animator)
	local allanimations = animator:GetPlayingAnimationTracks()
	for _, v in pairs(allanimations) do
		if v.Name ~= 'Animation' then
			for _, j in pairs(dancemodule.Dances) do
				if j[1] == v.Name then
					v:Stop(FADE_TIME)
					break
				end
			end
			for _, j in pairs(dancemodule.Emotes) do
				if j[1] == v.Name then
					v:Stop(FADE_TIME)
					break
				end
			end
		end
	end
end

local function get_playing_animation(animator)
	local allanimations = animator:GetPlayingAnimationTracks()
	for _, v in pairs(allanimations) do
		if v.Name ~= 'Animation' then
			for _, j in pairs(dancemodule.Dances) do
				if j[1] == v.Name and v.IsPlaying then
					return v, j[1]
				end
			end
			for _, j in pairs(dancemodule.Emotes) do
				if j[1] == v.Name and v.IsPlaying then
					return v, j[1]
				end
			end
		end
	end
end

local function sync_allplayers_toplayer(animtrack, player, animation, shouldsync)
	for _, v in pairs(game.Players:GetChildren()) do
		if v ~= player and v.Character then
			if v.Character:GetAttribute('Syncing') == player.Name then
				local success, errormessage = pcall(function()
					local hum = v.Character:FindFirstChild('Humanoid')
					local animator2 = hum and hum:FindFirstChild('Animator')
					if animator2 then
						stop_otherDances(animator2)
						if shouldsync then
							local animtrack2 = animator2:LoadAnimation(animation or animtrack.Animation)
							animtrack2:Play(FADE_TIME)
							animtrack2:AdjustSpeed(animtrack.Speed)
							animtrack2.TimePosition = animtrack.TimePosition
						end
					end
				end)
				if not success then
					warn('Error syncing '..v.Name..' to '..player.Name..'. Error: '..errormessage)
				end
			end
		end
	end
end

local function get_main_source(targetedplayer)
	local char = targetedplayer.Character
	if char then
		if char:GetAttribute('Syncing') then
			return game.Players:FindFirstChild(char:GetAttribute('Syncing'))
		else
			return targetedplayer
		end
	end
end

local function play_animation(player, animation, ShouldPlay, speed, Speeding)
	local animator = get_animator(player)
	speed = tonumber(speed or 1)
	speed = math.clamp(speed, 0, 5)
	if animator and ((animation and animation:IsDescendantOf(animations)) or Speeding) then
		if ShouldPlay then
			if Speeding then
				local track, name = get_playing_animation(animator)
				if track then
					track:AdjustSpeed(speed)
					task.spawn(function()
						sync_allplayers_toplayer(track, player, animation, true)
					end)
				end
			else
				stop_otherDances(animator)
				animator.Parent.Parent:SetAttribute('Syncing', nil)
				if not check_ifPlaying(animator, animation.Name) then
					local animtrack = animator:LoadAnimation(animation)
					animtrack:Play(FADE_TIME)
					animtrack:AdjustSpeed(speed)
					task.spawn(function()
						sync_allplayers_toplayer(animtrack, player, animation, true)
					end)
					return 'playing'
				else
					task.spawn(function()
						sync_allplayers_toplayer(nil, player, nil, false)
					end)
					return 'stopped'
				end
			end
		end
	end
end

local function sync_player(player, targetedplayer, condition)
	local animator1 = get_animator(player)
	if animator1 then
		if condition then
			targetedplayer = get_main_source(targetedplayer)
			if targetedplayer then
				local animator2 = get_animator(targetedplayer)
				if animator2 then
					stop_otherDances(animator1)
					local maintrack, animationname = get_playing_animation(animator2)
					if maintrack and animationname then
						local animtrack = animator1:LoadAnimation(maintrack.Animation)
						animtrack:Play(FADE_TIME)
						animtrack:AdjustSpeed(maintrack.Speed)
						task.spawn(function()
							for _ = 1, 5 do
								animtrack.TimePosition = maintrack.TimePosition
								task.wait()
							end
						end)
						for _, v in pairs(game.Players:GetChildren()) do
							if v.Character and v.Character:GetAttribute('Syncing') == player.Name then
								sync_player(v, targetedplayer, true)
							end
						end
					end
				end
				animator1.Parent.Parent:SetAttribute("Syncing", targetedplayer.Name)
			end
		else
			stop_otherDances(animator1)
			animator1.Parent.Parent:SetAttribute('Syncing', nil)
		end
	end
end

local function speed_anim(player, speed)
	local char = player.Character
	if char and char:GetAttribute('Syncing') == nil then
		play_animation(player, nil, true, speed, true)
	end
end

---------- EVENTS ----------
remotes.playAnim.OnServerInvoke = play_animation
remotes.speedAnim.OnServerEvent:Connect(speed_anim)

---------- RUN ----------
for _, v in pairs(dancemodule.Dances) do
	local animation = Instance.new('Animation')
	animation.Name = v[1]
	animation.AnimationId = 'rbxassetid://'..v[2]
	animation.Parent = animations
end

for _, v in pairs(dancemodule.Emotes) do
	local animation = Instance.new('Animation')
	animation.Name = v[1]
	animation.AnimationId = 'rbxassetid://'..v[2]
	animation.Parent = animations
end

animations:SetAttribute('Loaded', true)
for _, v in pairs(animations:GetChildren()) do
	game:GetService('ContentProvider'):PreloadAsync({v})
end