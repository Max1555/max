#$computers = "PC1"

# Проверяем компьютеры
if (-not $computers) {
    Write-Warning "Не найдено компьютеров. Должен быть задан список в computers "
    Pause
    exit
}

$computers
