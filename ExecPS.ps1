# Импорт из .csv + фильтр для бухов
$computers = Import-Csv -Path "C:\IT\Deployment\computers.csv" | 
             Where-Object { $_.Department -eq "Бухгалтерия" } | 
             Select-Object -ExpandProperty ComputerName

# Проверяем компьютеры
if (-not $computers) {
    Write-Warning "Не найдено компьютеров отдела Бухгалтерия в CSV файле"
    exit
}

# Путь к ZIP-архиву с Chocolatey на сетевой шаре
$chocoZipPath = "\\IT\Software\choco\chocolatey.zip"
# Временный каталог для распаковки на машинах
$tempChocoPath = "C:\Temp\ChocolateyInstall"

foreach ($computer in $computers) {
    try {
        # Проверяем доступность машины
        if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
            Write-Warning "$computer недоступен"
            Add-Content -Path "C:\IT\Deployment\failed.txt" -Value "$computer - недоступен по сети"
            continue
        }

        # Устанавливаем Chocolatey из архива
        $session = $null
        try {
            # Создаем сессию
            $session = New-PSSession -ComputerName $computer -ErrorAction Stop
            
            Invoke-Command -Session $session -ScriptBlock {
                param($zipPath, $installPath)
                
                # Создаем временный каталог
                if (-not (Test-Path $installPath)) {
                    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
                }
                
                # Копируем архив на целевую машину
                $localZipPath = Join-Path $env:TEMP "chocolatey.zip"
                Copy-Item -Path $zipPath -Destination $localZipPath -Force
                
                # Распаковываем архив
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($localZipPath, $installPath)
                } catch {
                    Write-Warning "Ошибка распаковки Chocolatey: $_"
                    throw
                }
                
                # Добавляем путь к Chocolatey в переменную PATH
                $chocoBinPath = Join-Path $installPath "tools"
                $envPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                if (-not $envPath.Contains($chocoBinPath)) {
                    [Environment]::SetEnvironmentVariable(
                        "PATH", 
                        "$envPath;$chocoBinPath", 
                        "Machine"
                    )
                    $env:PATH += ";$chocoBinPath"
                }
                
                # Устанавливаем переменную окружения ChocolateyInstall
                [Environment]::SetEnvironmentVariable(
                    "ChocolateyInstall", 
                    $installPath, 
                    "Machine"
                )
                
                # Добавляем локальный репозиторий
                Start-Sleep -Seconds 5 # Даем время для инициализации
                &amp; choco source add -n="LocalRepo" -s="\\IT\Software\choco" --priority=1 -ErrorAction Stop
                
                # Устанавливаем пакет
                &amp; choco install buh-software -y --source=LocalRepo --force -ErrorAction Stop
                
                # Очищаем временные файлы
                Remove-Item $localZipPath -Force -ErrorAction SilentlyContinue
                
            } -ArgumentList $chocoZipPath, $tempChocoPath -ErrorAction Stop

            Write-Host "$computer : установка завершена успешно" -ForegroundColor Green
        } catch {
            Write-Warning "Ошибка на $computer : $_"
            Add-Content -Path "C:\IT\Deployment\failed.txt" -Value "$computer - ошибка установки: $_"
        } finally {
            if ($session) { Remove-PSSession -Session $session }
        }
    }
    catch {
        Write-Warning "Ошибка при обработке $computer : $_"
        Add-Content -Path "C:\IT\Deployment\failed.txt" -Value "$computer - ошибка обработки: $_"
    }
}