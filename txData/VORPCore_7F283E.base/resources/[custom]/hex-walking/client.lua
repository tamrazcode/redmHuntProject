--[[
    Enhanced Movement Controller
    Version: 1.0.0
    Description: A customizable movement control system with auto-run feature
    
    Features:
    - Configurable movement speeds
    - Auto-run with camera following
    - Visual speed indicators
    - Progress bar for auto-run charging
--]]

-----------------------------------
-- Configuration
-----------------------------------
local Config = {
    -- Movement settings
    Movement = {
        MIN_SPEED = 0.2,        -- Minimum movement speed
        MAX_SPEED = 3.0,        -- Maximum movement speed
        SPEED_INCREMENT = 0.1,   -- Speed change per adjustment
        DEFAULT_SPEED = 1.0,    -- Default walking speed
        AUTO_RUN_SPEED = 1.6    -- Speed during auto-run
    },
    
    -- Visual display settings
    Display = {
        DISPLAY_TIME = 2000,    -- How long to show speed display (ms)
        -- Speed indicator visuals - thresholds and corresponding display text
        SPEED_INDICATORS = {
            {threshold = 0.3, text = "~COLOR_GREEN~+~COLOR_WHITE~++++"},    -- Slow
            {threshold = 0.5, text = "~COLOR_GREEN~++~COLOR_WHITE~+++"},    -- Normal
            {threshold = 0.7, text = "~COLOR_YELLOW~+++~COLOR_WHITE~++"},   -- Fast
            {threshold = 0.9, text = "~COLOR_ORANGE~++++~COLOR_WHITE~+"},   -- Very Fast
            {threshold = 1.0, text = "~COLOR_RED~+++++"}                    -- Maximum
        }
    },
    
    -- Auto-run feature settings
    AutoRun = {
        CHARGE_TIME = 2000,        -- Time to hold key for auto-run (ms)
        FORWARD_DISTANCE = 20.0    -- Distance to project movement target
    },
    
    -- Control key bindings
    Controls = {
        SPRINT = 0x8FFC75D6,         -- Left Shift
        INCREASE_SPEED = 0x6319DB71, -- Up Arrow
        DECREASE_SPEED = 0x05CA7C52, -- Down Arrow
        RESET_SPEED = 0xE30CD707,    -- R
        MAX_SPEED = 0xDEB34313,      -- Right Arrow
        MIN_SPEED = 0xA65EBAB4,      -- Left Arrow
        TOGGLE_AUTORUN = 0x760A9C6F, -- G
        CANCEL_AUTORUN = 0x8CC9CD42, -- X
        LOCK_CAMERA = 0x9959A6F0     -- C
    }
}

-----------------------------------
-- UI Class
-----------------------------------
---@class UI
local UI = {
    ---Creates a new UI instance
    ---@return table UI instance
    new = function()
        local self = {}
        
        ---Draws text in 2D space
        ---@param text string Text to display
        function self:DrawText2D(text)
            SetTextScale(0.5, 0.5)
            SetTextColor(255, 255, 255, 215)
            SetTextCentre(1)
            SetTextDropshadow(1, 0, 0, 0, 255)
            DisplayText(CreateVarString(10, "LITERAL_STRING", text), 0.5, 0.95)
        end
        
        ---Draws a progress bar
        ---@param x number X position
        ---@param y number Y position
        ---@param width number Bar width
        ---@param height number Bar height
        ---@param progress number Progress value (0-1)
        ---@param color table Color table {r,g,b,a}
        function self:DrawProgressBar(x, y, width, height, progress, color)
            -- Draw background
            local baseColor = {r = 50, g = 50, b = 50, a = 150}
            DrawRect(x, y, width, height, baseColor.r, baseColor.g, baseColor.b, baseColor.a)
            
            -- Draw progress
            local progressWidth = width * progress
            DrawRect(
                x - (width - progressWidth) / 2, 
                y, 
                progressWidth, 
                height, 
                color.r, 
                color.g, 
                color.b, 
                color.a
            )
        end
        
        return self
    end
}

-----------------------------------
-- Movement Controller Class
-----------------------------------
---@class MovementController
local MovementController = {
    ---Creates a new MovementController instance
    ---@return table MovementController instance
    new = function()
        local self = {
            -- State variables
            currentSpeed = Config.Movement.DEFAULT_SPEED,
            isSpeedChanged = false,
            showSpeedTimer = 0,
            isAutoRunActive = false,
            autoRunProgress = 0.0,
            isChargingAutoRun = false,
            chargeStartTime = 0,
            lastHeading = 0.0,
            ui = UI.new()
        }
        
        -- Private Methods
        
        ---Sets the player's movement speed
        ---@param speed number Speed value to set
        function self:SetPlayerSpeed(speed)
            if speed then
                SetPedMaxMoveBlendRatio(PlayerPedId(), speed)
            end
        end
        
        ---Gets the current camera direction
        ---@return number Camera heading in degrees
        function self:GetCameraDirection()
            local rot = GetGameplayCamRot(2)
            return rot.z
        end
        
        ---Updates the speed display timer
        function self:ShowSpeedDisplay()
            self.showSpeedTimer = GetGameTimer() + Config.Display.DISPLAY_TIME
        end
        
        ---Gets the appropriate speed indicator based on current speed
        ---@return string Speed indicator text
        function self:GetSpeedIndicator()
            local speedPercentage = (self.currentSpeed - Config.Movement.MIN_SPEED) / 
                                  (Config.Movement.MAX_SPEED - Config.Movement.MIN_SPEED)
            
            for _, indicator in ipairs(Config.Display.SPEED_INDICATORS) do
                if speedPercentage <= indicator.threshold then
                    return indicator.text
                end
            end
            return Config.Display.SPEED_INDICATORS[#Config.Display.SPEED_INDICATORS].text
        end
        
        ---Generates the speed display text
        ---@return string Formatted speed text
        function self:GetSpeedText()
            local statusText = self.isAutoRunActive and "~COLOR_GOLD~[AUTO-RUN]~COLOR_WHITE~" or ""
            return string.format("%sSpeed: %.1f %s", 
                               statusText, 
                               self.currentSpeed, 
                               self:GetSpeedIndicator())
        end
        
        ---Adjusts the current speed by the given increment
        ---@param increment number Amount to change speed by
        ---@return boolean Success of speed adjustment
        function self:AdjustSpeed(increment)
            local newSpeed = self.currentSpeed + increment
            if newSpeed >= Config.Movement.MIN_SPEED and newSpeed <= Config.Movement.MAX_SPEED then
                self.currentSpeed = newSpeed
                self.isSpeedChanged = true
                self:ShowSpeedDisplay()
                return true
            end
            return false
        end
        
        ---Handles auto-run movement logic
        ---@param playerPed number Player ped ID
        function self:HandleAutoRun(playerPed)
            if not self.isAutoRunActive then return end
            
            local pos = GetEntityCoords(playerPed)
            local currentHeading = GetEntityHeading(playerPed)
            
            -- Determine movement direction based on camera lock
            local useHeading, forwardX, forwardY
            if IsControlPressed(0, Config.Controls.LOCK_CAMERA) then
                -- Use current heading when camera is locked
                forwardX = -math.sin(math.rad(currentHeading))
                forwardY = math.cos(math.rad(currentHeading))
                useHeading = currentHeading
            else
                -- Follow camera direction
                local camHeading = self:GetCameraDirection()
                forwardX = -math.sin(math.rad(camHeading))
                forwardY = math.cos(math.rad(camHeading))
                useHeading = camHeading
                self.lastHeading = camHeading
            end
            
            -- Calculate target position
            local targetX = pos.x + (forwardX * Config.AutoRun.FORWARD_DISTANCE)
            local targetY = pos.y + (forwardY * Config.AutoRun.FORWARD_DISTANCE)
            local targetZ = pos.z
            
            -- Move to target
            TaskGoStraightToCoord(
                playerPed,
                targetX,
                targetY,
                targetZ,
                Config.Movement.AUTO_RUN_SPEED,
                -1,
                useHeading,
                0.0
            )
        end
        
        ---Stops auto-run mode
        ---@param playerPed number Player ped ID
        function self:StopAutoRun(playerPed)
            self.isAutoRunActive = false
            self.currentSpeed = Config.Movement.DEFAULT_SPEED
            self.isSpeedChanged = false
            self:ShowSpeedDisplay()
            ClearPedTasks(playerPed)
        end
        
        ---Checks if the player is in a dead or incapacitated state
        ---@param playerPed number Player ped ID
        ---@return boolean Is player dead or incapacitated
        function self:IsPlayerDead(playerPed)
            local hogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, playerPed)
            local cuffed = Citizen.InvokeNative(0x74E559B3BC910685, playerPed)
            return IsEntityDead(playerPed) or IsPedDeadOrDying(playerPed, true) or hogtied or cuffed
        end
        
        ---Main update function called every frame
        function self:Update()
            local playerPed = PlayerPedId()
            
            -- Handle auto-run charging
            self:HandleAutoRunCharging(playerPed)
            
            -- Handle auto-run state
            self:HandleAutoRunState(playerPed)
            
            -- Update speed and display
            self:UpdateSpeedAndDisplay(playerPed)
            
            -- Handle speed controls
            self:HandleSpeedControls()
        end
        
        ---Handles the auto-run charging mechanic
        ---@param playerPed number Player ped ID
        function self:HandleAutoRunCharging(playerPed)
            if IsControlPressed(0, Config.Controls.TOGGLE_AUTORUN) and IsPedSprinting(playerPed) then
                if not self.isChargingAutoRun then
                    self.isChargingAutoRun = true
                    self.chargeStartTime = GetGameTimer()
                end
                
                local elapsedTime = GetGameTimer() - self.chargeStartTime
                self.autoRunProgress = math.min(1.0, elapsedTime / Config.AutoRun.CHARGE_TIME)
                
                self.ui:DrawProgressBar(0.5, 0.75, 0.2, 0.02, 
                                      self.autoRunProgress, 
                                      {r = 255, g = 165, b = 0, a = 200})
                
                if self.autoRunProgress >= 1.0 and not self.isAutoRunActive then
                    self:ActivateAutoRun(playerPed)
                end
            else
                self.isChargingAutoRun = false
                self.autoRunProgress = 0.0
            end
        end
        
        ---Activates auto-run mode
        ---@param playerPed number Player ped ID
        function self:ActivateAutoRun(playerPed)
            self.isAutoRunActive = true
            self.currentSpeed = Config.Movement.AUTO_RUN_SPEED
            self.isSpeedChanged = true
            self:ShowSpeedDisplay()
            self.lastHeading = GetEntityHeading(playerPed)
        end
        
        ---Handles the auto-run state checks and updates
        ---@param playerPed number Player ped ID
        function self:HandleAutoRunState(playerPed)
            if self.isAutoRunActive then
                if IsControlJustPressed(0, Config.Controls.CANCEL_AUTORUN) or self:IsPlayerDead(playerPed) then
                    self:StopAutoRun(playerPed)
                else
                    self:HandleAutoRun(playerPed)
                end
            end
        end
        
        ---Updates speed and handles display
        ---@param playerPed number Player ped ID
        function self:UpdateSpeedAndDisplay(playerPed)
            if self.isSpeedChanged then
                self:SetPlayerSpeed(self.currentSpeed)
            end
            
            if GetGameTimer() < self.showSpeedTimer or self.isAutoRunActive then
                self.ui:DrawText2D(self:GetSpeedText())
            end
        end
        
        ---Handles speed control inputs
        function self:HandleSpeedControls()
            if not self.isAutoRunActive and IsControlPressed(0, Config.Controls.SPRINT) then
                -- Speed increase
                if IsControlJustPressed(0, Config.Controls.INCREASE_SPEED) then
                    self:AdjustSpeed(Config.Movement.SPEED_INCREMENT)
                
                -- Speed decrease
                elseif IsControlJustPressed(0, Config.Controls.DECREASE_SPEED) then
                    self:AdjustSpeed(-Config.Movement.SPEED_INCREMENT)
                
                -- Reset speed
                elseif IsControlJustPressed(0, Config.Controls.RESET_SPEED) then
                    self.currentSpeed = Config.Movement.DEFAULT_SPEED
                    self.isSpeedChanged = false
                    self:ShowSpeedDisplay()
                
                -- Set maximum speed
                elseif IsControlJustPressed(0, Config.Controls.MAX_SPEED) then
                    self.currentSpeed = Config.Movement.MAX_SPEED
                    self.isSpeedChanged = true
                    self:ShowSpeedDisplay()
                
                -- Set minimum speed
                elseif IsControlJustPressed(0, Config.Controls.MIN_SPEED) then
                    self.currentSpeed = Config.Movement.MIN_SPEED
                    self.isSpeedChanged = true
                    self:ShowSpeedDisplay()
                end
            end
        end
        
        return self
    end
}

-----------------------------------
-- Main Thread
-----------------------------------
CreateThread(function()
    local controller = MovementController.new()
    while true do
        Wait(0)
        controller:Update()
    end
end)