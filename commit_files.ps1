$status = git status --porcelain
foreach ($line in $status) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $file = $line.Substring(3).Trim()
    
    if ($file.StartsWith('"') -and $file.EndsWith('"')) {
        $file = $file.Substring(1, $file.Length - 2)
    }
    
    if (Test-Path $file -PathType Leaf) {
        git add $file
        $basename = Split-Path $file -Leaf
        git commit -m "Update $basename"
    } elseif (Test-Path $file -PathType Container) {
        # Directory - get all files inside
        Get-ChildItem -Path $file -File -Recurse | ForEach-Object {
            $f = $_.FullName.Replace((Get-Location).Path + "\", "").Replace("\", "/")
            git add $f
            $b = $_.Name
            git commit -m "Add $b"
        }
    }
}
