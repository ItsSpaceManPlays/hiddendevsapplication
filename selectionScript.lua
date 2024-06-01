local ViewportPosition = Vector3.new(-82.61264038085938, 4.956138610839844, -2.969184398651123)
local VieportModelPos = Vector3.new(-78.3, 3, -0.8)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Towers = ReplicatedStorage:WaitForChild("Towers")

local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

local TOWER_ROTATION_INCREMENT = 45

local hoverColor = Color3.fromRGB(33, 33, 33)
local hoverOutlineColor = Color3.fromRGB(62, 62, 62)
local hoverOutlineTransparency = 0.2

local selectedColor = Color3.fromRGB(180, 180, 180)
local selectedOutlineColor = Color3.fromRGB(167, 167, 167)
local selectedOutlineTransparency = 0.6

local selectedTowerName = ""

local SELECT_MODE_NONE = 0
local SELECT_MODE_HOVER = 1
local SELECT_MODE_SELECTED = 2

local neonGreen = Color3.fromRGB(21, 111, 21)
local neonRed = Color3.fromRGB(165, 0, 3)

function highlightAreas(folder: Folder?, towerType: string)
	
	-- set all of them to be not visible
	for _, part in pairs(folder:GetDescendants()) do
		
		if part:IsA("Part") or part:IsA("UnionOperation") then
			
			part.Transparency = 1
			
		end
		
	end
	
	if towerType then
		
		-- set the one we want to highlight to be visible
		for _, part: Part | UnionOperation in pairs(folder[towerType]:GetChildren()) do
			
			part.Color = neonGreen
			part.Transparency = 0.9

		end
		
		-- make all the others red
		for _, planefolder in pairs(folder:GetChildren()) do
			
			if planefolder ~= folder[towerType] then
				
				for _, part: Part | UnionOperation in pairs(planefolder:GetChildren()) do

					part.Color = neonRed
					part.Transparency = 0.75

				end
				
			end
			
		end
		
	end
	
end

local numDefaultSize = UDim2.new(0.34, 0, 0.34, 0)
local numSelectSize = UDim2.new(0.4, 0, 0.4, 0)

-- this function just changes a frames look based on if its selected or not
function selectFrameHighlight(frame: Frame, mode: number)
	
	-- disable others
	for _, tFrame in pairs(script.Parent:GetChildren()) do
		
		if tFrame:IsA("Frame") then
			
			tFrame.SlotNum.Size = numDefaultSize
			tFrame.SlotNum.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
			
		end
		
	end
	
	if frame then
		
		local highlight: Frame = frame.SlotNum
		
		if mode == SELECT_MODE_NONE then
			
			highlight.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
			highlight.Size = numDefaultSize

		end

		if mode == SELECT_MODE_HOVER then

			highlight.BackgroundColor3 = Color3.fromRGB(44, 44, 44)

		end

		if mode == SELECT_MODE_SELECTED then
			
			highlight.Size = numSelectSize
			highlight.BackgroundColor3 = selectedColor

		end
		
	end
	
end

-- setup viewports and gui

for _, frame in pairs(script.Parent:GetChildren()) do
	
	if frame:IsA("Frame") then
		
		local towername: string = frame.TowerInternalName.Value
		
		if towername ~= "" then
			
			local cost = ReplicatedStorage.getTowerData:InvokeServer(towername, "Cost")
			local replicatedTemplate: Model = ReplicatedStorage.getTowerData:InvokeServer(towername, "Template")

			frame.Money.Text = "$"..cost
			frame.TowerName.Text = towername
			
			local viewportFrame: ViewportFrame = frame.ViewportFrame
			
			local newModel = replicatedTemplate:Clone()
			newModel.Parent = viewportFrame
			
			newModel:ScaleTo(1)
			newModel:PivotTo(CFrame.new(VieportModelPos) * CFrame.Angles(0, math.rad(90), 0))
			
			local tool = newModel:FindFirstChildOfClass("Tool")
			if tool then
				
				pcall(function()
					tool.Handle.CFrame = newModel.HumanoidRootPart.RightGripAttachment.WorldCFrame
				end)
				
			end
			
			local newCam = Instance.new("Camera", frame)
			newCam.CFrame = CFrame.new(ViewportPosition, newModel.PrimaryPart.Position + Vector3.new(0, newModel.PrimaryPart.Size.Y / 4 - 0.5, 0))
			
			viewportFrame.CurrentCamera = newCam
			
		else
			
			frame.Money.Text = "$0"
			frame.TowerName.Text = "None"
			
			frame.ViewportFrame.Visible = false
			
		end
		
		local selectButton: TextButton = frame.Select
		
		selectButton.MouseEnter:Connect(function()
			
			if selectedTowerName == "" then
				
				selectFrameHighlight(frame, SELECT_MODE_HOVER)
				
			end
			
		end)
		
		selectButton.MouseLeave:Connect(function()
			
			if selectedTowerName == "" then
				
				selectFrameHighlight(nil, SELECT_MODE_NONE)
				
			end
			
		end)
		
	end
	
end


UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean) 
	
	if input.UserInputType == Enum.UserInputType.Keyboard then
		
		if input.KeyCode == Enum.KeyCode.One then
			
			for _, frame in pairs(script.Parent:GetChildren()) do

				if frame:IsA("Frame") then
					
					local num: TextLabel = frame.SlotNum.Num

					if num.Text == "1" then

						local twrname = frame.TowerInternalName.Value

						if selectedTowerName ~= twrname then
							
							selectFrameHighlight(frame, SELECT_MODE_SELECTED)
							selectedTowerName = twrname
							beginTowerPlacement()

						end

					end
					
				end

			end
			
		end
		
	end
	
end)





-- make the buttons do something

local latestRay = nil


function MouseRaycast(params: RaycastParams): RaycastResult | nil
	
	local mousePos = UserInputService:GetMouseLocation()
	local mouseRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	latestRay = mouseRay

	local enemyRayResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 50, params)
	
	return enemyRayResult
	
end

function endTowerPlacement(towerPlaceholder: Model, towerRay: Ray, towerCFrame: CFrame)
	
	towerPlaceholder:Destroy()
	
	ReplicatedStorage.towerPlaceEvent:FireServer(towerRay.Origin, towerRay.Direction, towerCFrame, selectedTowerName)
	selectedTowerName = ""
	
	selectFrameHighlight(nil, SELECT_MODE_NONE)
	highlightAreas(workspace.TowerPlaceholderAreas, nil)
	
end

local towerRayParams = RaycastParams.new()
towerRayParams.FilterType = Enum.RaycastFilterType.Exclude

local towerRotation = 0

function beginTowerPlacement()
	
	local templateTower = Towers:FindFirstChild(selectedTowerName)
	if templateTower then
		
		local towerToSpawn: Model = templateTower:Clone()
		towerToSpawn.Name = "PlaceholderTower"
		towerToSpawn.Parent = workspace
		
		for _, v in pairs(towerToSpawn:GetDescendants()) do
			
			if v:IsA("BasePart") or v:IsA("MeshPart") then
				
				if v.Transparency < 1 then
					
					v.Transparency = 0.5
					v.CastShadow = false
					
				end
				v.CollisionGroup = "Towers"
				
			end
			
		end
		
		local towerRoot: Part = towerToSpawn:FindFirstChild("HumanoidRootPart")
		local towerHuman: Humanoid = towerToSpawn:FindFirstChild("Humanoid")
		
		local towerHighlight: Highlight = Instance.new("Highlight", towerToSpawn)
		towerHighlight.FillTransparency = 0.5
		towerHighlight.OutlineTransparency = 0.1
		
		towerRayParams.FilterDescendantsInstances = {towerToSpawn, player.Character, workspace.MapAI, workspace.Towers, workspace.TowerPlaceholderAreas}
		
		local towerCanPlace = false
		
		local cframe = nil
		
		local towerType = ReplicatedStorage.getTowerData:InvokeServer(selectedTowerName, "TowerType")
		highlightAreas(workspace.TowerPlaceholderAreas, towerType)
		
		local runEvent = RunService.RenderStepped:Connect(function()
			
			local result = MouseRaycast(towerRayParams)
			if result and result.Instance then
				
				if not result.Instance:HasTag("GroundUnit") then
					
					-- make it red
					towerHighlight.FillColor = Color3.fromRGB(200, 0, 0)
					towerHighlight.OutlineColor= Color3.fromRGB(200, 0, 0)
					towerCanPlace = false
					
				else
					
					-- make it green
					towerHighlight.FillColor = Color3.fromRGB(0, 154, 0)
					towerHighlight.OutlineColor = Color3.fromRGB(0, 200, 0)
					towerCanPlace = true
					
				end
				
				local x = result.Position.X
				local y = result.Position.Y + towerHuman.HipHeight + (towerRoot.Size.Y / 2)
				local z = result.Position.Z
				
				cframe = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(towerRotation), 0)
				
				towerToSpawn:PivotTo(cframe)
				
			end
			
		end)
		
		local clickEvent
		clickEvent = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean) 
			
			if not gameProcessedEvent then
				
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					
					if towerCanPlace then
						
						-- finish the thing and disconnect events
						endTowerPlacement(towerToSpawn, latestRay, cframe)

						runEvent:Disconnect()
						clickEvent:Disconnect()
						
					end
					
				end
					
				if input.UserInputType == Enum.UserInputType.Keyboard then
					
					if input.KeyCode == Enum.KeyCode.Q then

						towerRotation = towerRotation + TOWER_ROTATION_INCREMENT

					end

					if input.KeyCode == Enum.KeyCode.E then

						towerRotation = towerRotation - TOWER_ROTATION_INCREMENT

					end
					
					-- X to cancel place logic
					if input.KeyCode == Enum.KeyCode.X then
						
						towerToSpawn:Destroy()
						selectedTowerName = ""
						selectFrameHighlight(nil, SELECT_MODE_NONE)
						highlightAreas(workspace.TowerPlaceholderAreas, nil)
						
						runEvent:Disconnect()
						clickEvent:Disconnect()
						
					end
					
				end
				
			end
			
		end)
		
	else
		
		warn("No tower with the name "..selectedTowerName.." exists")
		
	end

end


for _, towerFrame in pairs(script.Parent:GetChildren()) do
	
	if towerFrame:IsA("Frame") then
		
		local selectButton: TextButton = towerFrame:FindFirstChild("Select")
		
		selectButton.Activated:Connect(function()
			
			local towerName = towerFrame.TowerInternalName.Value
			if selectedTowerName ~= towerName and towerName ~= "" then
				
				-- set it and start the placing function
				selectFrameHighlight(towerFrame, SELECT_MODE_SELECTED)
				
				selectedTowerName = towerName
				beginTowerPlacement()
				
			end
			
		end)
		
	end
	
end