-- =========================================================================
-- Client.client.luau
-- "Sang Bos" untuk Client. Bertugas memuat dan menjalankan semua Controllers.
-- =========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ambil referensi ke folder Controllers milikmu
local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
-- Karena di Antigravity kita taruh di src/client/Controllers, 
-- di Roblox ini akan berada di PlayerScripts.Controllers
local ControllersFolder = PlayerScripts:WaitForChild("Controllers")

local loadedControllers = {}

-- =========================================================================
-- 1. Fase Require: Memuat semua modul Controller ke dalam memori
-- =========================================================================
for _, module in ipairs(ControllersFolder:GetChildren()) do
	if module:IsA("ModuleScript") then
		local success, controller = pcall(require, module)
		if success and type(controller) == "table" then
			loadedControllers[module.Name] = controller
			print("[Client] Loaded Controller: " .. module.Name)
		else
			warn("[Client] Failed to load controller: " .. module.Name .. " | Error: " .. tostring(controller))
		end
	end
end

-- =========================================================================
-- 2. Fase Init: Inisialisasi Awal (Sinkron)
-- Digunakan untuk setup UI, mengambil referensi RemoteEvent, dll
-- =========================================================================
for name, controller in pairs(loadedControllers) do
	if type(controller.Init) == "function" then
		local success, err = pcall(function()
			controller:Init()
		end)
		if not success then
			warn("[Client] Error during Init() in " .. name .. ": " .. tostring(err))
		end
	end
end

-- =========================================================================
-- 3. Fase Start: Menjalankan logika utama (Asinkron)
-- Digunakan untuk mendengarkan event dari server (OnClientEvent) atau loop
-- =========================================================================
for name, controller in pairs(loadedControllers) do
	if type(controller.Start) == "function" then
		task.spawn(function()
			local success, err = pcall(function()
				controller:Start()
			end)
			if not success then
				warn("[Client] Error during Start() in " .. name .. ": " .. tostring(err))
			end
		end)
	end
end

print("[Client] All Controllers Started Successfully.")

-- Opsional: Menyediakan cara global agar satu Controller bisa memanggil Controller lain
-- Contoh: _G.GetController("UIController"):ShowMenu()
_G.GetController = function(controllerName)
	local controller = loadedControllers[controllerName]
	if not controller then
		warn("[Client] GetController failed: " .. tostring(controllerName) .. " does not exist.")
	end
	return controller
end