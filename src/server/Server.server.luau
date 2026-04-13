local ServerScriptService = game:GetService("ServerScriptService")
local ServicesFolder = ServerScriptService:WaitForChild("Services")

local loadedServices = {}

-- 1. Fase Require: Memuat semua modul ke dalam memori
for _, module in ipairs(ServicesFolder:GetChildren()) do
	if module:IsA("ModuleScript") then
		local success, service = pcall(require, module)
		if success and type(service) == "table" then
			loadedServices[module.Name] = service
			print("[Server] Loaded Service: " .. module.Name)
		else
			warn("[Server] Failed to load service: " .. module.Name .. " | Error: " .. tostring(service))
		end
	end
end

-- 2. Fase Init: Inisialisasi awal (Sinkron)
-- Digunakan untuk mendaftarkan RemoteEvents/Functions sebelum ada yang memanggilnya
for name, service in pairs(loadedServices) do
	if type(service.Init) == "function" then
		local success, err = pcall(function()
			service:Init()
		end)
		if not success then
			warn("[Server] Error during Init() in " .. name .. ": " .. tostring(err))
		end
	end
end

-- 3. Fase Start: Menjalankan logika utama (Asinkron)
-- Dibungkus task.spawn agar loop (seperti while true) di satu service tidak menghentikan service lainnya
for name, service in pairs(loadedServices) do
	if type(service.Start) == "function" then
		task.spawn(function()
			local success, err = pcall(function()
				service:Start()
			end)
			if not success then
				warn("[Server] Error during Start() in " .. name .. ": " .. tostring(err))
			end
		end)
	end
end

print("[Server] All Services Started Successfully.")