-- LocalScript: AnimationClient.lua
-- Integration dengan AnimationHandler.lua (Server Side)
-- Supports: Dances, Emotes, Favorites, Search, Speed Control

---------- SERVICES ----------
local TS = game:GetService('TweenService')
local RS = game:GetService('ReplicatedStorage')
local CS = game:GetService('ContentProvider')
local UIS = game:GetService('UserInputService')
local RunS = game:GetService('RunService')

---------- ROOT & VARIABLES ----------
local guiRoot = script.Parent
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild('Humanoid')
local animator = hum:WaitForChild('Animator')

local animationassets = RS:WaitForChild('AnimationAssets')
local remotes = animationassets:WaitForChild('Remotes')
local animationsfolder = animationassets:WaitForChild('Animations')
local dancemodule = require(animationassets:WaitForChild('DanceModule'))
local globalmodule = require(animationassets:WaitForChild('GlobalFunction'))

local mainframe = guiRoot:WaitForChild('MainFrame')
local searchbar = mainframe:WaitForChild('SearchBar')
local speedframe = mainframe:WaitForChild('SpeedFrame')

local AnimBtn = mainframe:WaitForChild('AnimBtn')
local AnimContainer = mainframe:WaitForChild('AnimationContainer')
local EmoteBtn = mainframe:WaitForChild('EmoteBtn')
local EmoteContainer = mainframe:WaitForChild('EmoteContainer')

---------- STATE ----------
local db = false
local animBtnsTable = {}
local currentanimtrack = nil
local holding = false
local currentspeed = 1
local currentView = "Animation" -- "Animation" | "Emote" | "Favorite"

---------- FAVORITES SYSTEM ----------
local favorites = {}
local favSet = {}

local getFavoritesRemote = remotes:FindFirstChild("GetFavorites")
local setFavoritesRemote = remotes:FindFirstChild("SetFavorites")

local pushScheduled = false
local function pushFavoritesToServerThrottled()
	if not setFavoritesRemote or not setFavoritesRemote:IsA("RemoteEvent") then return end
	if pushScheduled then return end
	pushScheduled = true
	task.spawn(function()
		task.wait(3)
		local copy = {}
		for i,v in ipairs(favorites) do copy[i] = v end
		pcall(function() setFavoritesRemote:FireServer(copy) end)
		pushScheduled = false
	end)
end

local function fetchFavoritesFromServer()
	if getFavoritesRemote and getFavoritesRemote:IsA("RemoteFunction") then
		local ok, result = pcall(function() return getFavoritesRemote:InvokeServer() end)
		if ok and type(result) == "table" then
			favorites = {}
			favSet = {}
			for i, name in ipairs(result) do
				if type(name) == "string" then
					table.insert(favorites, name)
					favSet[name] = true
				end
			end
			return
		end
	end
	favorites = {}
	favSet = {}
end

---------- HELPERS ----------
local function snap(n,f)
	if f == 0 then return n end
	return math.floor(n/f+0.5)*f
end

local function play_anim(animation, btn, condition)
	local ok, req = pcall(function()
		return remotes.playAnim:InvokeServer(animation, true, currentspeed)
	end)
	if currentanimtrack then
		pcall(function() currentanimtrack.BackgroundColor3 = Color3.fromRGB(48,48,48) end)
	end
	if not ok then
		warn("[play_anim] remote error:", req)
		return
	end
	if req == 'playing' then
		if btn then btn.BackgroundColor3 = Color3.fromRGB(94,94,94) end
		currentanimtrack = btn
	elseif req == 'stopped' then
		if btn then btn.BackgroundColor3 = Color3.fromRGB(48,48,48) end
		currentanimtrack = nil
	end
end

local function setSampleFavoriteVisual(sample, isFav)
	local favIcon = sample:FindFirstChild("FavIcon")
	if not favIcon then return end
	if isFav then
		favIcon.Text = "★"
		favIcon.TextColor3 = Color3.fromRGB(255,210,0)
		sample:SetAttribute("Favorite", true)
	else
		favIcon.Text = "☆"
		favIcon.TextColor3 = Color3.fromRGB(180,180,180)
		sample:SetAttribute("Favorite", false)
	end
end

local function toggleFavorite(sample)
	local name = sample.Name
	if favSet[name] then
		favSet[name] = nil
		for i,v in ipairs(favorites) do if v == name then table.remove(favorites,i); break end end
		setSampleFavoriteVisual(sample, false)
	else
		favSet[name] = true
		table.insert(favorites, 1, name)
		setSampleFavoriteVisual(sample, true)
	end
	pushFavoritesToServerThrottled()
	if currentView == "Favorite" then
		for _, btn in pairs(animBtnsTable) do
			btn.Visible = favSet[btn.Name] == true
		end
	end
end

local function createFavIconIfNeeded(sample)
	local favIcon = sample:FindFirstChild("FavIcon")
	if not favIcon then
		favIcon = Instance.new("TextButton")
		favIcon.Name = "FavIcon"
		favIcon.Parent = sample
		favIcon.AnchorPoint = Vector2.new(1,0.5)
		favIcon.Position = UDim2.new(1, -8, 0.5, 0)
		favIcon.Size = UDim2.new(0, 20, 0, 20)
		favIcon.BackgroundTransparency = 1
		favIcon.Font = Enum.Font.GothamBold
		favIcon.TextScaled = true
		favIcon.Text = "☆"
		favIcon.TextColor3 = Color3.fromRGB(180,180,180)
		favIcon.ZIndex = sample.ZIndex + 2
	end
	favIcon.MouseButton1Click:Connect(function()
		if db then return end
		db = true
		toggleFavorite(sample)
		task.wait(0.12)
		db = false
	end)
	return favIcon
end

---------- UI SWITCH ----------
local function open_frame(frameName)
	currentView = frameName
	if frameName == 'Animation' then
		AnimBtn.BackgroundColor3 = Color3.fromRGB(255,255,255); AnimBtn.BackgroundTransparency = 0
		EmoteBtn.BackgroundColor3 = Color3.fromRGB(104,104,104); EmoteBtn.BackgroundTransparency = 0.5
		AnimContainer.Visible = true; EmoteContainer.Visible = false
		local keyword = string.lower(searchbar.Box.Text or "")
		for _, btn in pairs(animBtnsTable) do
			btn.Visible = (keyword == "" or string.find(string.lower(btn.Name), keyword))
		end
	elseif frameName == 'Emote' then
		EmoteBtn.BackgroundColor3 = Color3.fromRGB(255,255,255); EmoteBtn.BackgroundTransparency = 0
		AnimBtn.BackgroundColor3 = Color3.fromRGB(104,104,104); AnimBtn.BackgroundTransparency = 0.5
		AnimContainer.Visible = false; EmoteContainer.Visible = true
	elseif frameName == 'Favorite' then
		AnimBtn.BackgroundColor3 = Color3.fromRGB(104,104,104); AnimBtn.BackgroundTransparency = 0.5
		EmoteBtn.BackgroundColor3 = Color3.fromRGB(104,104,104); EmoteBtn.BackgroundTransparency = 0.5
		AnimContainer.Visible = true; EmoteContainer.Visible = false
		local keyword = string.lower(searchbar.Box.Text or "")
		for _, btn in pairs(animBtnsTable) do
			local isFav = favSet[btn.Name] == true
			btn.Visible = isFav and (keyword == "" or string.find(string.lower(btn.Name), keyword))
		end
	end
end

---------- CREATION OF SAMPLES ----------
local function create_sample(v, container, order)
	local ok, ret = pcall(function()
		local sample = script.sample:Clone()
		sample.Name = v.Name
		sample.TextLabel.Text = v.Name
		sample.Size = UDim2.new(1, -8, 0, 36)
		sample.LayoutOrder = order
		sample.Parent = container
		sample:SetAttribute("DefaultOrder", order)
		if sample:FindFirstChild("TextLabel") then
			sample.TextLabel.TextScaled = false
			sample.TextLabel.TextSize = 14
		end
		globalmodule.add_animations(sample, sample.UIScale)
		createFavIconIfNeeded(sample)
		if favSet[v.Name] then setSampleFavoriteVisual(sample, true) else setSampleFavoriteVisual(sample, false) end
		sample.Button.MouseButton1Click:Connect(function()
			if not db then
				db = true
				sample:SetAttribute('Clicked', true)
				play_anim(v, sample, true)
				task.wait(0.2)
				db = false
				sample:SetAttribute('Clicked', false)
			end
		end)
		return sample
	end)
	if not ok then
		warn('There was an error setting up the Animation('..tostring(v.Name)..'). Error: '..tostring(ret))
		return nil
	end
	return ret
end

local function load_keyword()
	local keyword = string.lower(searchbar.Box.Text or "")
	for _, v in pairs(animBtnsTable) do
		local matches = (keyword == "" or string.find(string.lower(v.Name), keyword))
		if currentView == "Favorite" then
			v.Visible = (favSet[v.Name] == true) and matches
		elseif currentView == "Emote" then
			v.Visible = false
		else
			v.Visible = matches
		end
	end
end

---------- INPUT & SLIDER HANDLING ----------
UIS.InputEnded:Connect(function(input, gpe)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = false; db = false
	end
end)
UIS.TouchEnded:Connect(function() holding = false; db = false end)
speedframe.bar.dot.Button.MouseButton1Down:Connect(function()
	if not db then db = true; holding = true end
end)
RunS.RenderStepped:Connect(function()
	if holding then
		local mousepos = UIS:GetMouseLocation().X
		local barsize = speedframe.bar.AbsoluteSize.X
		local barpos = speedframe.bar.AbsolutePosition.X
		local pos = 0
		if barsize ~= 0 then pos = snap((mousepos - barpos) / barsize, 0.02) end
		local scale = math.clamp(pos, 0, 1)
		speedframe.bar.dot.Position = UDim2.fromScale(scale, 0.5)
		local newspeed = (math.round(speedframe.bar.dot.Position.X.Scale * 100) / 20)
		if newspeed and currentspeed ~= newspeed then
			currentspeed = newspeed
			speedframe.TextLabel.Text = currentspeed..'x'
			if currentanimtrack then
				pcall(function() remotes.speedAnim:FireServer(currentspeed) end)
			end
		end
	end
end)

---------- EVENTS ----------
AnimBtn.MouseButton1Click:Connect(function()
	if db then return end
	db = true; open_frame('Animation'); task.wait(0.2); db = false
end)
EmoteBtn.MouseButton1Click:Connect(function()
	if db then return end
	db = true; open_frame('Emote'); task.wait(0.2); db = false
end)
searchbar.Box:GetPropertyChangedSignal('Text'):Connect(load_keyword)

remotes:WaitForChild('open_frame').Event:Connect(function(name, condition)
	if name == 'animation' then guiRoot.MainFrame.Visible = condition end
end)

---------- BUTTON HEADER WITH FAVORITES ICON ----------
local buttonHeader = mainframe:FindFirstChild("ButtonHeader")
if not buttonHeader then
	buttonHeader = Instance.new("Frame")
	buttonHeader.Name = "ButtonHeader"
	buttonHeader.Size = UDim2.new(1, 0, 0, 50)
	buttonHeader.Position = UDim2.new(0, 0, 0, 0)
	buttonHeader.BackgroundTransparency = 1
	buttonHeader.Parent = mainframe
	
	if not buttonHeader:FindFirstChild("UIListLayout") then
		local listLayout = Instance.new("UIListLayout")
		listLayout.Direction = Enum.FillDirection.Horizontal
		listLayout.Padding = UDim.new(0, 8)
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listLayout.Parent = buttonHeader
	end
	
	if AnimBtn and AnimBtn.Parent == mainframe then
		AnimBtn.Parent = buttonHeader
	end
	if EmoteBtn and EmoteBtn.Parent == mainframe then
		EmoteBtn.Parent = buttonHeader
	end
end

local FavoritesIcon = mainframe:FindFirstChild("FavoritesIcon") or buttonHeader:FindFirstChild("FavoritesIcon")
if not FavoritesIcon then
	local icon = Instance.new("TextButton")
	icon.Name = "FavoritesIcon"
	icon.Parent = buttonHeader
	icon.Size = UDim2.new(0, 22, 0, 22)
	icon.BackgroundTransparency = 0
	icon.BackgroundColor3 = Color3.fromRGB(104, 104, 104)
	icon.AutoButtonColor = true
	icon.Font = Enum.Font.GothamBold
	icon.Text = "★"
	icon.TextSize = 16
	icon.TextColor3 = Color3.fromRGB(255,255,255)
	icon.ZIndex = mainframe.ZIndex + 5
	pcall(function() Instance.new("UICorner", icon).CornerRadius = UDim.new(0,6) end)
	FavoritesIcon = icon
end

FavoritesIcon.MouseButton1Click:Connect(function()
	if db then return end
	db = true
	if currentView == "Favorite" then open_frame("Animation") else open_frame("Favorite") end
	task.wait(0.12)
	db = false
end)

---------- INITIALIZATION ----------
db = false
open_frame('Animation')
fetchFavoritesFromServer()

repeat task.wait() until animationsfolder:GetAttribute('Loaded') == true

for i, v in ipairs(dancemodule.Dances) do
	local animationinstance = animationsfolder:FindFirstChild(v[1])
	if animationinstance then
		local btn = create_sample(animationinstance, AnimContainer, i)
		if btn then table.insert(animBtnsTable, btn) end
	end
end

for i, v in ipairs(dancemodule.Emotes) do
	local animationinstance = animationsfolder:FindFirstChild(v[1])
	if animationinstance then
		local btn = create_sample(animationinstance, EmoteContainer, i)
		if btn then table.insert(animBtnsTable, btn) end
	end
end

for _, v in ipairs(animationsfolder:GetChildren()) do
	pcall(function() CS:PreloadAsync({v}) end)
end

db = false
load_keyword()

guiRoot.AncestryChanged:Connect(function()
	if not guiRoot:IsDescendantOf(game) then
		-- cleanup
	end
end)
