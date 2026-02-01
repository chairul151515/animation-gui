local container  = script.Parent
local Icon = require(container.Topbar.Icon)

local TweenService = game:GetService("TweenService")

local StarterGui4 = game.Players.LocalPlayer.PlayerGui:WaitForChild("AnimationUi")
local Frame4 = StarterGui4:WaitForChild("MainFrame")
Icon.new()
	:setLabel("Close", "Selected")
	:setImage(76460329147890, "Deselected")
	:setImage(76460329147890, "Selected")
	:setImageScale(.6)
	:bindEvent("selected", function() -- tween in
		local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut) -- 0.25 seconds for faster tweening
		local goal = {Position = UDim2.new(0.755, 0,0.208, 0)}
		local tween = TweenService:Create(Frame4, tweenInfo, goal)
		tween:Play()
	end)
	:bindEvent("deselected", function() -- tween out
		local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut) -- 0.25 seconds for faster tweening
		local goal = {Position = UDim2.new(2, 0,0.208, 0)}
		local tween = TweenService:Create(Frame4, tweenInfo, goal)
		tween:Play()
	end)