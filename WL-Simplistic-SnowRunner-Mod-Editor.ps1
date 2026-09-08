$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppName = 'WL Simplistic SnowRunner Mod Editor v1.1.3'
$script:AppRoot = if ($env:WL_SSME_ROOT) { $env:WL_SSME_ROOT } else { $PSScriptRoot }
$script:SettingsPath = Join-Path $script:AppRoot 'WL-Settings.json'
$script:Fields = @{}
$script:Combos = @{}
$script:Checks = @{}
$script:UpdateDetected = $false
$script:TruckTargets = @{}
$script:wlDamageCapHits = 0
$script:wlDamageMultHits = 0

function Format-Number([double]$Value) {
    return $Value.ToString('0.############', [Globalization.CultureInfo]::InvariantCulture)
}

function Read-Multiplier([string]$Name) {
    $raw = $script:Fields[$Name].Text.Trim()
    $value = 0.0
    if (-not [double]::TryParse($raw, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
        throw "'$raw' is not a valid value for $Name. Use a number such as 1.25."
    }
    if ($value -lt 0 -or $value -gt 100) {
        throw "$Name must be between 0 and 100."
    }
    return $value
}

function Read-Offset([string]$Name) {
    $value = Read-Multiplier $Name
    if ($value -gt 5) { throw "$Name must be between 0.00 and 5.00 meters." }
    return $value
}

function Get-Settings {
    if ($cmbTruck.SelectedItem -and ([string]$cmbTruck.SelectedItem -like '[[]MOD[]]*')) {
        throw 'v1.1.1 modifies official trucks only. Mod trucks remain discovery-only until separate per-mod backup/restore protection is implemented.'
    }
    return [ordered]@{
        SettingsVersion = 2
        PakPath = $txtPak.Text.Trim()
        TargetTruck = if ($cmbTruck.SelectedItem) { [string]$cmbTruck.SelectedItem } else { 'All Trucks' }
        TargetTruckId = $(
            $selectedTruckText = if ($cmbTruck.SelectedItem) { [string]$cmbTruck.SelectedItem } else { 'All Trucks' }
            if ($selectedTruckText -eq 'All Trucks') { '' }
            elseif ($script:TruckTargets.ContainsKey($selectedTruckText)) { [string]$script:TruckTargets[$selectedTruckText] }
            elseif ($selectedTruckText -match '\[([^\[\]]+)\]\s*$') { [string]$Matches[1] }
            else { throw "TEST 6.9 safety stop: a specific truck is selected, but its internal truck ID could not be resolved. No modifications were made." }
        )
        TargetTruckEntry = ''
        IndividualServiceAddonEntries = @()
        IndividualCraneAddonEntries = @()
        IndividualEngineSourceEntry = ''
        IndividualEngineSourceEntries = @()
        IndividualEngineTypes = @()
        IndividualEngineCloneEntry = ''
        IndividualEngineCloneType = ''
        SharedEngineType = ''
        SharedEngineTruckUsers = 0
        SharedGearboxType = ''
        SharedGearboxDefault = ''
        SharedGearboxTruckUsers = 0
        IndividualTireSourceEntry = ''
        IndividualTireDefault = ''
        IndividualTireWheelType = ''
        IndividualTirePrivateName = ''
        IndividualWheelSourceEntry = ''
        IndividualWheelType = ''
        IndividualWheelPrivateType = ''
        IndividualWheelPrivateEntry = ''
        TestStockWheelSwap = [bool]$chkStockWheelSwap.Checked
        TestStockWheelSwapType = ''
        TestStockWheelSwapTire = ''
        EngineTorque = Read-Multiplier 'Engine torque'
        EngineResponse = Read-Multiplier 'Engine responsiveness'
        EngineFuel = Read-Multiplier 'Engine fuel consumption'
        EngineDurability = Read-Multiplier 'Engine durability'
        GearboxFuel = Read-Multiplier 'Gearbox fuel consumption'
        GearTuning = if ($script:Combos.ContainsKey('Gear tuning') -and $script:Combos['Gear tuning'].SelectedItem) { [string]$script:Combos['Gear tuning'].SelectedItem } else { 'Stock' }
        GearSpeed = Get-GearTuningFactor $(if ($script:Combos.ContainsKey('Gear tuning') -and $script:Combos['Gear tuning'].SelectedItem) { [string]$script:Combos['Gear tuning'].SelectedItem } else { 'Stock' })
        GearboxDurability = Read-Multiplier 'Gearbox durability'
        AwdFuel = Read-Multiplier 'AWD fuel penalty'
        IdleFuel = Read-Multiplier 'Idle fuel use'
        SteeringAngle = Read-Multiplier 'Maximum steering angle'
        SteeringResponse = Read-Multiplier 'Steering response'
        TireAsphalt = Read-Multiplier 'Tire asphalt grip'
        TireOffroad = Read-Multiplier 'Tire off-road grip'
        TireMud = Read-Multiplier 'Tire mud grip'
        TireDurability = Read-Multiplier 'Tire durability'
        SuspensionStrength = Read-Multiplier 'Suspension strength'
        SuspensionHeight = Read-Multiplier 'Suspension height'
        SuspensionDamping = Read-Multiplier 'Suspension damping'
        SuspensionDurability = Read-Multiplier 'Suspension durability'
        FuelCapacity = Read-Multiplier 'Truck fuel capacity'
        FuelTankDurability = Read-Multiplier 'Fuel tank durability'
        WinchStrength = Read-Multiplier 'Winch strength'
        WinchLength = Read-Multiplier 'Winch length'
        CraneStrength = Read-Multiplier 'Crane strength'
        CraneSpeed = Read-Multiplier 'Crane speed'
        ServiceFuel = Read-Multiplier 'Service fuel capacity'
        ServiceRepairs = Read-Multiplier 'Service repair points'
        ServiceWheels = Read-Multiplier 'Service spare wheels'
        CargoMass = Read-Multiplier 'Cargo mass'
        TruckPrice = Read-Multiplier 'Truck prices'
        UpgradePrice = Read-Multiplier 'Upgrade/addon prices'
        TruckCgDrop = Read-Offset 'Truck center-of-gravity drop'
        AddonCgDrop = Read-Offset 'Addon/trailer center-of-gravity drop'
        AlwaysAWD = $script:Checks['Always AWD'].Checked
        AlwaysDiff = $script:Checks['Always differential lock (unchecked = default)'].Checked
        DisableAllDamage = $script:Checks['Extreme durability (GLOBAL)'].Checked
        AutonomousWinches = $script:Checks['Autonomous winches'].Checked
        UnlockTrucks = $script:Checks['Unlock all trucks'].Checked
        AllRegions = $script:Checks['All trucks in all regions'].Checked
        UnlockUpgrades = $script:Checks['Unlock all upgrades/addons'].Checked
    }
}

function Save-Settings($Settings) {
    $Settings | ConvertTo-Json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
}

function Load-Settings {
    if (-not (Test-Path -LiteralPath $script:SettingsPath)) { return }
    try {
        $s = Get-Content -LiteralPath $script:SettingsPath -Raw | ConvertFrom-Json
        if ($s.PakPath) { $txtPak.Text = $s.PakPath }
        $map = @{
            'Engine torque'='EngineTorque'; 'Engine responsiveness'='EngineResponse'; 'Engine fuel consumption'='EngineFuel'
            'Engine durability'='EngineDurability'; 'Gearbox fuel consumption'='GearboxFuel'; 'Gearbox durability'='GearboxDurability'; 'AWD fuel penalty'='AwdFuel'; 'Idle fuel use'='IdleFuel'
            'Maximum steering angle'='SteeringAngle'; 'Steering response'='SteeringResponse'
            'Tire asphalt grip'='TireAsphalt'; 'Tire off-road grip'='TireOffroad'; 'Tire mud grip'='TireMud'; 'Tire durability'='TireDurability'
            'Suspension strength'='SuspensionStrength'; 'Suspension height'='SuspensionHeight'; 'Suspension damping'='SuspensionDamping'
            'Suspension durability'='SuspensionDurability'; 'Truck fuel capacity'='FuelCapacity'; 'Fuel tank durability'='FuelTankDurability'
            'Winch strength'='WinchStrength'; 'Winch length'='WinchLength'; 'Crane strength'='CraneStrength'; 'Crane speed'='CraneSpeed'
            'Service fuel capacity'='ServiceFuel'; 'Service repair points'='ServiceRepairs'; 'Service spare wheels'='ServiceWheels'
            'Cargo mass'='CargoMass'; 'Truck prices'='TruckPrice'; 'Upgrade/addon prices'='UpgradePrice'
            'Truck center-of-gravity drop'='TruckCgDrop'; 'Addon/trailer center-of-gravity drop'='AddonCgDrop'
        }
        foreach ($name in $map.Keys) {
            $prop = $map[$name]
            if ($null -ne $s.$prop) { $script:Fields[$name].Text = Format-Number ([double]$s.$prop) }
        }
        if ($script:Combos.ContainsKey('Gear tuning')) {
            $gp = if ($s.GearTuning) { [string]$s.GearTuning } else { 'Stock' }
            if ($script:Combos['Gear tuning'].Items.Contains($gp)) { $script:Combos['Gear tuning'].SelectedItem = $gp } else { $script:Combos['Gear tuning'].SelectedItem = 'Stock' }
        }
        $checks = @{'Always AWD'='AlwaysAWD';'Always differential lock (unchecked = default)'='AlwaysDiff';'Extreme durability (GLOBAL)'='DisableAllDamage';'Autonomous winches'='AutonomousWinches';'Unlock all trucks'='UnlockTrucks';'All trucks in all regions'='AllRegions';'Unlock all upgrades/addons'='UnlockUpgrades'}
        foreach ($name in $checks.Keys) {
            $prop = $checks[$name]
            # Do not carry legacy differential settings into this format.
            if ($prop -eq 'AlwaysDiff' -and ([int]$s.SettingsVersion -lt 2)) { continue }
            if ($null -ne $s.$prop) { $script:Checks[$name].Checked = [bool]$s.$prop }
        }
    } catch {
        $lblStatus.Text = 'Could not load saved settings; defaults are active.'
    }
}

function Add-Count($Counts, [string]$Name, [int]$Amount) {
    if ($Amount -le 0) { return }
    if (-not $Counts.ContainsKey($Name)) { $Counts[$Name] = 0 }
    $Counts[$Name] += $Amount
}

function Replace-NumericAttribute([string]$Text, [string]$Attribute, [double]$Multiplier, $Counts, [string]$Label) {
    if ([math]::Abs($Multiplier - 1.0) -lt 0.0000001) { return $Text }
    $pattern = '(?i)(\b' + [regex]::Escape($Attribute) + '=")(-?\d+(?:\.\d+)?)(")'
    $hits = 0
    $result = [regex]::Replace($Text, $pattern, {
        param($m)
        $scriptValue = [double]::Parse($m.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
        $newValue = Format-Number ($scriptValue * $Multiplier)
        $script:hitsForReplacement++
        return $m.Groups[1].Value + $newValue + $m.Groups[3].Value
    })
    # Evaluators execute in a child scope, so count matches independently.
    $hits = [regex]::Matches($Text, $pattern).Count
    Add-Count $Counts $Label $hits
    return $result
}

function Compensate-SuspensionCamberForHeight([string]$Text, [double]$HeightMultiplier, $Counts) {
    # v1.1.2 RC4 EXPERIMENTAL:
    # Some trucks (notably the Tatra suspension architecture) intentionally couple
    # rendered wheel camber to suspension position through CamberSuspensionMultiplier.
    # When Suspension Height is multiplied, preserve the stock suspension-to-camber
    # contribution by inversely scaling ONLY existing CamberSuspensionMultiplier values.
    # Do not inject camber attributes and do not touch CamberAngleRender/Physics.
    if ([math]::Abs($HeightMultiplier - 1.0) -lt 0.0000001 -or $HeightMultiplier -le 0) { return $Text }
    $pattern = '(?i)(\bCamberSuspensionMultiplier=")(-?\d+(?:\.\d+)?)(")'
    $hits = [regex]::Matches($Text, $pattern).Count
    if ($hits -lt 1) { return $Text }
    $result = [regex]::Replace($Text, $pattern, {
        param($m)
        $v = [double]::Parse($m.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
        $newValue = Format-Number ($v / $HeightMultiplier)
        return $m.Groups[1].Value + $newValue + $m.Groups[3].Value
    })
    Add-Count $Counts 'Suspension-height camber compensation (EXPERIMENTAL)' $hits
    return $result
}

function Replace-SuspensionTravelAttribute([string]$Text, [string]$Attribute, [double]$Multiplier, $Counts, [string]$Label) {
    # v1.1.2 RC3: Strength/Damping are wheel-suspension physics controls.
    # Fleet audit found a second class of articulated/zero-travel suspension entries
    # where SuspensionMax is omitted (for example CAT CT680).  The common structural
    # signature is Height="0" + SuspensionMin="0".  Do not multiply Strength/Damping
    # on those entries; normal/traveling Suspension entries remain tunable.
    # Never inject attributes.
    if ([math]::Abs($Multiplier - 1.0) -lt 0.0000001) { return $Text }
    $suspensionPattern = '(?is)<Suspension\b[^>]*>'
    $attrPattern = '(?i)(\b' + [regex]::Escape($Attribute) + '=")(-?\d+(?:\.\d+)?)(")'
    $result = [regex]::Replace($Text, $suspensionPattern, {
        param($m)
        $tag = $m.Value
        $height = [regex]::Match($tag, '(?i)\bHeight="\s*(-?\d+(?:\.\d+)?)\s*"')
        $min = [regex]::Match($tag, '(?i)\bSuspensionMin="\s*(-?\d+(?:\.\d+)?)\s*"')
        if ($height.Success -and $min.Success) {
            $heightValue = [double]::Parse($height.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
            $minValue = [double]::Parse($min.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
            if ([math]::Abs($heightValue) -lt 0.0000001 -and [math]::Abs($minValue) -lt 0.0000001) {
                return $tag
            }
        }
        return [regex]::Replace($tag, $attrPattern, {
            param($a)
            $scriptValue = [double]::Parse($a.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
            $newValue = Format-Number ($scriptValue * $Multiplier)
            return $a.Groups[1].Value + $newValue + $a.Groups[3].Value
        })
    })
    # Count only eligible Suspension tags containing the requested attribute.
    $changed = 0
    foreach ($m in [regex]::Matches($Text, $suspensionPattern)) {
        $tag = $m.Value
        $height = [regex]::Match($tag, '(?i)\bHeight="\s*(-?\d+(?:\.\d+)?)\s*"')
        $min = [regex]::Match($tag, '(?i)\bSuspensionMin="\s*(-?\d+(?:\.\d+)?)\s*"')
        $skip = $false
        if ($height.Success -and $min.Success) {
            $heightValue = [double]::Parse($height.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
            $minValue = [double]::Parse($min.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
            $skip = ([math]::Abs($heightValue) -lt 0.0000001 -and [math]::Abs($minValue) -lt 0.0000001)
        }
        if (-not $skip -and [regex]::IsMatch($tag, $attrPattern)) { $changed++ }
    }
    Add-Count $Counts $Label $changed
    return $result
}

function Get-GearTuningFactor([string]$Profile) {
    switch ($Profile) {
        'Mild' { return 1.20 }
        'Performance' { return 1.35 }
        'High Performance' { return 1.50 }
        'Extreme' { return 1.75 }
        default { return 1.00 }
    }
}

function Tune-GearboxProgression([string]$Text, [double]$TopFactor, $Counts, [string]$Label) {
    # RC3.5: Gear Tuning is a bounded transmission profile, not a raw multiplier.
    # Each gearbox variant keeps its original first gear, gains ONE forward gear,
    # and its intermediate forward gears are re-sampled from the stock progression.
    # This preserves launch ability while tightening the ratios and mildly extending top end.
    if ([math]::Abs($TopFactor - 1.0) -lt 0.0000001) { return $Text }
    $gearboxPattern='(?is)<Gearbox\b[^>]*\bName="[^"]+"[^>]*>.*?</Gearbox>'
    $gearPattern='(?is)<Gear\b[^>]*/?>'
    $angPattern='(?i)(\bAngVel=")(-?\d*\.?\d+)(")'
    $fuelPattern='(?i)(\bFuelModifier=")(-?\d*\.?\d+)(")'
    $variants=[regex]::Matches($Text,$gearboxPattern)
    if($variants.Count -lt 1){throw 'RC3.5 Gear Tuning safety stop: no gearbox variants were found.'}
    $changedVariants=0; $newGearCount=0; $retuned=0
    $result=[regex]::Replace($Text,$gearboxPattern,{
        param($gb)
        $block=$gb.Value
        $gm=[regex]::Matches($block,$gearPattern)
        $n=$gm.Count
        if($n -lt 2){return $block}
        $vals=New-Object Collections.Generic.List[double]
        $fuels=New-Object Collections.Generic.List[string]
        foreach($g in $gm){
            $am=[regex]::Match($g.Value,$angPattern); if(-not $am.Success){return $block}
            $vals.Add([double]::Parse($am.Groups[2].Value,[Globalization.CultureInfo]::InvariantCulture))
            $fm=[regex]::Match($g.Value,$fuelPattern); $fuels.Add($(if($fm.Success){$fm.Groups[2].Value}else{'1.0'}))
        }
        $newVals=New-Object Collections.Generic.List[double]
        # N stock gears become N+1. Sample the original curve at N+1 positions;
        # the final point is the bounded extended top gear.
        for($i=0;$i -le $n;$i++){
            if($i -eq $n){$newVals.Add($vals[$n-1]*$TopFactor);continue}
            $pos=([double]$i*($n-1))/$n
            $lo=[int][math]::Floor($pos); $hi=[int][math]::Ceiling($pos)
            if($hi -ge $n){$hi=$n-1}
            $frac=$pos-$lo
            $v=$vals[$lo]+(($vals[$hi]-$vals[$lo])*$frac)
            $newVals.Add($v)
        }
        $sb=New-Object Text.StringBuilder
        $cursor=0
        for($i=0;$i -lt $n;$i++){
            $g=$gm[$i]
            [void]$sb.Append($block.Substring($cursor,$g.Index-$cursor))
            $gv=$g.Value
            $fmt=Format-Number $newVals[$i]
            $gv=[regex]::Replace($gv,$angPattern,{param($m)$m.Groups[1].Value+$fmt+$m.Groups[3].Value},1)
            [void]$sb.Append($gv); $cursor=$g.Index+$g.Length
        }
        # append one extra top gear after the last stock gear position
        $last=$gm[$n-1]; $newTop=Format-Number $newVals[$n]; $fuel=$fuels[$n-1]
        [void]$sb.Append(('`r`n`t`t<Gear AngVel="'+$newTop+'" FuelModifier="'+$fuel+'" />'))
        [void]$sb.Append($block.Substring($cursor))
        return $sb.ToString()
    })
    foreach($gb in $variants){$n=[regex]::Matches($gb.Value,$gearPattern).Count;if($n -ge 2){$changedVariants++;$newGearCount++;$retuned += ($n-1)}}
    if($changedVariants -lt 1 -or $result -ceq $Text){throw 'RC3.5 Gear Tuning safety stop: no gearbox progressions were changed.'}
    Add-Count $Counts $Label $changedVariants
    Add-Count $Counts 'Extra forward gears added' $newGearCount
    Add-Count $Counts 'Intermediate forward gears re-spaced' $retuned
    Add-Count $Counts 'Launch gears preserved stock' $changedVariants
    return $result
}

function Replace-InverseNumericAttribute([string]$Text, [string]$Attribute, [double]$Multiplier, $Counts, [string]$Label) {
    if ([math]::Abs($Multiplier - 1.0) -lt 0.0000001) { return $Text }
    if ($Multiplier -le 0) { throw "$Label must be greater than zero." }
    $pattern = '(?i)(\b' + [regex]::Escape($Attribute) + '=")(-?\d*\.?\d+)(")'
    $hits = [regex]::Matches($Text, $pattern).Count
    $result = [regex]::Replace($Text, $pattern, {
        param($m)
        $value = [double]::Parse($m.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
        return $m.Groups[1].Value + (Format-Number ($value / $Multiplier)) + $m.Groups[3].Value
    })
    Add-Count $Counts $Label $hits
    return $result
}

function Lower-CenterOfMass([string]$Text, [double]$Drop, $Counts, [string]$Label) {
    if ($Drop -le 0) { return $Text }
    # SnowRunner vectors are (forward/back; vertical; left/right).
    # Current files contain both semicolon and legacy comma vector separators.
    $pattern = '(?i)(\bCenterOfMassOffset="\(\s*[^;,"]+\s*[;,]\s*)(-?\d*\.?\d+)(\s*[;,][^"]+\)")'
    $hits = [regex]::Matches($Text, $pattern).Count
    $result = [regex]::Replace($Text, $pattern, {
        param($m)
        $vertical = [double]::Parse($m.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
        return $m.Groups[1].Value + (Format-Number ($vertical - $Drop)) + $m.Groups[3].Value
    })
    Add-Count $Counts $Label $hits
    return $result
}


function Lower-AddonTrailerPrimaryCenterOfMass([string]$Text, [double]$Drop, $Counts, [string]$Label) {
    if ([math]::Abs($Drop) -lt 0.0000001) { return $Text }
    # v1.1.2 hotfix: addon/trailer COG must never move nested articulated bodies.
    # Modify only the first (primary) <Body> directly inside <PhysicsModel>, and only
    # when that body already defines CenterOfMassOffset. Never inject a new COG.
    $pm = [regex]::Match($Text, '(?is)<PhysicsModel\b[^>]*>')
    if (-not $pm.Success) { return $Text }
    $searchStart = $pm.Index + $pm.Length
    $tail = $Text.Substring($searchStart)
    $bodyRel = [regex]::Match($tail, '(?is)<Body\b[^>]*>')
    if (-not $bodyRel.Success) { return $Text }
    $body = $bodyRel
    $bodyAbsoluteIndex = $searchStart + $bodyRel.Index
    $com = [regex]::Match($body.Value, '(?i)(\bCenterOfMassOffset="\(\s*[^;,"]+\s*[;,]\s*)(-?\d*\.?\d+)(\s*[;,][^"]+\)")')
    if (-not $com.Success) { return $Text }
    $old = [double]::Parse($com.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
    $new = Format-Number ($old - $Drop)
    $newTag = $body.Value.Substring(0,$com.Index) + $com.Groups[1].Value + $new + $com.Groups[3].Value + $body.Value.Substring($com.Index + $com.Length)
    Add-Count $Counts $Label 1
    return $Text.Substring(0,$bodyAbsoluteIndex) + $newTag + $Text.Substring($bodyAbsoluteIndex + $body.Length)
}

function Lower-TruckPrimaryCenterOfMass([string]$Text, [double]$Drop, $Counts, [string]$Label) {
    if ($Drop -le 0) { return $Text }

    # v1.1.2 RC1 SAFETY FIX:
    # "Truck COG" must affect only the primary/root Body of the truck's PhysicsModel.
    # v1.1.1 used a file-wide CenterOfMassOffset replacement, which also moved nested
    # cabin/articulation/constraint body COGs and can destabilize certain trucks.
    $physics = [regex]::Match($Text, '(?is)<PhysicsModel\b[^>]*>.*?</PhysicsModel>')
    if (-not $physics.Success) { return $Text }

    $body = [regex]::Match($physics.Value, '(?is)<Body\b[^>]*>')
    if (-not $body.Success) { return $Text }

    $com = [regex]::Match($body.Value, '(?i)(\bCenterOfMassOffset="\(\s*[^;,"]+\s*[;,]\s*)(-?\d*\.?\d+)(\s*[;,][^"]+\)")')
    if (-not $com.Success) { return $Text }

    $vertical = [double]::Parse($com.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
    $replacement = $com.Groups[1].Value + (Format-Number ($vertical - $Drop)) + $com.Groups[3].Value

    $absolute = $physics.Index + $body.Index + $com.Index
    $result = $Text.Remove($absolute, $com.Length).Insert($absolute, $replacement)
    Add-Count $Counts $Label 1
    return $result
}

function Repoint-TestStockWheelFamily([string]$Text,$S,$Counts) {
    if(-not $S.TargetTruckId -or -not $S.TestStockWheelSwap){return $Text}
    if(([string]$S.TargetTruckId).ToLowerInvariant() -ne 'freightliner_114sd'){
        throw 'TEST 6.18 safety stop: stock wheel-family substitution is intentionally limited to Freightliner 114SD.'
    }
    $newType=[string]$S.TestStockWheelSwapType
    $newTire=[string]$S.TestStockWheelSwapTire
    if(-not $newType -or -not $newTire){throw 'TEST 6.18 safety stop: stock wheel-family test plan was not resolved.'}
    $wheels=[regex]::Matches($Text,'(?is)<Wheels\b[^>]*>')
    if($wheels.Count -ne 1){throw "TEST 6.18 safety stop: expected exactly one <Wheels> tag; found $($wheels.Count)."}
    $oldTag=$wheels[0].Value
    $oldType=[regex]::Match($oldTag,'(?i)\bDefaultWheelType="([^"]+)"')
    $oldTire=[regex]::Match($oldTag,'(?i)\bDefaultTire="([^"]+)"')
    if(-not $oldType.Success -or -not $oldTire.Success){throw 'TEST 6.18 safety stop: current DefaultWheelType/DefaultTire could not be resolved.'}
    $newTag=[regex]::Replace($oldTag,'(?i)(\bDefaultWheelType=")[^"]+(" )?',{param($m) if($m.Groups[2].Success){$m.Groups[1].Value+$newType+$m.Groups[2].Value}else{$m.Groups[1].Value+$newType+'"'}})
    # Simpler exact attribute replacements after the guarded parse.
    $newTag=[regex]::Replace($oldTag,'(?i)(\bDefaultWheelType=")[^"]+(" )?',{param($m) $suffix=if($m.Groups[2].Success){$m.Groups[2].Value}else{'"'}; $m.Groups[1].Value+$newType+$suffix})
    $newTag=[regex]::Replace($newTag,'(?i)(\bDefaultTire=")[^"]+(" )?',{param($m) $suffix=if($m.Groups[2].Success){$m.Groups[2].Value}else{'"'}; $m.Groups[1].Value+$newTire+$suffix})
    if($newTag -ceq $oldTag){throw 'TEST 6.18 safety stop: wheel substitution produced no XML change.'}
    $Text=$Text.Remove($wheels[0].Index,$wheels[0].Length).Insert($wheels[0].Index,$newTag)
    Add-Count $Counts 'TEST stock DefaultWheelType substitutions' 1
    Add-Count $Counts 'TEST stock DefaultTire substitutions' 1
    return $Text
}

function Disable-GlobalComponentDamage([string]$Name, [string]$Text, $Counts) {
    # RC3.9.7: preserve the proven RC3.9.3 extreme-durability behavior exactly.
    # FuelTank fix only: max the existing DamageCapacity on the real <FuelTank>
    # element. FuelTank DamageArea definitions are deliberately left untouched.
    $lower = $Name.ToLowerInvariant().Replace('/', '\')

    # RC3.9.7 FuelTank fix. Fuel-tank durability belongs on the actual
    # <FuelTank DamageCapacity="..." /> element in base truck XML. Do NOT add
    # DamageCapacity to <DamageArea Type="FuelTank">; that invalidates truck definitions.
    if ($lower -match '\\classes\\trucks\\[^\\]+\.xml$') {
        $script:wlFuelTankHits = 0
        $Text = [regex]::Replace($Text, '(?is)<FuelTank\b[^>]*\bDamageCapacity="-?\d+(?:\.\d+)?"[^>]*>', {
            param($m)
            $tag = $m.Value
            if ($tag -notmatch '(?i)\bDamageCapacity="64000(?:\.0+)?"') { $script:wlFuelTankHits++ }
            return [regex]::Replace($tag, '(?i)(\bDamageCapacity=")-?\d+(?:\.\d+)?(")', '${1}64000${2}')
        })
        Add-Count $Counts 'GLOBAL extreme durability - fuel tank capacities maxed' ([int]$script:wlFuelTankHits)
        $script:wlFuelTankHits = 0
        return $Text
    }

    if ($lower -match '\\classes\\engines\\[^\\]+\.xml$') {
        $hits = [regex]::Matches($Text, '(?i)\bDamageCapacity="(?!64000(?:\.0+)?")-?\d+(?:\.\d+)?"').Count
        $Text = [regex]::Replace($Text, '(?i)(\bDamageCapacity=")-?\d+(?:\.\d+)?(")', '${1}64000${2}')
        Add-Count $Counts 'GLOBAL extreme durability - engine capacities maxed' $hits
        return $Text
    }

    if ($lower -match '\\classes\\gearboxes\\[^\\]+\.xml$') {
        $hits = [regex]::Matches($Text, '(?i)\bDamageCapacity="(?!64000(?:\.0+)?")-?\d+(?:\.\d+)?"').Count
        $Text = [regex]::Replace($Text, '(?i)(\bDamageCapacity=")-?\d+(?:\.\d+)?(")', '${1}64000${2}')
        Add-Count $Counts 'GLOBAL extreme durability - gearbox capacities maxed' $hits
        return $Text
    }

    if ($lower -match '\\classes\\wheels\\[^\\]+\.xml$') {
        # DamageCapacity is documented on the root <TruckWheel> / <TruckWheels>
        # tags, not on individual <TruckTire> entries. Touch only those roots.
        $hits = 0
        $Text = [regex]::Replace($Text, '(?is)<TruckWheels?\b[^>]*>', {
            param($m)
            $tag=$m.Value
            if($tag -match '(?i)\bDamageCapacity="-?\d+(?:\.\d+)?"'){
                if($tag -notmatch '(?i)\bDamageCapacity="64000(?:\.0+)?"'){ $script:wlWheelHits++ }
                return [regex]::Replace($tag, '(?i)(\bDamageCapacity=")-?\d+(?:\.\d+)?(")', '${1}64000${2}')
            }
            return $tag
        })
        $hits=[int]$script:wlWheelHits; $script:wlWheelHits=0
        Add-Count $Counts 'GLOBAL extreme durability - wheel capacities maxed' $hits
        return $Text
    }

    if ($lower -match '\\classes\\suspensions\\[^\\]+\.xml$') {
        # Both attributes belong on <SuspensionSet>, not child <Suspension>.
        $capHits=0; $multHits=0; $multAdded=0
        $Text = [regex]::Replace($Text, '(?is)<SuspensionSet\b[^>]*>', {
            param($m)
            $tag=$m.Value
            if($tag -match '(?i)\bDamageCapacity="-?\d+(?:\.\d+)?"'){
                if($tag -notmatch '(?i)\bDamageCapacity="64000(?:\.0+)?"'){ $script:wlSuspCapHits++ }
                $tag=[regex]::Replace($tag, '(?i)(\bDamageCapacity=")-?\d+(?:\.\d+)?(")', '${1}64000${2}')
            } else {
                $script:wlSuspCapHits++
                $tag=$tag.Substring(0,$tag.Length-1)+' DamageCapacity="64000">'
            }
            if($tag -match '(?i)\bBrokenWheelDamageMultiplier="-?\d+(?:\.\d+)?"'){
                if($tag -notmatch '(?i)\bBrokenWheelDamageMultiplier="0(?:\.0+)?"'){ $script:wlSuspMultHits++ }
                $tag=[regex]::Replace($tag, '(?i)(\bBrokenWheelDamageMultiplier=")-?\d+(?:\.\d+)?(")', '${1}0${2}')
            } else {
                $script:wlSuspMultAdded++
                $tag=$tag.Substring(0,$tag.Length-1)+' BrokenWheelDamageMultiplier="0">'
            }
            return $tag
        })
        $capHits=[int]$script:wlSuspCapHits; $script:wlSuspCapHits=0
        $multHits=[int]$script:wlSuspMultHits; $script:wlSuspMultHits=0
        $multAdded=[int]$script:wlSuspMultAdded; $script:wlSuspMultAdded=0
        Add-Count $Counts 'GLOBAL extreme durability - suspension capacities maxed' $capHits
        Add-Count $Counts 'GLOBAL extreme durability - broken-wheel multipliers disabled' $multHits
        Add-Count $Counts 'GLOBAL extreme durability - broken-wheel multipliers added' $multAdded
        return $Text
    }

    return $Text
}

function Modify-Entry([string]$Name, [string]$Text, $S, $Counts) {
    $lower = $Name.ToLowerInvariant().Replace('/', '\')

    # v1.1.0 TEST individual-truck scope. A selected truck is intentionally
    # limited to its base truck definition so shared engines/gearboxes/tires/etc.
    # cannot accidentally change other trucks that use the same component XML.
    if ($S.TargetTruckId) {
        if (-not $S.TargetTruckEntry) { return $Text }
        $targetBase = ([string]$S.TargetTruckEntry).ToLowerInvariant().Replace('/', '\')
        # TEST 6.2 resolves the real archive entry before modification, then uses
        # exact equality here. No fuzzy matching is allowed during the write pass.
        if (-not $lower.Equals($targetBase, [StringComparison]::OrdinalIgnoreCase)) { return $Text }
    }

    if ($S.TargetTruckId) {
        # TEST 6.23.1: engine settings keep the stock EngineSocket identifiers unchanged.
        # The selected stock/default engine variant is edited in place.
        # TEST 6.23.1: gearbox identifiers remain stock; no private variant repoint.
        $Text = Repoint-IndividualTire $Text $S $Counts
        $Text = Repoint-TestStockWheelFamily $Text $S $Counts
    }

    if ($lower -match '\\classes\\engines\\[^\\]+\.xml$') {
        $Text = Replace-NumericAttribute $Text 'Torque' $S.EngineTorque $Counts 'Engine torque'
        $Text = Replace-NumericAttribute $Text 'EngineResponsiveness' $S.EngineResponse $Counts 'Engine responsiveness'
        $Text = Replace-NumericAttribute $Text 'FuelConsumption' $S.EngineFuel $Counts 'Engine fuel consumption'
        $Text = Replace-NumericAttribute $Text 'DamageCapacity' $S.EngineDurability $Counts 'Engine durability'
    }
    elseif ($lower -match '\\classes\\gearboxes\\[^\\]+\.xml$') {
        $Text = Replace-NumericAttribute $Text 'FuelConsumption' $S.GearboxFuel $Counts 'Gearbox fuel consumption'
        $Text = Replace-NumericAttribute $Text 'AWDConsumptionModifier' $S.AwdFuel $Counts 'AWD fuel penalty'
        $Text = Replace-NumericAttribute $Text 'IdleFuelModifier' $S.IdleFuel $Counts 'Idle fuel use'
        # RC3.9.7: All Trucks traverses every gearbox-class XML, including helper/template files
        # that contain no named <Gearbox> variants. Only tune files that actually contain variants.
        # Individual-truck mode keeps its stricter resolved-family safety stop in the dedicated path.
        if ([math]::Abs([double]$S.GearSpeed - 1.0) -ge 0.0000001 -and [regex]::IsMatch($Text, '(?is)<Gearbox\b[^>]*\bName="[^"]+"[^>]*>')) {
            $Text = Tune-GearboxProgression $Text $S.GearSpeed $Counts 'Gearbox variants tuned'
        }
        $Text = Replace-NumericAttribute $Text 'DamageCapacity' $S.GearboxDurability $Counts 'Gearbox durability'
    }
    elseif ($lower -match '\\classes\\wheels\\[^\\]+\.xml$') {
        $Text = Replace-NumericAttribute $Text 'BodyFrictionAsphalt' $S.TireAsphalt $Counts 'Tire asphalt grip'
        $Text = Replace-NumericAttribute $Text 'BodyFriction' $S.TireOffroad $Counts 'Tire off-road grip'
        $Text = Replace-NumericAttribute $Text 'SubstanceFriction' $S.TireMud $Counts 'Tire mud grip'
        $Text = Replace-NumericAttribute $Text 'DamageCapacity' $S.TireDurability $Counts 'Tire durability'
    }
    elseif ($lower -match '\\classes\\suspensions\\[^\\]+\.xml$') {
        $Text = Replace-SuspensionTravelAttribute $Text 'Strength' $S.SuspensionStrength $Counts 'Suspension strength'
        $Text = Replace-NumericAttribute $Text 'Height' $S.SuspensionHeight $Counts 'Suspension height'
        $Text = Replace-SuspensionTravelAttribute $Text 'Damping' $S.SuspensionDamping $Counts 'Suspension damping'
        $Text = Replace-NumericAttribute $Text 'DamageCapacity' $S.SuspensionDurability $Counts 'Suspension durability'
    }
    elseif ($lower -match '\\classes\\winches\\[^\\]+\.xml$' -and $lower -notmatch 'winch_ui_draw') {
        $Text = Replace-NumericAttribute $Text 'StrengthMult' $S.WinchStrength $Counts 'Winch strength'
        $Text = Replace-NumericAttribute $Text 'Length' $S.WinchLength $Counts 'Winch length'
        if ($S.AutonomousWinches) {
            $pattern = '(?i)IsEngineIgnitionRequired="(?:true|false)"'
            $n = [regex]::Matches($Text, $pattern).Count
            $Text = [regex]::Replace($Text, $pattern, 'IsEngineIgnitionRequired="false"')
            Add-Count $Counts 'Autonomous winches' $n
        }
    }
    elseif ($lower -match '\\classes\\trucks\\addons\\[^\\]+\.xml$' -and (
        $lower -match '(?:crane|loglift)' -or
        $Text -match '(?is)<AddonType\s+Name="Crane"\s*/?>' -or
        $Text -match '(?is)<ControlledConstraints>.*?BelongToCategorie="(?:crane_control|tow_control)"'
    )) {
        # v1.1.3: discover mechanical equipment by XML semantics, not filename alone.
        # Existing crane/loglift behavior stays intact. This also reaches crane-equipped service modules,
        # telehandlers/manipulators, and towing platforms whose filenames do not contain "crane".
        if ($S.TargetTruckId) { return $Text }
        $Text = Replace-CraneHingeMotorForce $Text ([double]$S.CraneStrength) $Counts
        $Text = Replace-CraneControlledIKSpeed $Text ([double]$S.CraneSpeed) $Counts
        $Text = Replace-ControlledConstraintMotorForce $Text ([double]$S.CraneStrength) $Counts
        $Text = Replace-ControlledConstraintSpeed $Text ([double]$S.CraneSpeed) $Counts
    }

    $isBaseTruck = ($lower -match '\\classes\\trucks\\[^\\]+\.xml$' -and $Text -match '<Truck>')
    $isTruckXml = ($lower -match '\\classes\\trucks\\.*\.xml$')
    $isUpgrade = ($lower -match '\\classes\\(?:engines|gearboxes|suspensions|wheels|winches)\\[^\\]+\.xml$' -or $lower -match '\\classes\\trucks\\(?!cargo\\|trailers\\)[^\\]+\\[^\\]+\.xml$')

    if ($isTruckXml -and -not $isBaseTruck) {
        $Text = Replace-NumericAttribute $Text 'FuelCapacity' $S.ServiceFuel $Counts 'Service fuel capacity'
        $Text = Replace-NumericAttribute $Text 'RepairsCapacity' $S.ServiceRepairs $Counts 'Service repair points'
        $Text = Replace-NumericAttribute $Text 'WheelRepairsCapacity' $S.ServiceWheels $Counts 'Service spare wheels'
        if ($lower -notmatch '\\classes\\trucks\\cargo\\') {
            $Text = Lower-AddonTrailerPrimaryCenterOfMass $Text $S.AddonCgDrop $Counts 'Addon/trailer center of gravity (primary body only)'
        }
    }

    if (-not $S.TargetTruckId -and (($lower -match '\\classes\\models\\[^\\]+\.xml$' -and $Text -match '\bLoadType="') -or $lower -match '\\classes\\trucks\\cargo\\[^\\]+\.xml$')) {
        # Cargo definitions are shared/global resources; Cargo Mass is All-Trucks-only.
        $Text = Replace-NumericAttribute $Text 'Mass' $S.CargoMass $Counts 'Cargo physical mass'
    }

    if ($isUpgrade) {
        $Text = Replace-NumericAttribute $Text 'Price' $S.UpgradePrice $Counts 'Upgrade/addon prices'
        if ($S.UnlockUpgrades) {
            $p1 = '(?i)(\bUnlockByRank=")\d+(?:\.\d+)?(")'
            $p2 = '(?i)(\bUnlockByExploration=")(?:true|false)(")'
            $n = [regex]::Matches($Text, $p1).Count + [regex]::Matches($Text, $p2).Count
            $Text = [regex]::Replace($Text, $p1, '${1}1${2}')
            $Text = [regex]::Replace($Text, $p2, '${1}false${2}')
            Add-Count $Counts 'Upgrade/addon unlock requirements' $n
        }
    }

    # Only base truck definitions: exclude tuning, addons and trailers.
    if ($isBaseTruck) {
        # TEST 6.20.4: EngineSocket is already repointed once in the individual-target
        # block above. Calling Repoint-IndividualEngine a second time here searched
        # for the old Default after it had already been replaced, producing the
        # false TEST 6.9 "0 matching EngineSocket" safety stop.
        $Text = Replace-NumericAttribute $Text 'FuelCapacity' $S.FuelCapacity $Counts 'Truck fuel capacity'
        if ([math]::Abs([double]$S.FuelTankDurability - 1.0) -ge 0.0000001) {
            $ftPattern = '(?is)<FuelTank\b[^>]*\bDamageCapacity="(-?\d+(?:\.\d+)?)"[^>]*>'
            $ftHits = [regex]::Matches($Text, $ftPattern).Count
            $Text = [regex]::Replace($Text, $ftPattern, {
                param($m)
                $tag = $m.Value
                return [regex]::Replace($tag, '(?i)(\bDamageCapacity=")(-?\d+(?:\.\d+)?)(")', {
                    param($a)
                    $v = [double]::Parse($a.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
                    return $a.Groups[1].Value + (Format-Number ($v * [double]$S.FuelTankDurability)) + $a.Groups[3].Value
                })
            })
            Add-Count $Counts 'Fuel tank durability' $ftHits
        }
        if ([math]::Abs([double]$S.TruckPrice - 1.0) -ge 0.0000001) {
            $Text = Replace-NumericAttribute $Text 'Price' $S.TruckPrice $Counts 'Truck prices'
        }
        $Text = Lower-TruckPrimaryCenterOfMass $Text $S.TruckCgDrop $Counts 'Truck center of gravity'
        $Text = Replace-NumericAttribute $Text 'SteeringAngle' $S.SteeringAngle $Counts 'Maximum steering angle'
        $Text = Replace-NumericAttribute $Text 'SteerSpeed' $S.SteeringResponse $Counts 'Steering response'
        $Text = Replace-NumericAttribute $Text 'BackSteerSpeed' $S.SteeringResponse $Counts 'Return steering response'
        # RC4 experimental visual-geometry compensation. This only changes truck XMLs
        # that already define CamberSuspensionMultiplier, and only when Height is changed.
        $Text = Compensate-SuspensionCamberForHeight $Text ([double]$S.SuspensionHeight) $Counts
        if ($S.AlwaysAWD) {
            # Keep the normal driven axle as "default". Only convert an axle
            # that is connectable or disabled into an always-driven axle.
            # Some trucks call the axle Front/MiddleAxle instead of FrontWheel.
            # Symbolic connectable/none torque values only occur on drive nodes.
            $pattern = '(?is)(<[A-Za-z0-9_]+\b[^>]*?\bTorque=")(?:connectable|none)(")'
            $n = [regex]::Matches($Text, $pattern).Count
            $Text = [regex]::Replace($Text, $pattern, '${1}full${2}')
            Add-Count $Counts 'Always AWD wheel definitions' $n
        }
        if ($S.AlwaysDiff) {
            $pattern = '(?i)(\bDiffLockType=")(?:None|Uninstalled|Installed|Always|Connected|Switchable)(")'
            $n = [regex]::Matches($Text, $pattern).Count
            $Text = [regex]::Replace($Text, $pattern, '${1}Always${2}')
            Add-Count $Counts 'Always differential lock' $n
        }
        if ($S.UnlockTrucks) {
            $p1 = '(?i)(\bUnlockByRank=")\d+(?:\.\d+)?(")'
            $p2 = '(?i)(\bUnlockByExploration=")(?:true|false)(")'
            $n = [regex]::Matches($Text, $p1).Count + [regex]::Matches($Text, $p2).Count
            $Text = [regex]::Replace($Text, $p1, '${1}1${2}')
            $Text = [regex]::Replace($Text, $p2, '${1}false${2}')
            Add-Count $Counts 'Truck unlock requirements' $n
        }
        if ($S.AllRegions) {
            $pattern = '(?i)(\bCountry=")[^"]*(")'
            $n = [regex]::Matches($Text, $pattern).Count
            $Text = [regex]::Replace($Text, $pattern, '${1}US,RU,NE,CAS,CE,WA${2}')
            Add-Count $Counts 'Truck region availability' $n
        }
    }
    return $Text
}

function Get-BackupPath([string]$PakPath) {
    return Join-Path ([IO.Path]::GetDirectoryName($PakPath)) 'initial.original.pak'
}

function Get-BackupMetaPath([string]$PakPath) {
    return Join-Path ([IO.Path]::GetDirectoryName($PakPath)) 'initial.original.pak.wlmeta.json'
}

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-SnowRunnerClosed {
    $running = Get-Process -Name 'SnowRunner' -ErrorAction SilentlyContinue
    if ($running) {
        throw 'SnowRunner is currently running. Close SnowRunner completely before applying or restoring mods.'
    }
}


function Test-PakCompatibility([string]$Path) {
    # This is intentionally independent of the user's selected multipliers.
    # It verifies the SnowRunner structures this editor knows how to modify
    # before a backup is promoted or the live PAK is ever replaced.
    $stats = [ordered]@{ Xml=0; Engines=0; Gearboxes=0; Wheels=0; Suspensions=0; Winches=0; BaseTrucks=0 }
    $stream = [IO.File]::OpenRead($Path)
    try {
        $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Read)
        try {
            foreach ($entry in $zip.Entries) {
                $name = $entry.FullName.ToLowerInvariant()
                if (-not $name.EndsWith('.xml')) { continue }
                $stats.Xml++
                if ($name -match '\\classes\\engines\\[^\\]+\.xml$') { $stats.Engines++ }
                elseif ($name -match '\\classes\\gearboxes\\[^\\]+\.xml$') { $stats.Gearboxes++ }
                elseif ($name -match '\\classes\\wheels\\[^\\]+\.xml$') { $stats.Wheels++ }
                elseif ($name -match '\\classes\\suspensions\\[^\\]+\.xml$') { $stats.Suspensions++ }
                elseif ($name -match '\\classes\\winches\\[^\\]+\.xml$') { $stats.Winches++ }
                elseif ($name -match '\\classes\\trucks\\[^\\]+\.xml$') {
                    $reader = New-Object IO.StreamReader($entry.Open(), [Text.Encoding]::UTF8, $true)
                    try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
                    if ($text -match '<Truck>') { $stats.BaseTrucks++ }
                }
            }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }

    # Broad lower bounds, not exact version numbers. Routine DLC/content updates
    # should sail through; a major archive/layout change should fail closed.
    $problems = New-Object Collections.Generic.List[string]
    if ($stats.Xml -lt 1000) { $problems.Add("only $($stats.Xml) XML files were found") }
    if ($stats.Engines -lt 10) { $problems.Add("engine definitions are missing/relocated ($($stats.Engines) found)") }
    if ($stats.Gearboxes -lt 5) { $problems.Add("gearbox definitions are missing/relocated ($($stats.Gearboxes) found)") }
    if ($stats.Wheels -lt 20) { $problems.Add("wheel definitions are missing/relocated ($($stats.Wheels) found)") }
    if ($stats.Suspensions -lt 20) { $problems.Add("suspension definitions are missing/relocated ($($stats.Suspensions) found)") }
    if ($stats.Winches -lt 5) { $problems.Add("winch definitions are missing/relocated ($($stats.Winches) found)") }
    if ($stats.BaseTrucks -lt 50) { $problems.Add("base truck definitions are missing/relocated ($($stats.BaseTrucks) found)") }
    if ($problems.Count -gt 0) {
        throw ("Compatibility preflight FAILED. This SnowRunner update may have changed initial.pak in a way this editor does not understand. NO MODIFICATIONS WERE MADE. Use Epic Games Verify if needed and wait for an editor update. Details: " + ($problems -join '; '))
    }
    return [pscustomobject]$stats
}

function Initialize-Backup([string]$Pak) {
    $script:UpdateDetected = $false
$script:TruckTargets = @{}
$script:wlDamageCapHits = 0
$script:wlDamageMultHits = 0
    $backup = Get-BackupPath $Pak
    $metaPath = Get-BackupMetaPath $Pak
    $currentHash = Get-FileSha256 $Pak

    # v1.0.0 backups have no metadata and may belong to an older SnowRunner update.
    # Never trust them automatically. Archive the legacy backup and establish the
    # current verified initial.pak as the new baseline.
    if ((Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $metaPath)) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $legacy = Join-Path ([IO.Path]::GetDirectoryName($Pak)) ("initial.original.legacy-$stamp.pak")
        Move-Item -LiteralPath $backup -Destination $legacy -Force
    }

    if (-not (Test-Path -LiteralPath $backup)) {
        [IO.File]::Copy($Pak, $backup, $false)
        $meta = [ordered]@{ BackupHash = $currentHash; LastEditorOutputHash = $null; CreatedUtc = [DateTime]::UtcNow.ToString('o') }
        $meta | ConvertTo-Json | Set-Content -LiteralPath $metaPath -Encoding UTF8
        return $backup
    }

    Assert-Pak $backup
    $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
    $backupHash = Get-FileSha256 $backup
    if ($meta.BackupHash -ne $backupHash) {
        throw 'The editor backup no longer matches its safety record. Use Epic Games Verify, then delete initial.original.pak and its .wlmeta.json file before trying again.'
    }

    # If current PAK is neither our known clean backup nor our last editor output,
    # SnowRunner/Epic changed it. Promote that new official PAK to the baseline.
    if ($currentHash -ne $meta.BackupHash -and $currentHash -ne $meta.LastEditorOutputHash) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $archived = Join-Path ([IO.Path]::GetDirectoryName($Pak)) ("initial.original.preupdate-$stamp.pak")
        Move-Item -LiteralPath $backup -Destination $archived -Force
        [IO.File]::Copy($Pak, $backup, $false)
        $meta = [ordered]@{ BackupHash = $currentHash; LastEditorOutputHash = $null; CreatedUtc = [DateTime]::UtcNow.ToString('o') }
        $meta | ConvertTo-Json | Set-Content -LiteralPath $metaPath -Encoding UTF8
        $script:UpdateDetected = $true
    }
    return $backup
}

function Set-LastEditorOutputHash([string]$Pak) {
    $metaPath = Get-BackupMetaPath $Pak
    if (Test-Path -LiteralPath $metaPath) {
        $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
        $meta.LastEditorOutputHash = Get-FileSha256 $Pak
        $meta | ConvertTo-Json | Set-Content -LiteralPath $metaPath -Encoding UTF8
    }
}

function Assert-Pak([string]$Path, [bool]$RequireInitialName = $false) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'Choose a valid initial.pak file first.'
    }
    if ($RequireInitialName -and [IO.Path]::GetFileName($Path).ToLowerInvariant() -ne 'initial.pak') {
        throw 'The selected file must be named initial.pak.'
    }
    $stream = [IO.File]::OpenRead($Path)
    try {
        $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Read)
        try {
            if (-not ($zip.Entries | Where-Object { $_.FullName -eq 'pak.load_list' } | Select-Object -First 1)) {
                throw 'This does not appear to be a valid SnowRunner initial.pak.'
            }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }
}

function Get-TruckTargets([string]$PakPath) {
    Assert-Pak $PakPath $true
    $items = New-Object Collections.Generic.List[object]
    $stream = [IO.File]::OpenRead($PakPath)
    try {
        $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Read)
        try {
            $utf8 = New-Object Text.UTF8Encoding($false)
            foreach ($entry in $zip.Entries) {
                $name = $entry.FullName.ToLowerInvariant()
                if ($name -notmatch '\\classes\\trucks\\([^\\]+)\.xml$') { continue }
                $es = $entry.Open()
                try {
                    $reader = New-Object IO.StreamReader($es, $utf8, $true)
                    try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
                } finally { $es.Dispose() }
                if ($text -notmatch '<Truck\b') { continue }
                $id = [IO.Path]::GetFileNameWithoutExtension($entry.FullName)
                $friendly = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase((($id -replace '[_-]+',' ').ToLowerInvariant()))
                $items.Add([pscustomobject]@{ Id=$id; Display=("$friendly  [$id]") })
            }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }
    return $items | Sort-Object Display
}

function Refresh-TruckTargets {
    $previous = if ($cmbTruck.SelectedItem) { [string]$cmbTruck.SelectedItem } else { 'All Trucks' }
    $cmbTruck.Items.Clear()
    $script:TruckTargets = @{}
$script:wlDamageCapHits = 0
$script:wlDamageMultHits = 0
    [void]$cmbTruck.Items.Add('All Trucks')
    $pakPath = $txtPak.Text.Trim()
    if ($pakPath -and (Test-Path -LiteralPath $pakPath)) {
        foreach ($truck in (Get-TruckTargets $pakPath)) {
            $script:TruckTargets[$truck.Display] = $truck.Id
            [void]$cmbTruck.Items.Add($truck.Display)
        }
    }
    $idx = $cmbTruck.Items.IndexOf($previous)
    $cmbTruck.SelectedIndex = if ($idx -ge 0) { $idx } else { 0 }
    $lblTruckCount.Text = if ($cmbTruck.Items.Count -gt 1) { [string](($cmbTruck.Items.Count)-1) } else { '' }
}


function Find-InstalledModTruckSources {
    # TEST 6: clean, READ-ONLY subscribed mod.io truck discovery retained from TEST 5.
    # Only scan the actual SnowRunner mod.io subscription tree and only accept
    # XML files whose contents contain a real <Truck ...> root/element.
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $modRoot = Join-Path $docs 'My Games\SnowRunner\base\Mods\.modio\mods'
    $results = New-Object Collections.Generic.List[object]
    $archives = New-Object Collections.Generic.List[object]
    $seen = @{}

    if (-not (Test-Path -LiteralPath $modRoot -PathType Container)) {
        return [pscustomobject]@{ Root=$modRoot; Trucks=[object[]]@(); Archives=[object[]]@() }
    }

    $utf8 = New-Object Text.UTF8Encoding($false)
    foreach ($f in (Get-ChildItem -LiteralPath $modRoot -Recurse -File -Filter '*.pak' -ErrorAction SilentlyContinue)) {
        # Ignore the shared/aggregate cache if one exists. Individual numbered
        # subscription folders are the authoritative source for this test.
        if ($f.Name -ieq 'mod.pak') { continue }
        try {
            $fs = [IO.File]::OpenRead($f.FullName)
            try {
                $z = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Read)
                try {
                    $truckCount=0
                    foreach ($e in $z.Entries) {
                        $entryName = ($e.FullName -replace '\\','/').ToLowerInvariant()
                        if ($entryName -notmatch '(^|/)classes/trucks/([^/]+)\.xml$') { continue }

                        # Filename/path alone is not enough: addon XMLs are often
                        # stored below classes/trucks too. Verify this is a Truck.
                        $es=$e.Open()
                        try {
                            $reader=New-Object IO.StreamReader($es,$utf8,$true)
                            try { $text=$reader.ReadToEnd() } finally { $reader.Dispose() }
                        } finally { $es.Dispose() }
                        if ($text -notmatch '<Truck\b') { continue }

                        $id=[IO.Path]::GetFileNameWithoutExtension($e.FullName)
                        $key=($id + '|' + $f.FullName).ToLowerInvariant()
                        if ($seen[$key]) { continue }; $seen[$key]=$true
                        $friendly=[Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase((($id -replace '[_-]+',' ').ToLowerInvariant()))
                        $display="[MOD] $friendly  [$id]"
                        $results.Add([pscustomobject]@{ Id=$id; Display=$display; Source=$f.FullName; Entry=$e.FullName; Kind='mod.io PAK' })
                        $truckCount++
                    }
                    if ($truckCount -gt 0) { $archives.Add([pscustomobject]@{Path=$f.FullName; Trucks=$truckCount}) }
                } finally { $z.Dispose() }
            } finally { $fs.Dispose() }
        } catch { }
    }
    [object[]]$truckArray=@($results.ToArray() | Sort-Object Display)
    [object[]]$archiveArray=$archives.ToArray()
    return [pscustomobject]@{ Root=$modRoot; Trucks=$truckArray; Archives=$archiveArray }
}

function Refresh-ModTruckTargets {
    $scan=Find-InstalledModTruckSources
    # Remove only entries previously inserted by Scan Mods.
    for ($i=$cmbTruck.Items.Count-1; $i -ge 0; $i--) {
        if ([string]$cmbTruck.Items[$i] -like '[[]MOD[]]*') { $cmbTruck.Items.RemoveAt($i) }
    }
    if (-not $script:ModTruckTargets) { $script:ModTruckTargets=@{} } else { $script:ModTruckTargets.Clear() }
    foreach ($truck in $scan.Trucks) {
        $script:ModTruckTargets[$truck.Display]=$truck
        [void]$cmbTruck.Items.Add($truck.Display)
    }
    return $scan
}

function Show-ModScanDiagnostic {
    $scan=Refresh-ModTruckTargets
    $lines=New-Object Collections.Generic.List[string]
    $lines.Add('WL Simplistic SnowRunner Mod Editor v1.1.3 - CLEAN READ-ONLY MOD TRUCK DISCOVERY')
    $lines.Add(('Generated: ' + (Get-Date)))
    $lines.Add('NO FILES WERE MODIFIED.')
    $lines.Add('')
    $lines.Add(('mod.io subscription root: ' + $scan.Root))
    $lines.Add(('PAK archives containing verified Truck XML: ' + $scan.Archives.Count))
    foreach ($a in $scan.Archives) { $lines.Add(('  ' + $a.Trucks + ' truck(s): ' + $a.Path)) }
    $lines.Add('')
    $lines.Add(('Verified installed mod trucks found: ' + $scan.Trucks.Count))
    foreach ($t in $scan.Trucks) {
        $lines.Add(('  ' + $t.Display))
        $lines.Add(('      PAK: ' + $t.Source))
        $lines.Add(('      XML: ' + $t.Entry))
    }
    $report=Join-Path ([Environment]::GetFolderPath('Desktop')) 'WL-SnowRunner-TEST5-ModTrucks.txt'
    $lines | Set-Content -LiteralPath $report -Encoding UTF8
    [Windows.Forms.MessageBox]::Show(("Clean read-only mod scan complete.`r`n`r`nFound " + $scan.Trucks.Count + " verified mod truck(s).`r`n`r`nThey were added to the Truck target dropdown as [MOD].`r`n`r`nReport saved to:`r`n" + $report),$script:AppName,'OK','Information') | Out-Null
    return $scan.Trucks.Count
}

function Resolve-OfficialTruckEntryPath([string]$PakPath, [string]$TruckId) {
    if ([string]::IsNullOrWhiteSpace($TruckId)) { return '' }

    $report = Join-Path ([Environment]::GetFolderPath('Desktop')) 'WL-SnowRunner-TEST6.3-TruckResolver.txt'
    $lines = New-Object Collections.Generic.List[string]
    $lines.Add('WL Simplistic SnowRunner Mod Editor v1.1.0 TEST 6.10 - TRUCK RESOLVER')
    $lines.Add(('Generated: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
    $lines.Add('NO FILES WERE MODIFIED BY THIS DIAGNOSTIC.')
    $lines.Add('')
    $lines.Add(('Selected Truck ID: ' + $TruckId))
    $lines.Add(('Baseline PAK: ' + $PakPath))
    $lines.Add('')

    $idLower = $TruckId.ToLowerInvariant()
    $fileName = $idLower + '.xml'
    $candidates = New-Object Collections.Generic.List[object]
    $fs = $null; $zip = $null
    try {
        $fs = [IO.File]::OpenRead($PakPath)
        $zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Read)
        $lines.Add(('Archive entries: ' + $zip.Entries.Count))
        foreach ($entry in $zip.Entries) {
            if (-not $entry.FullName.EndsWith('.xml', [StringComparison]::OrdinalIgnoreCase)) { continue }
            $norm = $entry.FullName.Replace('\','/').TrimStart('/').ToLowerInvariant()
            $leaf = [IO.Path]::GetFileName($norm)
            $pathHit = ($leaf -eq $fileName) -or ($norm -like ('*' + $idLower + '*'))
            if (-not $pathHit) { continue }

            $isTruck = $false
            $readError = ''
            try {
                $stream = $entry.Open()
                try {
                    $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $true)
                    try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
                } finally { $stream.Dispose() }
                $isTruck = ($text -match '(?is)<Truck(?:\s|>)')
            } catch { $readError = $_.Exception.Message }

            $candidates.Add([pscustomobject]@{ Entry=$entry.FullName; Leaf=$leaf; IsTruck=$isTruck; Error=$readError })
        }
    } finally {
        if ($null -ne $zip) { $zip.Dispose() }
        if ($null -ne $fs) { $fs.Dispose() }
    }

    $lines.Add(('Candidate entries containing ID / matching filename: ' + $candidates.Count))
    foreach ($c in $candidates) {
        $lines.Add(('  Entry: ' + $c.Entry))
        $lines.Add(('    Filename: ' + $c.Leaf))
        $lines.Add(('    Contains <Truck>: ' + $c.IsTruck))
        if ($c.Error) { $lines.Add(('    Read error: ' + $c.Error)) }
    }

    # Resolve by exact XML filename + verified <Truck>, regardless of archive folder layout.
    $verified = @($candidates | Where-Object { $_.Leaf -eq $fileName -and $_.IsTruck })
    $lines.Add('')
    $lines.Add(('Verified exact-filename Truck matches: ' + $verified.Count))
    foreach ($v in $verified) { $lines.Add(('  ' + $v.Entry)) }

    if ($verified.Count -eq 1) {
        $lines.Add(('RESOLVED: ' + $verified[0].Entry))
        return [string]$verified[0].Entry
    }

    $lines.Add('RESOLUTION FAILED.')
    if ($verified.Count -eq 0) {
        throw ("TEST 6.9 safety stop: no verified exact XML filename match was found for truck ID '" + $TruckId + "'. No modifications were made.`r`n`r`nResolver report:`r`n" + $report)
    }
    throw ("TEST 6.9 safety stop: truck ID '" + $TruckId + "' matched " + $verified.Count + " verified Truck XML entries. Refusing an ambiguous edit.`r`n`r`nResolver report:`r`n" + $report)
}


function Write-SelectedTruckComponentDiagnostic([string]$PakPath, [string]$TruckEntry, [string]$TruckId) {
    if ([string]::IsNullOrWhiteSpace($TruckEntry)) { return }
    $desktop = [Environment]::GetFolderPath('Desktop')
    $report = Join-Path $desktop 'WL-SnowRunner-TEST6.6-ComponentMap.txt'
    $xmlOut = Join-Path $desktop 'WL-SnowRunner-TEST6.6-SelectedTruck.xml'
    $fs=$null; $zip=$null
    try {
        $fs=[IO.File]::OpenRead($PakPath)
        $zip=New-Object IO.Compression.ZipArchive($fs,[IO.Compression.ZipArchiveMode]::Read)
        $targetNorm=$TruckEntry.Replace('/','\')
        $entry=@($zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($targetNorm,[StringComparison]::OrdinalIgnoreCase) })
        if ($entry.Count -ne 1) { throw "Expected one selected truck entry, found $($entry.Count)." }
        $st=$entry[0].Open()
        try { $rd=New-Object IO.StreamReader($st,[Text.Encoding]::UTF8,$true); try { $text=$rd.ReadToEnd() } finally { $rd.Dispose() } } finally { $st.Dispose() }
        $text | Set-Content -LiteralPath $xmlOut -Encoding UTF8
        $lines=New-Object Collections.Generic.List[string]
        $lines.Add('WL Simplistic SnowRunner Mod Editor v1.1.0 TEST 6.10 - COMPONENT MAP')
        $lines.Add(('Generated: '+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
        $lines.Add('DIAGNOSTIC. TEST 6.8 diagnostic only; no private engine clone is installed.')
        $lines.Add('')
        $lines.Add(('Truck ID: '+$TruckId)); $lines.Add(('Truck entry: '+$TruckEntry)); $lines.Add('')
        $lines.Add('Lines/tags containing likely component references:')
        foreach($line in ($text -split "`r?`n")) {
            if($line -match '(?i)engine|gearbox|suspension|wheel|tire|winch|socket|template') { $lines.Add(('  '+$line.Trim())) }
        }
        $lines.Add('')
        $lines.Add('Quoted values containing likely component keywords:')
        $seen=@{}
        foreach($m in [regex]::Matches($text,'"([^"\r\n]+)"')) {
            $v=$m.Groups[1].Value
            if($v -match '(?i)engine|gearbox|susp|wheel|tire|winch' -and -not $seen.ContainsKey($v)) { $seen[$v]=$true; $lines.Add(('  '+$v)) }
        }
        $lines.Add(''); $lines.Add(('Full selected truck XML copy: '+$xmlOut))
        $lines | Set-Content -LiteralPath $report -Encoding UTF8
    } finally { if($null-ne $zip){$zip.Dispose()}; if($null-ne $fs){$fs.Dispose()} }
}

function Write-TireFamilyDiagnostic([string]$PakPath, [string]$TruckEntry, [string]$TruckId) {
    if ([string]::IsNullOrWhiteSpace($TruckEntry)) { return }
    $desktop=[Environment]::GetFolderPath('Desktop')
    $report=Join-Path $desktop 'WL-SnowRunner-TEST6.13.1-WheelResolution.txt'
    $fs=$null; $zip=$null
    try {
        $fs=[IO.File]::OpenRead($PakPath)
        $zip=New-Object IO.Compression.ZipArchive($fs,[IO.Compression.ZipArchiveMode]::Read)
        $truck=@($zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) })
        if($truck.Count -ne 1){throw "TEST 6.13 wheel diagnostic: expected one selected truck XML, found $($truck.Count)."}
        $st=$truck[0].Open(); try{$rd=New-Object IO.StreamReader($st,[Text.Encoding]::UTF8,$true);try{$truckText=$rd.ReadToEnd()}finally{$rd.Dispose()}}finally{$st.Dispose()}
        $wm=[regex]::Match($truckText,'(?is)<Wheels\b[^>]*>')
        if(-not $wm.Success){throw 'TEST 6.13 wheel diagnostic: selected truck has no resolvable <Wheels> tag.'}
        $dt=[regex]::Match($wm.Value,'(?i)\bDefaultTire="([^"]+)"'); $dw=[regex]::Match($wm.Value,'(?i)\bDefaultWheelType="([^"]+)"')
        $defaultTire=if($dt.Success){$dt.Groups[1].Value}else{''}; $wheelType=if($dw.Success){$dw.Groups[1].Value}else{''}
        $exact=@($zip.Entries | Where-Object { $_.Name.Equals(($wheelType+'.xml'),[StringComparison]::OrdinalIgnoreCase) -and $_.FullName.Replace('/','\') -match '(?i)\\classes\\wheels\\[^\\]+\.xml$' })
        $lines=New-Object Collections.Generic.List[string]
        $lines.Add('WL Simplistic SnowRunner Mod Editor v1.1.0 TEST 6.21.3 - WHEEL FAMILY RESOLUTION')
        $lines.Add(('Generated: '+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
        $lines.Add('READ-ONLY DIAGNOSTIC. NO TIRE/WHEEL MODIFICATION IS PERFORMED BY TEST 6.13.')
        $lines.Add(''); $lines.Add(('Truck ID: '+$TruckId)); $lines.Add(('Truck entry: '+$TruckEntry)); $lines.Add(('Wheels tag: '+$wm.Value.Trim()))
        $lines.Add(('DefaultTire: '+$defaultTire)); $lines.Add(('DefaultWheelType: '+$wheelType)); $lines.Add(('Exact wheel-family filename matches: '+$exact.Count));
        foreach($e in $exact){$lines.Add(('  EXACT FAMILY: '+$e.FullName))}
        $lines.Add(''); $lines.Add('TRUCK XMLs USING THIS DefaultWheelType:')
        $truckHits=0
        foreach($e in $zip.Entries){
            $n=$e.FullName.Replace('/','\'); if($n -notmatch '(?i)\\classes\\trucks\\[^\\]+\.xml$'){continue}
            $es=$e.Open(); try{$r=New-Object IO.StreamReader($es,[Text.Encoding]::UTF8,$true);try{$t=$r.ReadToEnd()}finally{$r.Dispose()}}finally{$es.Dispose()}
            if($t -match ('(?i)\bDefaultWheelType="'+[regex]::Escape($wheelType)+'"')){
                $truckHits++; $dm=[regex]::Match($t,'(?is)<Wheels\b[^>]*\bDefaultWheelType="'+[regex]::Escape($wheelType)+'"[^>]*>')
                $lines.Add(('  '+$e.FullName)); if($dm.Success){$lines.Add(('    '+$dm.Value.Trim()))}
            }
        }
        $lines.Add(('Truck references found: '+$truckHits))
        $lines.Add(''); $lines.Add('EXACT WHEEL FAMILY CONTENT (wheel/tire structure):')
        foreach($e in $exact){
            $lines.Add(('  ENTRY: '+$e.FullName)); $es=$e.Open(); try{$r=New-Object IO.StreamReader($es,[Text.Encoding]::UTF8,$true);try{$t=$r.ReadToEnd()}finally{$r.Dispose()}}finally{$es.Dispose()}
            foreach($line in ($t -split "`r?`n")){if($line -match '(?i)<TruckWheels|</TruckWheels|<TruckTire|</TruckTire|<TruckRim|<WheelFriction|<WheelSoftness|<WheelTracks|_template=|Name=|BodyFriction|SubstanceFriction|DamageCapacity'){$lines.Add(('    '+$line.Trim()))}}
        }
        $lines.Add(''); $lines.Add('OTHER XML REFERENCES TO THIS WHEEL FAMILY TOKEN (excluding selected truck):')
        $refs=0
        foreach($e in $zip.Entries){
            if(-not $e.FullName.EndsWith('.xml',[StringComparison]::OrdinalIgnoreCase)){continue}; if($e.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase)){continue}
            $es=$e.Open(); try{$r=New-Object IO.StreamReader($es,[Text.Encoding]::UTF8,$true);try{$t=$r.ReadToEnd()}finally{$r.Dispose()}}finally{$es.Dispose()}
            if($t.IndexOf($wheelType,[StringComparison]::OrdinalIgnoreCase) -ge 0){$refs++; $lines.Add(('  '+$e.FullName)); foreach($line in ($t -split "`r?`n")){if($line.IndexOf($wheelType,[StringComparison]::OrdinalIgnoreCase) -ge 0){$lines.Add(('    '+$line.Trim()))}}}
        }
        $lines.Add(('Other XML reference files: '+$refs))
        $lines.Add(''); $lines.Add('PURPOSE: determine whether DefaultWheelType is a filename/class token that can safely be isolated, and identify all stock trucks that share the selected wheel family before TEST 6.14.')
        $lines | Set-Content -LiteralPath $report -Encoding UTF8
        $localReport = Join-Path $PSScriptRoot 'WL-SnowRunner-TEST6.13.1-WheelResolution.txt'
        $lines | Set-Content -LiteralPath $localReport -Encoding UTF8
    } finally {if($zip){$zip.Dispose()};if($fs){$fs.Dispose()}}
}

function Get-IndividualEnginePlan([string]$PakPath, [string]$TruckEntry, [string]$TruckId) {
    $input = $null; $zip = $null
    try {
        $input = [IO.File]::OpenRead($PakPath)
        $zip = New-Object IO.Compression.ZipArchive($input, [IO.Compression.ZipArchiveMode]::Read)
        $truck = $zip.Entries | Where-Object { $_.FullName.Replace('/', '\').Equals($TruckEntry.Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if (-not $truck) { throw 'RC3.6 engine safety stop: selected truck XML could not be reopened. No modifications were made.' }
        $reader = New-Object IO.StreamReader($truck.Open(), [Text.Encoding]::UTF8, $true)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $m = [regex]::Match($text, '(?is)<EngineSocket\b(?=[^>]*\bDefault="([^"]+)")(?=[^>]*\bType="([^"]+)")[^>]*/?>')
        if (-not $m.Success) { throw 'RC3.6 engine safety stop: EngineSocket Default/Type could not be resolved. No modifications were made.' }
        $engineDefault=$m.Groups[1].Value; $engineTypeRaw=$m.Groups[2].Value
        # RC3.6: every token in EngineSocket Type is a compatible engine family for this truck.
        # Modify all existing compatible family XMLs in place; never clone/repoint identifiers.
        $engineTypes = @($engineTypeRaw -split '\s*,\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
        if($engineTypes.Count -lt 1){ throw 'RC3.6 engine safety stop: no compatible engine-family tokens were resolved.' }
        $families = @()
        foreach($candidateType in $engineTypes){
            $wanted = ($candidateType + '.xml').ToLowerInvariant()
            $entries = @($zip.Entries | Where-Object { $_.Name.ToLowerInvariant() -eq $wanted -and $_.FullName.Replace('/', '\').ToLowerInvariant() -match '\\classes\\engines\\[^\\]+\.xml$' })
            if($entries.Count -ne 1){ throw "RC3.6 engine safety stop: compatible engine family '$candidateType' resolved to $($entries.Count) XML files; expected exactly 1. No modifications were made." }
            $er=New-Object IO.StreamReader($entries[0].Open(),[Text.Encoding]::UTF8,$true); try{$et=$er.ReadToEnd()}finally{$er.Dispose()}
            $variantCount=[regex]::Matches($et,'(?is)<Engine\b(?=[^>]*\bName="[^"]+")[^>]*>.*?</Engine>').Count
            if($variantCount -lt 1){ throw "RC3.6 engine safety stop: compatible engine family '$candidateType' contains no named engine variants. No modifications were made." }
            $families += [pscustomobject]@{Type=[string]$candidateType; Entry=[string]$entries[0].FullName; VariantCount=[int]$variantCount}
        }
        # The stock/default engine must exist in at least one declared compatible family.
        $defaultHits=0
        foreach($fam in $families){
            $e=$zip.Entries | Where-Object {$_.FullName -eq $fam.Entry} | Select-Object -First 1
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true); try{$tt=$rr.ReadToEnd()}finally{$rr.Dispose()}
            if([regex]::IsMatch($tt,('(?is)<Engine\b(?=[^>]*\bName="'+[regex]::Escape($engineDefault)+'")[^>]*>'))){$defaultHits++}
        }
        if($defaultHits -lt 1){ throw "RC3.6 engine safety stop: stock/default engine '$engineDefault' was not found in any declared compatible engine family. No modifications were made." }
        return [pscustomobject]@{ Default=[string]$engineDefault; Types=[string[]]@($families | ForEach-Object {[string]$_.Type}); SourceEntries=[string[]]@($families | ForEach-Object {[string]$_.Entry}); Families=[object[]]@($families) }
    } finally { if ($zip) {$zip.Dispose()}; if ($input) {$input.Dispose()} }
}

function Write-EngineFamilyDiagnostic([string]$PakPath, $Plan, [string]$TruckId) {
    if (-not $Plan) { return }
    $desktop=[Environment]::GetFolderPath('Desktop')
    $report=Join-Path $desktop 'WL-SnowRunner-TEST6.8-EngineFamilyMap.txt'
    $xmlOut=Join-Path $desktop 'WL-SnowRunner-TEST6.8-EngineFamily.xml'
    $fs=$null; $zip=$null
    try {
        $fs=[IO.File]::OpenRead($PakPath); $zip=New-Object IO.Compression.ZipArchive($fs,[IO.Compression.ZipArchiveMode]::Read)
        $src=@($zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals(([string]$Plan.SourceEntry).Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) })
        if($src.Count -ne 1){ throw "TEST 6.8 diagnostic: expected one engine-family source, found $($src.Count)." }
        $st=$src[0].Open(); try{$rd=New-Object IO.StreamReader($st,[Text.Encoding]::UTF8,$true);try{$engineText=$rd.ReadToEnd()}finally{$rd.Dispose()}}finally{$st.Dispose()}
        $engineText | Set-Content -LiteralPath $xmlOut -Encoding UTF8
        $refs=New-Object Collections.Generic.List[string]
        foreach($e in $zip.Entries){
            if(-not $e.FullName.EndsWith('.xml',[StringComparison]::OrdinalIgnoreCase)){continue}
            $es=$e.Open(); try{$r=New-Object IO.StreamReader($es,[Text.Encoding]::UTF8,$true);try{$t=$r.ReadToEnd()}finally{$r.Dispose()}}finally{$es.Dispose()}
            if($t -match ('(?i)Type="'+[regex]::Escape([string]$Plan.Type)+'"') -or $t -match ('(?i)Default="'+[regex]::Escape([string]$Plan.Default)+'"')){$refs.Add($e.FullName)}
        }
        $lines=New-Object Collections.Generic.List[string]
        $lines.Add('WL Simplistic SnowRunner Mod Editor v1.1.0 TEST 6.10 - ENGINE FAMILY MAP')
        $lines.Add(('Generated: '+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
        $lines.Add('DIAGNOSTIC REPORT. TEST 6.9 Apply may add a private engine variant; this report itself modifies nothing.')
        $lines.Add(''); $lines.Add(('Truck ID: '+$TruckId)); $lines.Add(('Engine default: '+$Plan.Default)); $lines.Add(('Engine type/family: '+$Plan.Type)); $lines.Add(('Engine family XML: '+$Plan.SourceEntry)); $lines.Add(('6.7 failed family-clone entry was: '+$Plan.CloneEntry));
        $lines.Add(''); $lines.Add(('XML entries referencing this family/default: '+$refs.Count)); foreach($x in $refs){$lines.Add(('  '+$x))}
        $lines.Add(''); $lines.Add('Engine-family XML structure:');
        foreach($line in ($engineText -split "`r?`n")){if($line -match '(?i)<Engine|_template|Include=|Name=|Torque=|FuelConsumption=|DamageCapacity=|CriticalDamageThreshold='){$lines.Add(('  '+$line.Trim()))}}
        $lines.Add(''); $lines.Add(('Full engine-family XML copy: '+$xmlOut)); $lines | Set-Content -LiteralPath $report -Encoding UTF8
    } finally {if($zip){$zip.Dispose()};if($fs){$fs.Dispose()}}
}

function Repoint-IndividualEngine([string]$Text, $S, $Counts) {
    if (-not $S.TargetTruckId) { return $Text }
    $engineChange = ([math]::Abs([double]$S.EngineTorque-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.EngineResponse-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.EngineFuel-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.EngineDurability-1.0) -ge 0.0000001)
    if (-not $engineChange) { return $Text }
    if (-not $S.IndividualEnginePrivateName) { throw 'TEST 6.9 engine-variant safety stop: private engine variant was not prepared.' }
    $oldDefault = [string]$S.IndividualEngineDefault
    $engineType = [string]$S.IndividualEngineType
    # TEST 6.20.4: match the EngineSocket tag independent of attribute order.
    # SnowRunner truck XML commonly stores Default before Type; the old repoint regex
    # incorrectly required Type to appear before Default and therefore reported 0 hits.
    $tagPattern = '(?is)<EngineSocket\b(?=[^>]*\bType="' + [regex]::Escape($engineType) + '")(?=[^>]*\bDefault="' + [regex]::Escape($oldDefault) + '")[^>]*/?>'
    $tagMatches = [regex]::Matches($Text, $tagPattern)
    $hits = $tagMatches.Count
    if ($hits -ne 1) { throw "TEST 6.9 engine-variant safety stop: selected truck contains $hits matching EngineSocket Default references; expected exactly 1." }
    $newName = [string]$S.IndividualEnginePrivateName
    $tag = $tagMatches[0].Value
    $newTag = [regex]::Replace($tag, '(?i)(\bDefault=")' + [regex]::Escape($oldDefault) + '(")', { param($m) $m.Groups[1].Value + $newName + $m.Groups[2].Value }, 1)
    if ($newTag -eq $tag) { throw 'TEST 6.20.4 engine-variant safety stop: EngineSocket was resolved but its Default value could not be repointed. No modifications were made.' }
    $Text = $Text.Substring(0,$tagMatches[0].Index) + $newTag + $Text.Substring($tagMatches[0].Index + $tagMatches[0].Length)
    Add-Count $Counts 'Individual engine variant reference' 1
    return $Text
}

function Add-PrivateEngineVariant([string]$Text, $S, $Counts) {
    $defaultName = [regex]::Escape([string]$S.IndividualEngineDefault)
    $privateName = [string]$S.IndividualEnginePrivateName
    if (-not $defaultName -or -not $privateName) { throw 'TEST 6.9 engine-variant safety stop: engine variant names are missing.' }
    if ($Text -match ('(?i)\bName="' + [regex]::Escape($privateName) + '"')) { throw 'TEST 6.9 engine-variant safety stop: private engine variant already exists in baseline unexpectedly.' }
    $pattern = '(?is)<Engine\b(?=[^>]*\bName="' + $defaultName + '")[^>]*>.*?</Engine>'
    $matches = [regex]::Matches($Text, $pattern)
    if ($matches.Count -ne 1) { throw "TEST 6.9 engine-variant safety stop: default engine '$($S.IndividualEngineDefault)' matched $($matches.Count) variant blocks; expected exactly 1." }
    $block = $matches[0].Value
    $clone = [regex]::Replace($block, '(?i)(\bName=")' + $defaultName + '(")', { param($m) $m.Groups[1].Value + $privateName + $m.Groups[2].Value }, 1)
    # TEST 6.21.1: all individual engine controls modify only the selected truck's
    # private variant inside the existing stock engine family. The stock family
    # Type remains unchanged, preserving the proven TEST 6.9 architecture.
    # TEST 6.21.2: each private-engine control is independent. A stock 1.00
    # multiplier means leave that attribute untouched; it is not a safety failure.
    if ([math]::Abs([double]$S.EngineTorque-1.0) -ge 0.0000001) {
        $before = if ($Counts.ContainsKey('Engine torque')) { [int]$Counts['Engine torque'] } else { 0 }
        $clone = Replace-NumericAttribute $clone 'Torque' ([double]$S.EngineTorque) $Counts 'Engine torque'
        $after = if ($Counts.ContainsKey('Engine torque')) { [int]$Counts['Engine torque'] } else { 0 }
        if (($after-$before) -ne 1) { throw "TEST 6.21.2 engine-variant safety stop: Torque was requested but expected exactly 1 Torque value in cloned engine variant; changed $($after-$before)." }
    }

    # TEST 6.21.1: EngineResponsiveness can be inherited from the engine template.
    # If the selected variant does not explicitly carry it, resolve the template value
    # and write an explicit override into only the private variant.
    if ([math]::Abs([double]$S.EngineResponse-1.0) -ge 0.0000001) {
        if ([regex]::IsMatch($clone,'(?i)\bEngineResponsiveness="[^"]+"')) {
            $clone = Replace-NumericAttribute $clone 'EngineResponsiveness' ([double]$S.EngineResponse) $Counts 'Engine responsiveness'
        } else {
            $baseResponse = $null
            $tm = [regex]::Match($block,'(?i)\b_template="([^"]+)"')
            if ($tm.Success) {
                $templateName=[regex]::Escape($tm.Groups[1].Value)
                $templateTag=[regex]::Match($Text,('(?is)<' + $templateName + '\b[^>]*>'))
                if (-not $templateTag.Success) { $templateTag=[regex]::Match($Text,('(?is)<' + $templateName + '\b[^>]*/>')) }
                if ($templateTag.Success) {
                    $rm=[regex]::Match($templateTag.Value,'(?i)\bEngineResponsiveness="([0-9eE+\-.]+)"')
                    if ($rm.Success) { $baseResponse=[double]::Parse($rm.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture) }
                }
            }
            # Saber documentation defines 0.04 as the EngineResponsiveness default.
            # Use it only when neither the variant nor its template provides a value.
            if ($null -eq $baseResponse) { $baseResponse=0.04 }
            $newResponse=$baseResponse * [double]$S.EngineResponse
            if ($newResponse -gt 1.0) { $newResponse=1.0 }
            if ($newResponse -lt 0.01) { $newResponse=0.01 }
            $formatted=$newResponse.ToString('0.######',[Globalization.CultureInfo]::InvariantCulture)
            $open=[regex]::Match($clone,'(?is)<Engine\b[^>]*>')
            if (-not $open.Success) { throw 'TEST 6.21.1 engine responsiveness safety stop: private Engine opening tag could not be found.' }
            $newOpen=$open.Value.Insert($open.Value.Length-1,(' EngineResponsiveness="'+$formatted+'"'))
            $clone=$clone.Substring(0,$open.Index)+$newOpen+$clone.Substring($open.Index+$open.Length)
            Add-Count $Counts 'Engine responsiveness' 1
        }
    }
    $clone = Replace-NumericAttribute $clone 'FuelConsumption' ([double]$S.EngineFuel) $Counts 'Engine fuel consumption'
    $clone = Replace-NumericAttribute $clone 'DamageCapacity' ([double]$S.EngineDurability) $Counts 'Engine durability'
    $close = [regex]::Matches($Text, '(?i)</EngineVariants>')
    if ($close.Count -ne 1) { throw "TEST 6.9 engine-variant safety stop: expected exactly 1 </EngineVariants> tag; found $($close.Count)." }
    $insert = "`r`n`t<!-- WL private engine variant for $($S.TargetTruckId) -->`r`n" + $clone + "`r`n"
    $Text = $Text.Insert($close[0].Index, $insert)
    Add-Count $Counts 'Private engine variants added' 1
    return $Text
}

function Get-IndividualGearboxPlan([string]$PakPath, [string]$TruckEntry, [string]$TruckId) {
    $input=$null; $zip=$null
    try {
        $input=[IO.File]::OpenRead($PakPath); $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $truck=$zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if(-not $truck){throw 'TEST 6.10 gearbox safety stop: selected truck XML could not be reopened.'}
        $reader=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
        $m=[regex]::Match($text,'(?is)<GearboxSocket\b(?=[^>]*\bDefault="([^"]+)")(?=[^>]*\bType="([^"]+)")[^>]*/?>')
        if(-not $m.Success){throw 'TEST 6.10 gearbox safety stop: GearboxSocket Default/Type could not be resolved.'}
        $def=$m.Groups[1].Value; $type=$m.Groups[2].Value; $wanted=($type+'.xml').ToLowerInvariant()
        $matches=@($zip.Entries | Where-Object { $_.Name.ToLowerInvariant() -eq $wanted -and $_.FullName.Replace('/','\').ToLowerInvariant() -match '\\classes\\gearboxes\\[^\\]+\.xml$' })
        if($matches.Count -ne 1){throw "TEST 6.10 gearbox safety stop: gearbox family '$type' matched $($matches.Count) XML entries; expected exactly 1."}
        return [pscustomobject]@{Default=$def;Type=$type;SourceEntry=$matches[0].FullName}
    } finally {if($zip){$zip.Dispose()};if($input){$input.Dispose()}}
}


function Repoint-IndividualGearbox([string]$Text,$S,$Counts) {
    if(-not $S.TargetTruckId){return $Text}
    $gearboxChange = ([math]::Abs([double]$S.GearSpeed-1.0)-ge 0.0000001) -or ([math]::Abs([double]$S.GearboxFuel-1.0)-ge 0.0000001) -or ([math]::Abs([double]$S.AwdFuel-1.0)-ge 0.0000001) -or ([math]::Abs([double]$S.IdleFuel-1.0)-ge 0.0000001) -or ([math]::Abs([double]$S.GearboxDurability-1.0)-ge 0.0000001)
    if(-not $gearboxChange){return $Text}
    if(-not $S.IndividualGearboxPrivateName){throw 'TEST 6.10 gearbox safety stop: private gearbox variant was not prepared.'}
    $old=[regex]::Escape([string]$S.IndividualGearboxDefault)
    $pattern='(?is)(<GearboxSocket\b(?=[^>]*\bType="'+[regex]::Escape([string]$S.IndividualGearboxType)+'")[^>]*\bDefault=")'+$old+'("[^>]*/?>)'
    $hits=[regex]::Matches($Text,$pattern).Count
    if($hits-ne 1){throw "TEST 6.10 gearbox safety stop: selected truck contains $hits matching GearboxSocket references; expected 1."}
    $new=[string]$S.IndividualGearboxPrivateName
    $Text=[regex]::Replace($Text,$pattern,{param($m)$m.Groups[1].Value+$new+$m.Groups[2].Value},1)
    Add-Count $Counts 'Individual gearbox variant reference' 1
    return $Text
}

function Add-PrivateGearboxVariant([string]$Text,$S,$Counts) {
    $def=[regex]::Escape([string]$S.IndividualGearboxDefault); $private=[string]$S.IndividualGearboxPrivateName
    if(-not $def-or-not $private){throw 'TEST 6.10 gearbox safety stop: gearbox variant names are missing.'}
    if($Text-match('(?i)\bName="'+[regex]::Escape($private)+'"')){throw 'TEST 6.10 gearbox safety stop: private gearbox variant already exists unexpectedly.'}
    $pattern='(?is)<Gearbox\b(?=[^>]*\bName="'+$def+'")[^>]*>.*?</Gearbox>'
    $ms=[regex]::Matches($Text,$pattern)
    if($ms.Count-ne 1){throw "TEST 6.10 gearbox safety stop: default gearbox '$($S.IndividualGearboxDefault)' matched $($ms.Count) blocks; expected 1."}
    $clone=$ms[0].Value
    $clone=[regex]::Replace($clone,'(?i)(\bName=")'+$def+'(")',{param($m)$m.Groups[1].Value+$private+$m.Groups[2].Value},1)
    # TEST 6.23.1: legacy private gearbox helper retained but no longer used by the active individual path.
    if([math]::Abs([double]$S.GearSpeed-1.0)-ge 0.0000001){
        $before=if($Counts.ContainsKey('Gear speed')){[int]$Counts['Gear speed']}else{0}
        $clone=Replace-NumericAttribute $clone 'AngVel' ([double]$S.GearSpeed) $Counts 'Gear speed'
        $after=if($Counts.ContainsKey('Gear speed')){[int]$Counts['Gear speed']}else{0}
        if(($after-$before)-lt 1){throw 'TEST 6.23.1 gearbox safety stop: cloned gearbox contained no AngVel values to modify.'}
    }
    if([math]::Abs([double]$S.GearboxFuel-1.0)-ge 0.0000001){
        $clone=Replace-NumericAttribute $clone 'FuelConsumption' ([double]$S.GearboxFuel) $Counts 'Gearbox fuel consumption'
    }
    if([math]::Abs([double]$S.AwdFuel-1.0)-ge 0.0000001){
        $clone=Replace-NumericAttribute $clone 'AWDConsumptionModifier' ([double]$S.AwdFuel) $Counts 'AWD fuel penalty'
    }
    if([math]::Abs([double]$S.IdleFuel-1.0)-ge 0.0000001){
        $clone=Replace-NumericAttribute $clone 'IdleFuelModifier' ([double]$S.IdleFuel) $Counts 'Idle fuel use'
    }
    if([math]::Abs([double]$S.GearboxDurability-1.0)-ge 0.0000001){
        $clone=Replace-NumericAttribute $clone 'DamageCapacity' ([double]$S.GearboxDurability) $Counts 'Gearbox durability'
    }
    $close=[regex]::Matches($Text,'(?i)</GearboxVariants>')
    if($close.Count-ne 1){throw "TEST 6.10 gearbox safety stop: expected exactly 1 </GearboxVariants>; found $($close.Count)."}
    $insert="`r`n`t<!-- WL private gearbox variant for $($S.TargetTruckId) -->`r`n"+$clone+"`r`n"
    $Text=$Text.Insert($close[0].Index,$insert); Add-Count $Counts 'Private gearbox variants added' 1; return $Text
}

function Get-IndividualTirePlan([string]$PakPath,[string]$TruckEntry,[string]$TruckId) {
    $input=$null; $zip=$null
    try {
        $input=[IO.File]::OpenRead($PakPath); $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $truck=$zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if(-not $truck){throw 'TEST 6.12 tire safety stop: selected truck XML could not be reopened.'}
        $reader=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
        $wm=[regex]::Match($text,'(?is)<Wheels\b[^>]*>')
        if(-not $wm.Success){throw 'TEST 6.12 tire safety stop: selected truck has no resolvable <Wheels> tag.'}
        $dt=[regex]::Match($wm.Value,'(?i)\bDefaultTire="([^"]+)"'); $dw=[regex]::Match($wm.Value,'(?i)\bDefaultWheelType="([^"]+)"')
        if(-not $dt.Success -or -not $dw.Success){throw 'TEST 6.12 tire safety stop: DefaultTire/DefaultWheelType could not be resolved.'}
        $def=$dt.Groups[1].Value; $type=$dw.Groups[1].Value; $wanted=($type+'.xml').ToLowerInvariant()
        $matches=@($zip.Entries | Where-Object { $_.Name.ToLowerInvariant() -eq $wanted -and $_.FullName.Replace('/','\').ToLowerInvariant() -match '\\classes\\wheels\\[^\\]+\.xml$' })
        if($matches.Count -ne 1){throw "TEST 6.12 tire safety stop: wheel family '$type' matched $($matches.Count) stock XML entries; expected exactly 1."}
        return [pscustomobject]@{Default=$def;WheelType=$type;SourceEntry=$matches[0].FullName}
    } finally {if($zip){$zip.Dispose()};if($input){$input.Dispose()}}
}

function Repoint-IndividualTire([string]$Text,$S,$Counts) {
    # TEST 6.14 does NOT invent a new tire Name. Keep DefaultTire unchanged.
    return $Text
}

function Repoint-IndividualWheelFamily([string]$Text,$S,$Counts) {
    $script:WLWheelDefaultHits=0
    if(-not $S.TargetTruckId -or [math]::Abs([double]$S.TireMud-1.0)-lt 0.0000001){return $Text}
    if(-not $S.IndividualWheelType -or -not $S.IndividualWheelPrivateType){throw 'TEST 6.14.1 wheel safety stop: private wheel family was not prepared.'}

    $old=[string]$S.IndividualWheelType
    $new=[string]$S.IndividualWheelPrivateType
    $wheelsPattern='(?is)<Wheels\b[^>]*>'
    $wheels=[regex]::Matches($Text,$wheelsPattern)
    if($wheels.Count -lt 1){throw 'TEST 6.14.1 wheel safety stop: selected truck contains no <Wheels> tag.'}

    $defaultHits=0
    $Text=[regex]::Replace($Text,$wheelsPattern,{
        param($m)
        $tag=$m.Value
        $p='(?i)(\bDefaultWheelType\s*=\s*")'+[regex]::Escape($old)+'(")'
        $n=[regex]::Matches($tag,$p).Count
        if($n -gt 0){
            $script:WLWheelDefaultHits += $n
            $tag=[regex]::Replace($tag,$p,{param($x)$x.Groups[1].Value+$new+$x.Groups[2].Value})
        }
        return $tag
    })
    $defaultHits=[int]$script:WLWheelDefaultHits
    $script:WLWheelDefaultHits=0
    if($defaultHits -ne 1){throw "TEST 6.14.1 wheel safety stop: selected truck contained $defaultHits DefaultWheelType references to '$old'; expected exactly 1."}

    # Also repoint CompatibleWheels/WheelType references in this selected truck only.
    $extraHits=0
    $patterns=@(
        '(?i)(<CompatibleWheels\b[^>]*\bType\s*=\s*")'+[regex]::Escape($old)+'(")',
        '(?i)(\bWheelType\s*=\s*")'+[regex]::Escape($old)+'(")'
    )
    foreach($pat in $patterns){
        $n=[regex]::Matches($Text,$pat).Count
        if($n -gt 0){
            $Text=[regex]::Replace($Text,$pat,{param($m)$m.Groups[1].Value+$new+$m.Groups[2].Value})
            $extraHits += $n
        }
    }
    Add-Count $Counts 'Individual wheel family references' ($defaultHits+$extraHits)
    return $Text
}

function Modify-PrivateWheelFamily([string]$Text,$S,$Counts) {
    # Keep all stock tire/rim names and meshes. Only scale mud grip in this cloned family.
    $before=if($Counts.ContainsKey('Tire mud grip')){[int]$Counts['Tire mud grip']}else{0}
    $Text=Replace-NumericAttribute $Text 'SubstanceFriction' ([double]$S.TireMud) $Counts 'Tire mud grip'
    $after=if($Counts.ContainsKey('Tire mud grip')){[int]$Counts['Tire mud grip']}else{0}
    if(($after-$before)-lt 1){throw 'TEST 6.14.1 wheel safety stop: private wheel family contained no SubstanceFriction values.'}
    Add-Count $Counts 'Private wheel families added' 1
    return $Text
}


function Write-StockWheelFamilyDiagnostic([string]$PakPath,[string]$TruckEntry,[string]$TruckId) {
    $desktop=[Environment]::GetFolderPath('Desktop')
    $report=Join-Path $desktop 'WL-SnowRunner-TEST6.17-StockWheelFamilyCandidates.txt'
    $lines=New-Object Collections.Generic.List[string]
    $lines.Add('WL Simplistic SnowRunner Mod Editor v1.1.0 TEST 6.21.3 - WHEEL/TIRE OVERRIDE MAP')
    $lines.Add(('Generated: '+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
    $lines.Add('READ-ONLY DIAGNOSTIC. NO FILES ARE MODIFIED BY THIS REPORT.')
    $lines.Add('')
    $lines.Add(('Selected truck: '+$TruckId))
    $lines.Add(('Truck entry: '+$TruckEntry))
    $lines.Add('')

    $fs=$null;$zip=$null
    try {
        $fs=[IO.File]::OpenRead($PakPath)
        $zip=New-Object IO.Compression.ZipArchive($fs,[IO.Compression.ZipArchiveMode]::Read)
        $utf8=New-Object Text.UTF8Encoding($false)

        $truck=$zip.Entries | Where-Object {$_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase)} | Select-Object -First 1
        if(-not $truck){throw 'TEST 6.18 diagnostic: selected truck XML could not be reopened.'}
        $r=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true)
        try{$truckText=$r.ReadToEnd()}finally{$r.Dispose()}

        $lines.Add('SELECTED TRUCK WHEEL-RELATED XML:')
        foreach($m in [regex]::Matches($truckText,'(?is)<Wheels\b.*?</Wheels>|<CompatibleWheels\b[^>]*/>|<Wheel\b[^>]*>|<WheelType\b[^>]*>')){
            $lines.Add($m.Value.Trim())
        }
        $lines.Add('')

        $wm=[regex]::Match($truckText,'(?is)<Wheels\b[^>]*>')
        $dw=[regex]::Match($wm.Value,'(?i)\bDefaultWheelType="([^"]+)"')
        $dt=[regex]::Match($wm.Value,'(?i)\bDefaultTire="([^"]+)"')
        $wheelType=if($dw.Success){$dw.Groups[1].Value}else{''}
        $defaultTire=if($dt.Success){$dt.Groups[1].Value}else{''}
        $lines.Add(('DefaultWheelType: '+$wheelType))
        $lines.Add(('DefaultTire: '+$defaultTire))
        $lines.Add('')

        $lines.Add('STOCK TRUCKS WITH WHEEL/TIRE ATTRIBUTES OUTSIDE THE NORMAL <Wheels> DEFAULTS:')
        $interesting=0
        foreach($e in $zip.Entries){
            $norm=$e.FullName.Replace('/','\').ToLowerInvariant()
            if($norm -notmatch '\\classes\\trucks\\[^\\]+\.xml$'){continue}
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true)
            try{$x=$rr.ReadToEnd()}finally{$rr.Dispose()}
            if($x -notmatch '<Truck>'){continue}
            $hits=New-Object Collections.Generic.List[string]
            foreach($m in [regex]::Matches($x,'(?im)^.*(?:BodyFrictionAsphalt|BodyFriction|SubstanceFriction|WheelFriction|DefaultWheelType|DefaultTire|CompatibleWheels|WheelType).*?$')){
                $v=$m.Value.Trim()
                if($v){$hits.Add($v)}
            }
            $frictionOutsideWheels=($x -match '(?i)BodyFrictionAsphalt|BodyFriction|SubstanceFriction|WheelFriction')
            $specialWheelRefs=($x -match '(?i)\bWheelType="' -or ([regex]::Matches($x,'(?i)<CompatibleWheels\b').Count -gt 0))
            if($frictionOutsideWheels -or $specialWheelRefs){
                $interesting++
                $lines.Add(('  FILE: '+$e.FullName))
                foreach($h in $hits){$lines.Add(('    '+$h))}
            }
        }
        $lines.Add(('Interesting base truck files: '+$interesting))
        $lines.Add('')

        $lines.Add('DIRECT FRICTION ATTRIBUTES FOUND IN BASE TRUCK XMLs:')
        $direct=0
        foreach($e in $zip.Entries){
            $norm=$e.FullName.Replace('/','\').ToLowerInvariant()
            if($norm -notmatch '\\classes\\trucks\\[^\\]+\.xml$'){continue}
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true)
            try{$x=$rr.ReadToEnd()}finally{$rr.Dispose()}
            if($x -notmatch '<Truck>'){continue}
            $ms=[regex]::Matches($x,'(?im)^.*(?:BodyFrictionAsphalt|BodyFriction|SubstanceFriction|WheelFriction).*?$')
            if($ms.Count -gt 0){
                $direct++
                $lines.Add(('  FILE: '+$e.FullName))
                foreach($m in $ms){$lines.Add(('    '+$m.Value.Trim()))}
            }
        }
        $lines.Add(('Base truck XMLs containing direct friction attributes: '+$direct))
        $lines.Add('')

        $lines.Add('WHEEL FAMILY INVENTORY / UNIQUENESS:')
        $usage=@{}
        foreach($e in $zip.Entries){
            $norm=$e.FullName.Replace('/','\').ToLowerInvariant()
            if($norm -notmatch '\\classes\\trucks\\[^\\]+\.xml$'){continue}
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true)
            try{$x=$rr.ReadToEnd()}finally{$rr.Dispose()}
            if($x -notmatch '<Truck>'){continue}
            $m=[regex]::Match($x,'(?is)<Wheels\b[^>]*\bDefaultWheelType="([^"]+)"')
            if($m.Success){
                $key=$m.Groups[1].Value
                if(-not $usage.ContainsKey($key)){$usage[$key]=New-Object Collections.Generic.List[string]}
                $usage[$key].Add($e.FullName)
            }
        }
        foreach($key in ($usage.Keys | Sort-Object)){
            $lines.Add(('  '+$key+' : '+$usage[$key].Count+' truck(s)'))
            if($usage[$key].Count -le 2){
                foreach($u in $usage[$key]){$lines.Add(('      '+$u))}
            }
        }
        $lines.Add('')
        
        $lines.Add('STOCK RECOGNIZED FAMILY CANDIDATES FOR SELECTED TRUCK:')
        $lines.Add('Criteria: family exists in initial.pak, is used as DefaultWheelType by <= 1 base truck, and contains selected DefaultTire name.')
        $candidateCount=0
        foreach($key in ($usage.Keys | Sort-Object)){
            if($usage[$key].Count -gt 1){continue}
            $family=$zip.Entries | Where-Object {
                $_.FullName.Replace('/','\').ToLowerInvariant() -match ('\\classes\\wheels\\'+[regex]::Escape($key.ToLowerInvariant())+'\.xml$')
            } | Select-Object -First 1
            if(-not $family){continue}
            $rr=New-Object IO.StreamReader($family.Open(),[Text.Encoding]::UTF8,$true)
            try{$fx=$rr.ReadToEnd()}finally{$rr.Dispose()}
            $hasTire=$false
            if($defaultTire){
                $hasTire=[regex]::IsMatch($fx,('(?i)<TruckTire\b[^>]*\bName="'+[regex]::Escape($defaultTire)+'"'))
            }
            if(-not $hasTire){continue}
            $candidateCount++
            $tireCount=[regex]::Matches($fx,'(?i)<TruckTire\b').Count
            $rimCount=[regex]::Matches($fx,'(?i)<TruckRim\b').Count
            $sfCount=[regex]::Matches($fx,'(?i)\bSubstanceFriction="').Count
            $bfCount=[regex]::Matches($fx,'(?i)\bBodyFriction="').Count
            $baCount=[regex]::Matches($fx,'(?i)\bBodyFrictionAsphalt="').Count
            $lines.Add(('  CANDIDATE: '+$key))
            $lines.Add(('    Entry: '+$family.FullName))
            $lines.Add(('    Default users: '+$usage[$key].Count))
            foreach($u in $usage[$key]){$lines.Add(('      User: '+$u))}
            $lines.Add(('    Contains tire "'+$defaultTire+'": YES'))
            $lines.Add(('    TruckTire definitions: '+$tireCount+' | TruckRim definitions: '+$rimCount))
            $lines.Add(('    Explicit friction attrs: Substance='+$sfCount+' Body='+$bfCount+' Asphalt='+$baCount))
        }
        $lines.Add(('Candidate count: '+$candidateCount))
        $lines.Add('')

        $lines.Add('UNUSED STOCK WHEEL FAMILY FILES:')
        $lines.Add('These exist in initial.pak but are not used as DefaultWheelType by any base truck. They are especially interesting because the identifier is stock/recognized and may avoid collateral changes.')
        $unusedCount=0
        foreach($e in $zip.Entries){
            $norm=$e.FullName.Replace('/','\').ToLowerInvariant()
            if($norm -notmatch '\\classes\\wheels\\([^\\]+)\.xml$'){continue}
            $familyId=$matches[1]
            if($usage.ContainsKey($familyId)){continue}
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true)
            try{$fx=$rr.ReadToEnd()}finally{$rr.Dispose()}
            if($fx -notmatch '(?i)<TruckTire\b'){continue}
            $hasSelected=$false
            if($defaultTire){$hasSelected=[regex]::IsMatch($fx,('(?i)<TruckTire\b[^>]*\bName="'+[regex]::Escape($defaultTire)+'"'))}
            $unusedCount++
            $lines.Add(('  UNUSED: '+$familyId+' | selected tire present: '+$hasSelected+' | '+$e.FullName))
        }
        $lines.Add(('Unused stock wheel-family files: '+$unusedCount))
        $lines.Add('')

        $lines.Add('SELECTED TRUCK COMPATIBLE-WHEEL FAMILY DETAILS:')
        foreach($m in [regex]::Matches($truckText,'(?is)<CompatibleWheels\b[^>]*>')){
            $tag=$m.Value
            $tm=[regex]::Match($tag,'(?i)\bType="([^"]+)"')
            if(-not $tm.Success){continue}
            $cid=$tm.Groups[1].Value
            $family=$zip.Entries | Where-Object {
                $_.FullName.Replace('/','\').ToLowerInvariant() -match ('\\classes\\wheels\\'+[regex]::Escape($cid.ToLowerInvariant())+'\.xml$')
            } | Select-Object -First 1
            $lines.Add(('  '+$tag.Trim()))
            if($family){
                $rr=New-Object IO.StreamReader($family.Open(),[Text.Encoding]::UTF8,$true)
                try{$fx=$rr.ReadToEnd()}finally{$rr.Dispose()}
                $hasSelected=if($defaultTire){[regex]::IsMatch($fx,('(?i)<TruckTire\b[^>]*\bName="'+[regex]::Escape($defaultTire)+'"'))}else{$false}
                $lines.Add(('    Family exists: YES | selected tire present: '+$hasSelected+' | Entry: '+$family.FullName))
            } else {
                $lines.Add('    Family exists: NO')
            }
        }
        $lines.Add('')
        $lines.Add('PURPOSE: identify an already-recognized STOCK wheel family that could isolate the selected truck without inventing a new DefaultWheelType or DefaultTire identifier.')

    } finally {
        if($zip){$zip.Dispose()}
        if($fs){$fs.Dispose()}
    }
    $lines | Set-Content -LiteralPath $report -Encoding UTF8
    return $report
}

function Get-IndividualSuspensionPlan([string]$PakPath,[string]$TruckEntry,[string]$TruckId) {
    $input=$null; $zip=$null
    try {
        $input=[IO.File]::OpenRead($PakPath); $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $truck=$zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if(-not $truck){throw 'RC3.7 suspension safety stop: selected truck XML could not be reopened. No modifications were made.'}
        $reader=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
        $m=[regex]::Match($text,'(?is)<SuspensionSocket\b(?=[^>]*\bDefault="([^"]+)")(?=[^>]*\bType="([^"]+)")[^>]*/?>')
        if(-not $m.Success){throw 'RC3.7 suspension safety stop: SuspensionSocket Default/Type could not be resolved. No modifications were made.'}
        $def=$m.Groups[1].Value
        # As with engines, Type can declare more than one compatible suspension family.
        $types=@($m.Groups[2].Value -split '[,;\s]+' | ForEach-Object {$_.Trim()} | Where-Object {$_} | Select-Object -Unique)
        if($types.Count -lt 1){throw 'RC3.7 suspension safety stop: no compatible suspension-family tokens were resolved. No modifications were made.'}
        $plans=@()
        $defaultHits=0
        foreach($type in $types){
            $wanted=($type+'.xml').ToLowerInvariant()
            $matches=@($zip.Entries | Where-Object { $_.Name.ToLowerInvariant() -eq $wanted -and $_.FullName.Replace('/','\').ToLowerInvariant() -match '\\classes\\suspensions\\[^\\]+\.xml$' })
            if($matches.Count -ne 1){throw "RC3.7 suspension safety stop: compatible suspension family '$type' matched $($matches.Count) XML entries; expected exactly 1. No modifications were made."}
            $rr=New-Object IO.StreamReader($matches[0].Open(),[Text.Encoding]::UTF8,$true); try{$fx=$rr.ReadToEnd()}finally{$rr.Dispose()}
            # Count named suspension variants for Preview/safety. SnowRunner suspension-family XMLs expose variants as named elements.
            $variantNames=@([regex]::Matches($fx,'(?is)<(?:Suspension|SuspensionSet)\b[^>]*\bName="([^"]+)"') | ForEach-Object {$_.Groups[1].Value} | Select-Object -Unique)
            if($variantNames.Count -lt 1){
                # Some families use a different wrapper; fall back to unique Name attributes in the family rather than failing a valid stock family.
                $variantNames=@([regex]::Matches($fx,'(?i)\bName="([^"]+)"') | ForEach-Object {$_.Groups[1].Value} | Select-Object -Unique)
            }
            if($variantNames.Count -lt 1){throw "RC3.7 suspension safety stop: compatible suspension family '$type' contains no named variants. No modifications were made."}
            if($variantNames -contains $def){$defaultHits++}
            $plans += [pscustomobject]@{Type=[string]$type;SourceEntry=[string]$matches[0].FullName;VariantCount=[int]$variantNames.Count;VariantNames=[string[]]$variantNames}
        }
        # Default can be inherited/aliased in some stock families, so require it only when it is directly named somewhere if discoverable.
        return [pscustomobject]@{Default=[string]$def;Types=[string[]]$types;Families=[object[]]$plans;DefaultHits=[int]$defaultHits}
    } finally {if($zip){$zip.Dispose()};if($input){$input.Dispose()}}
}

function Get-IndividualWinchPlan([string]$PakPath,[string]$TruckEntry,[string]$TruckId) {
    $input=$null; $zip=$null
    try {
        $input=[IO.File]::OpenRead($PakPath); $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $truck=$zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if(-not $truck){throw 'TEST 6.20.4 winch safety stop: selected truck XML could not be reopened.'}
        $reader=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
        $m=[regex]::Match($text,'(?is)<WinchUpgradeSocket\b(?=[^>]*\bDefault="([^"]+)")(?=[^>]*\bType="([^"]+)")[^>]*/?>')
        if(-not $m.Success){throw 'TEST 6.20.4 winch safety stop: WinchUpgradeSocket Default/Type could not be resolved.'}
        $def=$m.Groups[1].Value; $type=$m.Groups[2].Value; $wanted=($type+'.xml').ToLowerInvariant()
        $matches=@($zip.Entries | Where-Object { $_.Name.ToLowerInvariant() -eq $wanted -and $_.FullName.Replace('/','\').ToLowerInvariant() -match '\\classes\\winches\\[^\\]+\.xml$' })
        if($matches.Count -ne 1){throw "TEST 6.20.4 winch safety stop: winch family '$type' matched $($matches.Count) XML entries; expected exactly 1."}
        return [pscustomobject]@{Default=$def;Type=$type;SourceEntry=$matches[0].FullName}
    } finally {if($zip){$zip.Dispose()};if($input){$input.Dispose()}}
}

function Get-ServiceEquipmentDiagnostic([string]$PakPath,[string]$TruckEntry) {
    $input=$null; $zip=$null
    try {
        $input=[IO.File]::OpenRead($PakPath); $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $truck=$zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if(-not $truck){throw 'TEST 6.25.1 diagnostic safety stop: selected truck XML was not found.'}
        $r=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$text=$r.ReadToEnd()}finally{$r.Dispose()}
        $socketLines=New-Object 'System.Collections.Generic.List[string]'
        foreach($m in [regex]::Matches($text,'(?is)<AddonSocket\b[^>]*>')){$tag=([regex]::Replace($m.Value,'\s+',' ')).Trim();if($tag.Length -gt 220){$tag=$tag.Substring(0,220)+'...'};[void]$socketLines.Add($tag)}
        $nameTokens=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach($m in [regex]::Matches($text,'(?i)\bNames(?:Block|Shift)?="([^"]+)"')){foreach($n in ($m.Groups[1].Value -split '[,;\s]+')){if($n){[void]$nameTokens.Add($n.Trim())}}}
        $service=New-Object 'System.Collections.Generic.List[string]'
        foreach($e in $zip.Entries){
            $ep=$e.FullName.Replace('/','\'); if($ep -notmatch '(?i)\\classes\\trucks\\addons\\[^\\]+\.xml$'){continue}
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true); try{$x=$rr.ReadToEnd()}finally{$rr.Dispose()}
            if($x -notmatch '(?i)\b(?:FuelCapacity|RepairsCapacity|WheelRepairsCapacity)\s*='){continue}
            $base=[IO.Path]::GetFileNameWithoutExtension($e.Name); $attrs=@()
            foreach($a in @('FuelCapacity','RepairsCapacity','WheelRepairsCapacity')){$am=[regex]::Match($x,('(?i)\b'+$a+'\s*=\s*"([^"]+)"'));if($am.Success){$attrs+=($a+'='+$am.Groups[1].Value)}}
            $ref='not direct-matched';if($nameTokens.Contains($base)){$ref='DIRECT-NAME-MATCH'}
            [void]$service.Add(($base+' ['+($attrs -join ', ')+'] - '+$ref))
        }
        $o=New-Object Text.StringBuilder
        [void]$o.AppendLine('TEST 6.25.1 SERVICE EQUIPMENT DIAGNOSTIC');[void]$o.AppendLine('')
        [void]$o.AppendLine(('Truck entry: '+$TruckEntry));[void]$o.AppendLine(('AddonSocket tags found: '+$socketLines.Count));[void]$o.AppendLine(('Names/NamesBlock/NamesShift tokens: '+$nameTokens.Count));[void]$o.AppendLine(('Service-capacity addon XMLs in archive: '+$service.Count));[void]$o.AppendLine('')
        [void]$o.AppendLine('ADDON SOCKETS ON SELECTED TRUCK:');if($socketLines.Count -eq 0){[void]$o.AppendLine('  (none found)')}else{foreach($v in $socketLines | Select-Object -First 10){[void]$o.AppendLine(('  '+$v))}}
        [void]$o.AppendLine('');[void]$o.AppendLine('SERVICE ADDON CANDIDATES:');if($service.Count -eq 0){[void]$o.AppendLine('  (none found)')}else{foreach($v in $service | Select-Object -First 18){[void]$o.AppendLine(('  '+$v))}}
        if($service.Count -gt 18){[void]$o.AppendLine(('  ... '+($service.Count-18)+' more'))};[void]$o.AppendLine('');[void]$o.AppendLine('No diagnostic TXT file was written to the Desktop.');return $o.ToString()
    } finally {if($zip){$zip.Dispose()};if($input){$input.Dispose()}}
}

function Get-IndividualServiceAddonEntries([string]$PakPath,[string]$TruckEntry) {
    $input=$null; $zip=$null
    try {
        $input=[IO.File]::OpenRead($PakPath)
        $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $truck=$zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if(-not $truck){throw 'TEST 6.25.5 service-equipment safety stop: selected truck XML was not found.'}
        $r=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$text=$r.ReadToEnd()}finally{$r.Dispose()}

        # TEST 6.25.6: SnowRunner's selected-truck socket vocabulary is spread across Names, NamesBlock,
        # and NamesShift attributes.  Resolve all three token sets, then exact-match addon InstallSocket Type.
        # This catches alternate service/fuel addon socket routes without falling back to global filename matching.
        $socketNames=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach($m in [regex]::Matches($text,'(?i)\bNames(?:Block|Shift)?="([^"]+)"')){
            foreach($n in ($m.Groups[1].Value -split '[,;\s]+')){
                $v=$n.Trim(); if($v){[void]$socketNames.Add($v)}
            }
        }
        if($socketNames.Count -eq 0){throw 'TEST 6.25.5 service-equipment safety stop: selected truck exposes no addon Socket Names identifiers.'}

        $hits=New-Object 'System.Collections.Generic.List[string]'
        foreach($e in $zip.Entries){
            $ep=$e.FullName.Replace('/','\')
            if($ep -notmatch '(?i)\\classes\\trucks\\addons\\[^\\]+\.xml$'){continue}
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true); try{$x=$rr.ReadToEnd()}finally{$rr.Dispose()}
            if($x -notmatch '(?i)\b(?:FuelCapacity|RepairsCapacity|WheelRepairsCapacity)\s*='){continue}

            $compatible=$false
            foreach($im in [regex]::Matches($x,'(?is)<InstallSocket\b[^>]*\bType\s*=\s*"([^"]+)"[^>]*/?>')){
                foreach($t in ($im.Groups[1].Value -split '[,;\s]+')){
                    $tv=$t.Trim()
                    if($tv -and $socketNames.Contains($tv)){$compatible=$true;break}
                }
                if($compatible){break}
            }
            if($compatible){[void]$hits.Add($e.FullName)}
        }
        return @($hits)
    } finally {if($zip){$zip.Dispose()}; if($input){$input.Dispose()}}
}


function Get-FuelAddonDiagnostic([string]$PakPath,[string]$TruckEntry) {
    $input=$null; $zip=$null
    try {
        $input=[IO.File]::OpenRead($PakPath)
        $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $truck=$zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if(-not $truck){throw 'TEST 6.25.6 diagnostic safety stop: selected truck XML was not found.'}
        $r=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$text=$r.ReadToEnd()}finally{$r.Dispose()}
        $socketNames=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach($m in [regex]::Matches($text,'(?i)\bNames(?:Block|Shift)?="([^"]+)"')){
            foreach($n in ($m.Groups[1].Value -split '[,;\s]+')){ $v=$n.Trim(); if($v){[void]$socketNames.Add($v)} }
        }

        $hits=New-Object 'System.Collections.Generic.List[string]'
        $capacityRows=New-Object 'System.Collections.Generic.List[string]'
        foreach($e in $zip.Entries){
            $ep=$e.FullName.Replace('/','\')
            if($ep -notmatch '(?i)\\classes\\trucks\\addons\\[^\\]+\.xml$'){continue}
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true); try{$x=$rr.ReadToEnd()}finally{$rr.Dispose()}
            $base=[IO.Path]::GetFileNameWithoutExtension($e.Name)
            $types=@()
            foreach($im in [regex]::Matches($x,'(?is)<InstallSocket\b[^>]*\bType\s*=\s*"([^"]+)"[^>]*/?>')){
                foreach($t in ($im.Groups[1].Value -split '[,;\s]+')){if($t.Trim()){$types += $t.Trim()}}
            }
            $matched=@($types | Where-Object {$socketNames.Contains($_)} | Select-Object -Unique)
            $state=if($matched.Count){'MATCH='+($matched -join ',')}else{'UNMATCHED'}

            # Show any literal 9000/2000/1800 occurrence with local XML context. This catches non-FuelCapacity tank systems.
            if($x -match '(?i)(9000|2000|1800)'){
                foreach($m in [regex]::Matches($x,'(?is).{0,90}(?:9000|2000|1800).{0,120}')){
                    $ctx=($m.Value -replace '[\r\n\t]+',' ' -replace '\s{2,}',' ').Trim()
                    if($ctx.Length -gt 230){$ctx=$ctx.Substring(0,230)}
                    [void]$hits.Add(('  '+$base+' | '+$state+' | InstallSocket='+($types -join ',')+' | '+$ctx))
                    break
                }
            }

            # Enumerate every capacity/volume/fluid/cargo/tank-related numeric attribute so we can identify the 9000-L display source.
            $attrs=New-Object 'System.Collections.Generic.List[string]'
            foreach($am in [regex]::Matches($x,'(?i)\b([A-Za-z0-9_]*(?:Capacity|Volume|Fuel|Fluid|Cargo|Tank)[A-Za-z0-9_]*)\s*=\s*"([^"]+)"')){
                $pair=$am.Groups[1].Value+'='+$am.Groups[2].Value
                if(-not $attrs.Contains($pair)){[void]$attrs.Add($pair)}
            }
            if($attrs.Count){[void]$capacityRows.Add(('  '+$base+' | '+$state+' | '+($attrs -join '; ')))}
        }

        $o=New-Object Text.StringBuilder
        [void]$o.AppendLine('TEST 6.25.6 TANK / FLUID CAPACITY DIAGNOSTIC');[void]$o.AppendLine('')
        [void]$o.AppendLine(('Truck entry: '+$TruckEntry))
        [void]$o.AppendLine(('Selected-truck socket tokens: '+$socketNames.Count));[void]$o.AppendLine('')
        [void]$o.AppendLine('KNOWN IN-GAME US CAPACITY FINGERPRINTS:')
        [void]$o.AppendLine('  2378 gal ~= 9000 L')
        [void]$o.AppendLine('   529 gal ~= 2000 L')
        [void]$o.AppendLine('   476 gal ~= 1800 L');[void]$o.AppendLine('')
        [void]$o.AppendLine('ADDON XMLs CONTAINING LITERAL 9000 / 2000 / 1800 (with context):')
        if($hits.Count -eq 0){[void]$o.AppendLine('  (none)')} else {foreach($v in $hits | Select-Object -First 35){[void]$o.AppendLine($v)}; if($hits.Count -gt 35){[void]$o.AppendLine(('  ... '+($hits.Count-35)+' more'))}}
        [void]$o.AppendLine('');[void]$o.AppendLine('CAPACITY / VOLUME / FLUID / CARGO / TANK ATTRIBUTES (first 45 addon XMLs):')
        foreach($v in $capacityRows | Select-Object -First 45){[void]$o.AppendLine($v)}
        if($capacityRows.Count -gt 45){[void]$o.AppendLine(('  ... '+($capacityRows.Count-45)+' more'))}
        [void]$o.AppendLine('');[void]$o.AppendLine('Goal: identify the XML mechanism behind the 2378-gal Fuel Tank and distinguish service FuelCapacity from fluid/cargo tank capacity.')
        [void]$o.AppendLine('Diagnostic only. No diagnostic TXT file was written to the Desktop.')
        return $o.ToString()
    } finally { if($zip){$zip.Dispose()}; if($input){$input.Dispose()} }
}

function Get-IndividualCraneAddonEntries([string]$PakPath,[string]$TruckEntry) {
    $input=$null; $zip=$null
    try {
        $input=[IO.File]::OpenRead($PakPath)
        $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $truck=$zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if(-not $truck){throw 'TEST 6.26.2 crane safety stop: selected truck XML was not found.'}
        $r=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$text=$r.ReadToEnd()}finally{$r.Dispose()}
        $socketNames=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach($m in [regex]::Matches($text,'(?i)\bNames(?:Block|Shift)?="([^"]+)"')){
            foreach($n in ($m.Groups[1].Value -split '[,;\s]+')){$v=$n.Trim();if($v){[void]$socketNames.Add($v)}}
        }
        if($socketNames.Count -eq 0){throw 'TEST 6.26.2 crane safety stop: selected truck exposes no addon socket identifiers.'}
        $hits=New-Object 'System.Collections.Generic.List[string]'
        foreach($e in $zip.Entries){
            $ep=$e.FullName.Replace('/','\'); if($ep -notmatch '(?i)\\classes\\trucks\\addons\\[^\\]*(?:crane|loglift)[^\\]*\.xml$'){continue}
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true);try{$x=$rr.ReadToEnd()}finally{$rr.Dispose()}
            $compatible=$false
            foreach($im in [regex]::Matches($x,'(?is)<InstallSocket\b[^>]*\bType\s*=\s*"([^"]+)"[^>]*/?>')){
                foreach($t in ($im.Groups[1].Value -split '[,;\s]+')){$tv=$t.Trim();if($tv -and $socketNames.Contains($tv)){$compatible=$true;break}}
                if($compatible){break}
            }
            if($compatible){[void]$hits.Add($e.FullName)}
        }
        return @($hits)
    } finally {if($zip){$zip.Dispose()};if($input){$input.Dispose()}}
}

function Get-ControlledMechanicalConstraintNames([string]$Text) {
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach($block in [regex]::Matches($Text,'(?is)<ControlledConstraints\b[^>]*>(.*?)</ControlledConstraints>')) {
        foreach($cm in [regex]::Matches($block.Groups[1].Value,'(?is)<Constraint\b[^>]*\bBelongToCategorie="(?:crane_control|tow_control)"[^>]*/?>')) {
            $nm=[regex]::Match($cm.Value,'(?i)\bName="([^"]+)"')
            if($nm.Success -and $nm.Groups[1].Value){[void]$names.Add($nm.Groups[1].Value)}
        }
    }
    return $names
}

function Replace-ControlledConstraintMotorForce([string]$Text,[double]$Multiplier,$Counts) {
    if([math]::Abs($Multiplier-1.0) -lt 0.0000001){return $Text}
    $names=Get-ControlledMechanicalConstraintNames $Text
    if($names.Count -eq 0){return $Text}
    $edits=New-Object 'System.Collections.Generic.List[object]'
    foreach($cm in [regex]::Matches($Text,'(?is)<Constraint\b[^>]*\bName="([^"]+)"[^>]*>.*?</Constraint>')) {
        if(-not $names.Contains($cm.Groups[1].Value)){continue}
        foreach($mm in [regex]::Matches($cm.Value,'(?is)<Motor\b[^>]*\bForce="(-?(?:\d+(?:\.\d+)?|\.\d+))"[^>]*\bType="Position"[^>]*/?>')) {
            $fm=[regex]::Match($mm.Value,'(?i)\bForce="(-?(?:\d+(?:\.\d+)?|\.\d+))"')
            if(-not $fm.Success){continue}
            $old=[double]::Parse($fm.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)
            $new=Format-Number ($old*$Multiplier)
            $absolute=$cm.Index+$mm.Index+$fm.Groups[1].Index
            [void]$edits.Add([pscustomobject]@{Index=$absolute;Length=$fm.Groups[1].Length;Value=$new})
        }
    }
    for($i=$edits.Count-1;$i -ge 0;$i--){$e=$edits[$i];$Text=$Text.Remove($e.Index,$e.Length).Insert($e.Index,$e.Value)}
    if($edits.Count -gt 0){Add-Count $Counts 'Mechanical strength (controlled Position motors)' $edits.Count}
    return $Text
}

function Replace-ControlledConstraintSpeed([string]$Text,[double]$Multiplier,$Counts) {
    if([math]::Abs($Multiplier-1.0) -lt 0.0000001){return $Text}
    if($Multiplier -le 0){throw 'RC5.2 mechanical speed safety stop: speed multiplier must be greater than zero.'}

    # RC5.2 EXPERIMENTAL: ControlledConstraints without an explicit SpeedMult use the game's
    # stock/default control speed.  For crane/tow controls only, materialize that stock default
    # as SpeedMult=1 and then apply the requested multiplier. Existing SpeedMult values are still
    # multiplied in place. This is required by CAT TH357 Shaft/Fork: Crane has SpeedMult=.5,
    # while Shaft and Fork intentionally omit the attribute.
    $existing=0
    $materialized=0
    $pattern='(?is)<Constraint\b[^>]*\bBelongToCategorie="(?:crane_control|tow_control)"[^>]*/?>'
    $Text=[regex]::Replace($Text,$pattern,{param($m)
        $tag=$m.Value
        $sm=[regex]::Match($tag,'(?i)\bSpeedMult="(-?(?:\d+(?:\.\d+)?|\.\d+))"')
        if($sm.Success){
            $old=[double]::Parse($sm.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)
            $new=Format-Number ($old*$Multiplier)
            $script:RC52ExistingSpeedCount++
            return $tag.Remove($sm.Groups[1].Index,$sm.Groups[1].Length).Insert($sm.Groups[1].Index,$new)
        }
        # No SpeedMult in stock XML: default is 1.0; inject only on an already controlled
        # crane/tow Constraint. Never inject on physics Constraint/Motor elements.
        $new=Format-Number $Multiplier
        $script:RC52MaterializedSpeedCount++
        if($tag -match '/>\s*$'){ return [regex]::Replace($tag,'/>\s*$',(' SpeedMult="'+$new+'"/>')) }
        return $tag
    })
    $existing=[int]$script:RC52ExistingSpeedCount
    $materialized=[int]$script:RC52MaterializedSpeedCount
    $script:RC52ExistingSpeedCount=0
    $script:RC52MaterializedSpeedCount=0
    if($existing -gt 0){Add-Count $Counts 'Mechanical speed (existing ControlledConstraints SpeedMult)' $existing}
    if($materialized -gt 0){Add-Count $Counts 'Mechanical speed (stock-default SpeedMult materialized)' $materialized}
    return $Text
}

function Replace-CraneHingeMotorForce([string]$Text,[double]$Multiplier,$Counts) {
    if([math]::Abs($Multiplier-1.0) -lt 0.0000001){return $Text}
    $matches=[regex]::Matches($Text,'(?is)<Motor\b[^>]*/?>')
    $edits=New-Object 'System.Collections.Generic.List[object]'
    foreach($mm in $matches){
        $fm=[regex]::Match($mm.Value,'(?i)\bForce="(-?\d+(?:\.\d+)?)"')
        if(-not $fm.Success){continue}
        # Use the same nearest-context rule that produced the successful TEST 6.26.2 motor map.
        $start=[Math]::Max(0,$mm.Index-220); $len=[Math]::Min(220,$mm.Index-$start); $before=$Text.Substring($start,$len)
        $cm=[regex]::Matches($before,'(?is)<(?:Mechanism|Constraint|Body)\b[^>]*(?:Name|Type|BodyFrame|ModelFrame)="([^"]+)"[^>]*>')
        if($cm.Count -eq 0 -or $cm[$cm.Count-1].Groups[1].Value -ne 'Hinge'){continue}
        $old=[double]::Parse($fm.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)
        $new=Format-Number ($old*$Multiplier)
        $absolute=$mm.Index+$fm.Groups[1].Index
        [void]$edits.Add([pscustomobject]@{Index=$absolute;Length=$fm.Groups[1].Length;Value=$new})
    }
    for($i=$edits.Count-1;$i -ge 0;$i--){$e=$edits[$i];$Text=$Text.Remove($e.Index,$e.Length).Insert($e.Index,$e.Value)}
    if($edits.Count -gt 0){Add-Count $Counts 'Crane lifting strength (Hinge Position motors only)' $edits.Count}
    return $Text
}

function Replace-CraneMotorTau([string]$Text,[double]$Multiplier,$Counts) {
    if([math]::Abs($Multiplier-1.0) -lt 0.0000001){return $Text}
    if($Multiplier -le 0){throw 'TEST 6.26.3 crane speed safety stop: speed multiplier must be greater than zero.'}
    # Tau is motor response time. For a speed multiplier > 1, divide Tau by the multiplier.
    # IMPORTANT: only Tau attributes inside actual <Motor> tags are touched. Constraint/mechanism Tau remains stock.
    $matches=[regex]::Matches($Text,'(?is)<Motor\b[^>]*/?>')
    $edits=New-Object 'System.Collections.Generic.List[object]'
    foreach($mm in $matches){
        $tm=[regex]::Match($mm.Value,'(?i)\bTau="(-?\d+(?:\.\d+)?)"')
        if(-not $tm.Success){continue}
        $old=[double]::Parse($tm.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)
        $new=Format-Number ($old/$Multiplier)
        $absolute=$mm.Index+$tm.Groups[1].Index
        [void]$edits.Add([pscustomobject]@{Index=$absolute;Length=$tm.Groups[1].Length;Value=$new})
    }
    for($i=$edits.Count-1;$i -ge 0;$i--){$e=$edits[$i];$Text=$Text.Remove($e.Index,$e.Length).Insert($e.Index,$e.Value)}
    if($edits.Count -gt 0){Add-Count $Counts 'Crane movement speed (Motor Tau only)' $edits.Count}
    return $Text
}

function Replace-CraneControlledIKSpeed([string]$Text,[double]$Multiplier,$Counts) {
    if([math]::Abs($Multiplier-1.0) -lt 0.0000001){return $Text}
    if($Multiplier -le 0){throw 'TEST 6.26.7 crane speed safety stop: speed multiplier must be greater than zero.'}
    # TEST 6.26.7: crane end-effector movement speed is exposed on <ControlledIK>.
    # SnowRunner crane XML commonly uses leading-decimal values such as .65/.5/.8/.6.
    # Accept both normal decimals (1.0) and leading decimals (.65) so ALL compatible cranes are reached.
    # Do NOT touch Motor Tau, Force, Constraint SpeedMult, or any other physics/control value here.
    $tags=[regex]::Matches($Text,'(?is)<ControlledIK\b[^>]*>')
    $edits=New-Object 'System.Collections.Generic.List[object]'
    foreach($tag in $tags){
        foreach($am in [regex]::Matches($tag.Value,'(?i)\b(CoeffEndMovementSpeed[A-Za-z0-9_]*)="(-?(?:\d+(?:\.\d+)?|\.\d+))"')){
            $old=[double]::Parse($am.Groups[2].Value,[Globalization.CultureInfo]::InvariantCulture)
            $new=Format-Number ($old*$Multiplier)
            $absolute=$tag.Index+$am.Groups[2].Index
            [void]$edits.Add([pscustomobject]@{Index=$absolute;Length=$am.Groups[2].Length;Value=$new})
        }
    }
    for($i=$edits.Count-1;$i -ge 0;$i--){$e=$edits[$i];$Text=$Text.Remove($e.Index,$e.Length).Insert($e.Index,$e.Value)}
    if($edits.Count -gt 0){Add-Count $Counts 'Crane movement speed (ControlledIK coefficients only)' $edits.Count}
    return $Text
}

function Get-CraneMotorDiagnostic([string]$PakPath,[string]$TruckEntry) {
    $input=$null; $zip=$null
    try {
        $input=[IO.File]::OpenRead($PakPath)
        $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $truck=$zip.Entries | Where-Object { $_.FullName.Replace('/','\').Equals($TruckEntry.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if(-not $truck){throw 'TEST 6.26.2 crane diagnostic safety stop: selected truck XML was not found.'}
        $r=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$text=$r.ReadToEnd()}finally{$r.Dispose()}
        $socketNames=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach($m in [regex]::Matches($text,'(?i)\bNames(?:Block|Shift)?="([^"]+)"')){
            foreach($n in ($m.Groups[1].Value -split '[,;\s]+')){$v=$n.Trim();if($v){[void]$socketNames.Add($v)}}
        }
        $rows=New-Object 'System.Collections.Generic.List[string]'; $cranes=0; $motors=0
        foreach($e in $zip.Entries){
            $ep=$e.FullName.Replace('/','\'); if($ep -notmatch '(?i)\\classes\\trucks\\addons\\[^\\]*(?:crane|loglift)[^\\]*\.xml$'){continue}
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true);try{$x=$rr.ReadToEnd()}finally{$rr.Dispose()}
            $compatible=$false; $install=@()
            foreach($im in [regex]::Matches($x,'(?is)<InstallSocket\b[^>]*\bType\s*=\s*"([^"]+)"[^>]*/?>')){
                foreach($t in ($im.Groups[1].Value -split '[,;\s]+')){$tv=$t.Trim();if($tv){$install+=$tv;if($socketNames.Contains($tv)){$compatible=$true}}}
            }
            if(-not $compatible){continue}; $cranes++
            [void]$rows.Add(('=== '+[IO.Path]::GetFileNameWithoutExtension($e.Name)+' | InstallSocket='+($install -join ',')+' ==='))
            $idx=0
            foreach($mm in [regex]::Matches($x,'(?is)<Motor\b[^>]*/?>')){
                $idx++;$motors++;$tag=$mm.Value
                $attrs=@();foreach($a in @('Name','Type','Force','Tau','MinLimit','MaxLimit','MotorForce','AngVel','Speed','Spring','Damping')){$am=[regex]::Match($tag,('(?i)\b'+$a+'="([^"]+)"'));if($am.Success){$attrs+=($a+'='+$am.Groups[1].Value)}}
                $start=[Math]::Max(0,$mm.Index-220);$len=[Math]::Min(220,$mm.Index-$start);$before=$x.Substring($start,$len)
                $ctx='';$cm=[regex]::Matches($before,'(?is)<(?:Mechanism|Constraint|Body)\b[^>]*(?:Name|Type|BodyFrame|ModelFrame)="([^"]+)"[^>]*>');if($cm.Count -gt 0){$ctx=$cm[$cm.Count-1].Groups[1].Value}
                [void]$rows.Add(('  Motor '+$idx+($(if($ctx){' | context='+$ctx}else{''}))+' | '+($attrs -join ' | ')))
            }
        }
        $o=New-Object Text.StringBuilder
        [void]$o.AppendLine('TEST 6.26.2 CRANE MOTOR DIAGNOSTIC');[void]$o.AppendLine('')
        [void]$o.AppendLine(('Truck entry: '+$TruckEntry));[void]$o.AppendLine(('Selected-truck socket tokens: '+$socketNames.Count));[void]$o.AppendLine(('Compatible crane/loglift XMLs: '+$cranes));[void]$o.AppendLine(('Motor tags mapped: '+$motors));[void]$o.AppendLine('')
        [void]$o.AppendLine('COMPATIBLE CRANE MOTOR MAP:');foreach($v in $rows | Select-Object -First 95){[void]$o.AppendLine($v)};if($rows.Count -gt 95){[void]$o.AppendLine(('... '+($rows.Count-95)+' more rows'))}
        [void]$o.AppendLine('');[void]$o.AppendLine('Diagnostic only: TEST 6.26 broad Motor Force/Tau editing is NOT active here.');[void]$o.AppendLine('No diagnostic TXT file was written to the Desktop.')
        return $o.ToString()
    } finally {if($zip){$zip.Dispose()};if($input){$input.Dispose()}}
}

function Get-CraneSpeedDiagnostic([string]$PakPath,[string]$TruckEntry) {
    $input=$null; $zip=$null
    try {
        $entries=@(Get-IndividualCraneAddonEntries $PakPath $TruckEntry)
        $wanted=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach($v in $entries){[void]$wanted.Add($v.Replace('/','\'))}
        $input=[IO.File]::OpenRead($PakPath)
        $zip=New-Object IO.Compression.ZipArchive($input,[IO.Compression.ZipArchiveMode]::Read)
        $rows=New-Object 'System.Collections.Generic.List[string]'
        $cranes=0; $motors=0; $candidateTags=0
        foreach($e in $zip.Entries){
            $ep=$e.FullName.Replace('/','\'); if(-not $wanted.Contains($ep)){continue}
            $cranes++
            $rr=New-Object IO.StreamReader($e.Open(),[Text.Encoding]::UTF8,$true);try{$x=$rr.ReadToEnd()}finally{$rr.Dispose()}
            [void]$rows.Add(('=== '+[IO.Path]::GetFileNameWithoutExtension($e.Name)+' ==='))
            $idx=0
            foreach($mm in [regex]::Matches($x,'(?is)<Motor\b[^>]*/?>')){
                $idx++;$motors++;$tag=$mm.Value
                $attrs=New-Object 'System.Collections.Generic.List[string]'
                foreach($am in [regex]::Matches($tag,'(?i)\b([A-Za-z_][A-Za-z0-9_]*)="([^"]*)"')){[void]$attrs.Add(($am.Groups[1].Value+'='+$am.Groups[2].Value))}
                $start=[Math]::Max(0,$mm.Index-320);$len=[Math]::Min(320,$mm.Index-$start);$before=$x.Substring($start,$len)
                $ctx='';$cm=[regex]::Matches($before,'(?is)<(?:Mechanism|Constraint|Body)\b[^>]*(?:Name|Type|BodyFrame|ModelFrame)="([^"]+)"[^>]*>');if($cm.Count -gt 0){$ctx=$cm[$cm.Count-1].Groups[1].Value}
                [void]$rows.Add(('  Motor '+$idx+($(if($ctx){' | context='+$ctx}else{''}))+' | '+($attrs -join ' | ')))
            }
            [void]$rows.Add('  SPEED/RATE/VELOCITY CANDIDATE TAGS:')
            $local=0
            foreach($tm in [regex]::Matches($x,'(?is)<[A-Za-z_][A-Za-z0-9_]*\b[^>]*(?:Speed|Velocity|Vel|Rate|Tau|Time|Force|Damping|Spring|Limit)[^>]*>')){
                $tag=($tm.Value -replace '\s+',' ').Trim()
                if($tag.Length -gt 300){$tag=$tag.Substring(0,300)+'...'}
                [void]$rows.Add(('    '+$tag));$local++;$candidateTags++
                if($local -ge 24){break}
            }
            if($local -eq 0){[void]$rows.Add('    (none found)')}
        }
        $o=New-Object Text.StringBuilder
        [void]$o.AppendLine('TEST 6.26.4 CRANE SPEED DIAGNOSTIC');[void]$o.AppendLine('')
        [void]$o.AppendLine(('Truck entry: '+$TruckEntry));[void]$o.AppendLine(('Compatible crane/loglift XMLs: '+$cranes));[void]$o.AppendLine(('Motor tags mapped: '+$motors));[void]$o.AppendLine(('Speed/rate/velocity candidate tags sampled: '+$candidateTags));[void]$o.AppendLine('')
        [void]$o.AppendLine('FULL MOTOR ATTRIBUTES + NEARBY SPEED/RATE/VELOCITY CANDIDATES:')
        foreach($v in $rows | Select-Object -First 180){[void]$o.AppendLine($v)}
        if($rows.Count -gt 180){[void]$o.AppendLine(('... '+($rows.Count-180)+' more rows'))}
        [void]$o.AppendLine('');[void]$o.AppendLine('Diagnostic only: Crane Speed makes NO XML edits in TEST 6.26.4. Proven hinge-only Crane Strength remains intact.')
        [void]$o.AppendLine('No diagnostic TXT file was written to the Desktop.')
        return $o.ToString()
    } finally {if($zip){$zip.Dispose()};if($input){$input.Dispose()}}
}

function Process-Pak($S, [bool]$WriteOutput) {
    if ($S.TargetTruck -and $S.TargetTruck -ne 'All Trucks' -and -not $S.TargetTruckId) {
        throw 'TEST 6.9 safety stop: individual-truck mode has no resolved internal truck ID. No modifications were made.'
    }
    Assert-Pak $S.PakPath $true
    $pak = [IO.Path]::GetFullPath($S.PakPath)
    $compat = Test-PakCompatibility $pak
    $backup = Initialize-Backup $pak
    Assert-Pak $backup
    # RC3.8.1 cumulative Individual Apply:
    # - The trusted original backup remains immutable and is used only as the clean baseline/Restore source.
    # - Individual truck Preview/Apply starts from the CURRENT live initial.pak so previously applied
    #   individual trucks remain modified when another truck is applied.
    # - All Trucks mode intentionally continues to rebuild from the untouched original baseline.
    # Initialize-Backup's LastEditorOutputHash record distinguishes our current modified PAK from a
    # genuine SnowRunner/Epic update, preventing an editor-modified PAK from being promoted to backup.
    $sourcePath = if ($S.TargetTruckId) { $pak } else { $backup }
    Assert-Pak $sourcePath
    if ($S.TargetTruckId) {
        $S.TargetTruckEntry = Resolve-OfficialTruckEntryPath $sourcePath ([string]$S.TargetTruckId)
        $S.IndividualServiceAddonEntries = @(Get-IndividualServiceAddonEntries $sourcePath ([string]$S.TargetTruckEntry))
        if(([math]::Abs([double]$S.CraneStrength-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.CraneSpeed-1.0) -ge 0.0000001)){ $S.IndividualCraneAddonEntries = @(Get-IndividualCraneAddonEntries $sourcePath ([string]$S.TargetTruckEntry)) }
        if ($S.TestStockWheelSwap) {
            if(([string]$S.TargetTruckId).ToLowerInvariant() -ne 'freightliner_114sd'){throw 'TEST 6.18 safety stop: select Freightliner 114SD for this controlled experiment.'}
            $testType='wheels_medium_highway_double'
            $fs=[IO.File]::OpenRead($sourcePath); $zz=New-Object IO.Compression.ZipArchive($fs,[IO.Compression.ZipArchiveMode]::Read)
            try {
                $truck=$zz.Entries | Where-Object { $_.FullName.Replace('\','/').Equals(([string]$S.TargetTruckEntry).Replace('\','/'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
                $rr=New-Object IO.StreamReader($truck.Open(),[Text.Encoding]::UTF8,$true); try{$tx=$rr.ReadToEnd()}finally{$rr.Dispose()}
                if(-not [regex]::IsMatch($tx,('(?is)<CompatibleWheels\b[^>]*\bType\s*=\s*["'']'+[regex]::Escape($testType)+'["'']'))){throw "TEST 6.18 safety stop: 114SD does not declare '$testType' as CompatibleWheels."}
                $fam=$zz.Entries | Where-Object { $_.FullName.Replace('\','/').ToLowerInvariant().EndsWith(('/classes/wheels/'+$testType.ToLowerInvariant()+'.xml'),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
                if(-not $fam){throw "TEST 6.18 safety stop: recognized stock family '$testType' was not found."}
                $rr=New-Object IO.StreamReader($fam.Open(),[Text.Encoding]::UTF8,$true); try{$fx=$rr.ReadToEnd()}finally{$rr.Dispose()}
                $tm=[regex]::Match($fx,'(?is)<TruckTire\b[^>]*\bName\s*=\s*"([^"]+)"')
                if(-not $tm.Success){throw "TEST 6.18 safety stop: '$testType' contains no named TruckTire."}
                $S.TestStockWheelSwapType=$testType
                $S.TestStockWheelSwapTire=$tm.Groups[1].Value
            } finally {if($zz){$zz.Dispose()};if($fs){$fs.Dispose()}}
        }
        $engineChange = ([math]::Abs([double]$S.EngineTorque-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.EngineResponse-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.EngineFuel-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.EngineDurability-1.0) -ge 0.0000001)
        if ($engineChange) {
            $enginePlan = Get-IndividualEnginePlan $sourcePath ([string]$S.TargetTruckEntry) ([string]$S.TargetTruckId)
            $S.IndividualEngineSourceEntries = @($enginePlan.SourceEntries)
            $S.IndividualEngineSourceEntry = if($S.IndividualEngineSourceEntries.Count -gt 0){[string]$S.IndividualEngineSourceEntries[0]}else{''}
            $S.IndividualEngineDefault = [string]$enginePlan.Default
            $S.IndividualEngineTypes = @($enginePlan.Types)
            $S.IndividualEngineType = if($S.IndividualEngineTypes.Count -gt 0){[string]$S.IndividualEngineTypes[0]}else{''}
            $S.IndividualEnginePrivateName = ''
            $S.SharedEngineType = ($S.IndividualEngineTypes -join ', ')
            # Engine edits are intentionally in-place. Count base trucks that use the same
            # engine family so Preview/Apply can clearly disclose the shared scope.
            $fsE=[IO.File]::OpenRead($sourcePath); $zzE=New-Object IO.Compression.ZipArchive($fsE,[IO.Compression.ZipArchiveMode]::Read)
            try {
                $users=0
                foreach($te in $zzE.Entries){
                    $nn=$te.FullName.Replace('/','\').ToLowerInvariant()
                    if($nn -notmatch '\\classes\\trucks\\[^\\]+\.xml$'){continue}
                    $rE=New-Object IO.StreamReader($te.Open(),[Text.Encoding]::UTF8,$true); try{$xt=$rE.ReadToEnd()}finally{$rE.Dispose()}
                    $usesFamily=$false
                    $sm=[regex]::Match($xt,'(?is)<EngineSocket\b[^>]*\bType="([^"]+)"')
                    if($sm.Success){$decl=@($sm.Groups[1].Value -split '\s*,\s*' | ForEach-Object {$_.Trim()}); foreach($et in @($S.IndividualEngineTypes)){if($decl -contains [string]$et){$usesFamily=$true;break}}}
                    if($usesFamily){$users++}
                }
                $S.SharedEngineTruckUsers=$users
            } finally {if($zzE){$zzE.Dispose()};if($fsE){$fsE.Dispose()}}
        }
        $gearboxChange = ([math]::Abs([double]$S.GearSpeed-1.0)-ge 0.0000001) -or ([math]::Abs([double]$S.GearboxFuel-1.0)-ge 0.0000001) -or ([math]::Abs([double]$S.AwdFuel-1.0)-ge 0.0000001) -or ([math]::Abs([double]$S.IdleFuel-1.0)-ge 0.0000001) -or ([math]::Abs([double]$S.GearboxDurability-1.0)-ge 0.0000001)
        if ($gearboxChange) {
            $gearPlan = Get-IndividualGearboxPlan $sourcePath ([string]$S.TargetTruckEntry) ([string]$S.TargetTruckId)
            $S.IndividualGearboxSourceEntry=[string]$gearPlan.SourceEntry
            $S.IndividualGearboxDefault=[string]$gearPlan.Default
            $S.IndividualGearboxType=[string]$gearPlan.Type
            $S.IndividualGearboxPrivateName=''
            $S.SharedGearboxType=[string]$gearPlan.Type
            $S.SharedGearboxDefault=[string]$gearPlan.Default
            # TEST 6.23.1: edit the existing/default gearbox variant in place. Count base
            # trucks that reference this exact Type+Default so Preview discloses scope.
            $fsG=[IO.File]::OpenRead($sourcePath); $zzG=New-Object IO.Compression.ZipArchive($fsG,[IO.Compression.ZipArchiveMode]::Read)
            try {
                $users=0
                foreach($te in $zzG.Entries){
                    $nn=$te.FullName.Replace('/','\').ToLowerInvariant()
                    if($nn -notmatch '\\classes\\trucks\\[^\\]+\.xml$'){continue}
                    $rG=New-Object IO.StreamReader($te.Open(),[Text.Encoding]::UTF8,$true); try{$xt=$rG.ReadToEnd()}finally{$rG.Dispose()}
                    $pat='(?is)<GearboxSocket\b(?=[^>]*\bType="'+[regex]::Escape([string]$S.SharedGearboxType)+'")(?=[^>]*\bDefault="'+[regex]::Escape([string]$S.SharedGearboxDefault)+'")[^>]*/?>'
                    if([regex]::IsMatch($xt,$pat)){$users++}
                }
                $S.SharedGearboxTruckUsers=$users
            } finally {if($zzG){$zzG.Dispose()};if($fsG){$fsG.Dispose()}}
        }
        $tireChange = ([math]::Abs([double]$S.TireAsphalt-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.TireOffroad-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.TireMud-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.TireDurability-1.0) -ge 0.0000001)
        if ($tireChange) {
            # TEST 6.18.1: tires deliberately edit the existing shared stock wheel family in-place.
            # Never prepare, clone, repoint, or invent wheel/tire identifiers here.
            $S.IndividualWheelSourceEntry=''
            $S.IndividualWheelType=''
            $S.IndividualWheelPrivateType=''
            $S.IndividualWheelPrivateEntry=''
            $tirePlan=Get-IndividualTirePlan $sourcePath ([string]$S.TargetTruckEntry) ([string]$S.TargetTruckId)
            $S.SharedWheelSourceEntry=[string]$tirePlan.SourceEntry
            $S.SharedWheelType=[string]$tirePlan.WheelType
            # Count base trucks whose DefaultWheelType uses this same family. This is informational only.
            $fs2=[IO.File]::OpenRead($sourcePath); $zz2=New-Object IO.Compression.ZipArchive($fs2,[IO.Compression.ZipArchiveMode]::Read)
            try {
                $users=0
                foreach($te in $zz2.Entries){
                    $nn=$te.FullName.Replace('/','\').ToLowerInvariant()
                    if($nn -notmatch '\\classes\\trucks\\[^\\]+\.xml$'){continue}
                    $r2=New-Object IO.StreamReader($te.Open(),[Text.Encoding]::UTF8,$true); try{$xt=$r2.ReadToEnd()}finally{$r2.Dispose()}
                    if([regex]::IsMatch($xt,('(?is)<Wheels\b[^>]*\bDefaultWheelType="'+[regex]::Escape([string]$S.SharedWheelType)+'"'))){$users++}
                }
                $S.SharedWheelTruckUsers=$users
            } finally {if($zz2){$zz2.Dispose()};if($fs2){$fs2.Dispose()}}
        }
        $suspChange = ([math]::Abs([double]$S.SuspensionStrength-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.SuspensionHeight-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.SuspensionDamping-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.SuspensionDurability-1.0) -ge 0.0000001)
        if($suspChange){
            $sp=Get-IndividualSuspensionPlan $sourcePath ([string]$S.TargetTruckEntry) ([string]$S.TargetTruckId)
            $S.CompatibleSuspensionFamilies=[object[]]@($sp.Families)
            $S.CompatibleSuspensionTypes=[string[]]@($sp.Types)
            $fs3=[IO.File]::OpenRead($sourcePath); $zz3=New-Object IO.Compression.ZipArchive($fs3,[IO.Compression.ZipArchiveMode]::Read)
            try {
                $users=0
                foreach($te in $zz3.Entries){
                    $nn=$te.FullName.Replace('/','\').ToLowerInvariant()
                    if($nn -notmatch '\\classes\\trucks\\[^\\]+\.xml$'){continue}
                    $r3=New-Object IO.StreamReader($te.Open(),[Text.Encoding]::UTF8,$true); try{$xt=$r3.ReadToEnd()}finally{$r3.Dispose()}
                    $tm=[regex]::Match($xt,'(?is)<SuspensionSocket\b[^>]*\bType="([^"]+)"')
                    if(-not $tm.Success){continue}
                    $tt=@($tm.Groups[1].Value -split '[,;\s]+' | ForEach-Object {$_.Trim()} | Where-Object {$_})
                    if(@($tt | Where-Object {$S.CompatibleSuspensionTypes -contains $_}).Count -gt 0){$users++}
                }
                $S.SharedSuspensionTruckUsers=$users
            } finally {if($zz3){$zz3.Dispose()};if($fs3){$fs3.Dispose()}}
        }
        $winchChange = ([math]::Abs([double]$S.WinchStrength-1.0) -ge 0.0000001) -or ([math]::Abs([double]$S.WinchLength-1.0) -ge 0.0000001) -or [bool]$S.AutonomousWinches
        if($winchChange){
            $wp=Get-IndividualWinchPlan $sourcePath ([string]$S.TargetTruckEntry) ([string]$S.TargetTruckId)
            $S.SharedWinchSourceEntry=[string]$wp.SourceEntry
            $S.SharedWinchType=[string]$wp.Type
            $fs4=[IO.File]::OpenRead($sourcePath); $zz4=New-Object IO.Compression.ZipArchive($fs4,[IO.Compression.ZipArchiveMode]::Read)
            try {
                $users=0
                foreach($te in $zz4.Entries){
                    $nn=$te.FullName.Replace('/','\').ToLowerInvariant()
                    if($nn -notmatch '\\classes\\trucks\\[^\\]+\.xml$'){continue}
                    $r4=New-Object IO.StreamReader($te.Open(),[Text.Encoding]::UTF8,$true); try{$xt=$r4.ReadToEnd()}finally{$r4.Dispose()}
                    if([regex]::IsMatch($xt,('(?is)<WinchUpgradeSocket\b[^>]*\bType="'+[regex]::Escape([string]$S.SharedWinchType)+'"'))){$users++}
                }
                $S.SharedWinchTruckUsers=$users
            } finally {if($zz4){$zz4.Dispose()};if($fs4){$fs4.Dispose()}}
        }
    }
    $counts = @{}
    $modifiedFiles = 0
    $tempPath = $null
    $input = $null
    $output = $null
    $sourceZip = $null
    $targetZip = $null
    try {
        $input = [IO.File]::OpenRead($sourcePath)
        $sourceZip = New-Object IO.Compression.ZipArchive($input, [IO.Compression.ZipArchiveMode]::Read)
        if ($WriteOutput) {
            $tempPath = Join-Path ([IO.Path]::GetDirectoryName($pak)) ('initial.editor.' + [guid]::NewGuid().ToString('N') + '.tmp')
            $output = [IO.File]::Create($tempPath)
            $targetZip = New-Object IO.Compression.ZipArchive($output, [IO.Compression.ZipArchiveMode]::Create)
        }
        $utf8 = New-Object Text.UTF8Encoding($false)
        foreach ($entry in $sourceZip.Entries) {
            $isXml = $entry.FullName.EndsWith('.xml', [StringComparison]::OrdinalIgnoreCase)
            $bytes = $null
            $newText = $null
            $changed = $false
            $entryStream = $entry.Open()
            try {
                $memory = New-Object IO.MemoryStream
                $entryStream.CopyTo($memory)
                $bytes = $memory.ToArray()
                $memory.Dispose()
            } finally { $entryStream.Dispose() }
            if ($isXml) {
                $text = $utf8.GetString($bytes)
                $originalText = $text
                # RC3.9.9: SnowRunner tire grip has two data layers that must stay in sync.
                # 1) [media]/_templates/trucks.xml contains the shared WheelFriction templates.
                # 2) [media]/classes/wheels/*.xml contains wheel/tire-specific friction overrides.
                # Modify ONLY friction attributes that already exist; never inject missing attributes,
                # never change wheel IDs/templates/default tire identities.  The wheel-class layer is
                # still handled by the existing All Trucks / selected compatible-family paths below.
                $entryNorm = $entry.FullName.Replace('\','/').ToLowerInvariant()
                $tireGripRequested = ([math]::Abs([double]$S.TireAsphalt - 1.0) -ge 0.0000001 -or
                                      [math]::Abs([double]$S.TireOffroad - 1.0) -ge 0.0000001 -or
                                      [math]::Abs([double]$S.TireMud - 1.0) -ge 0.0000001)
                if ($tireGripRequested -and $entryNorm -match '(^|/)_templates/trucks\.xml$') {
                    $newText = Replace-NumericAttribute $text 'BodyFrictionAsphalt' $S.TireAsphalt $counts 'Tire asphalt grip (trucks.xml templates)'
                    $newText = Replace-NumericAttribute $newText 'BodyFriction' $S.TireOffroad $counts 'Tire off-road grip (trucks.xml templates)'
                    $newText = Replace-NumericAttribute $newText 'SubstanceFriction' $S.TireMud $counts 'Tire mud grip (trucks.xml templates)'
                } elseif ($S.TargetTruckId -and $S.SharedWinchSourceEntry -and $entry.FullName.Replace('/', '\').Equals(([string]$S.SharedWinchSourceEntry).Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase)) {
                    $newText = Replace-NumericAttribute $text 'StrengthMult' $S.WinchStrength $counts 'Winch strength (component family)'
                    $newText = Replace-NumericAttribute $newText 'Length' $S.WinchLength $counts 'Winch length (component family)'
                    if($S.AutonomousWinches){
                        $n=0
                        $newText=[regex]::Replace($newText,'(?i)IsEngineIgnitionRequired="true"',{param($m) $script:n=$script:n+1; 'IsEngineIgnitionRequired="false"'})
                        if($script:n){ Add-Count $counts 'Autonomous winches (component family)' $script:n }; $script:n=0
                    }
                    if($newText -cne $text){ Add-Count $counts ('Winch family '+[string]$S.SharedWinchType+' - base trucks using family') ([int]$S.SharedWinchTruckUsers) }
                } elseif ($S.TargetTruckId -and $S.CompatibleSuspensionFamilies -and (@($S.CompatibleSuspensionFamilies | ForEach-Object { ([string]$_.SourceEntry).Replace('\','/').ToLowerInvariant() }) -contains $entry.FullName.Replace('\','/').ToLowerInvariant())) {
                    $sf=@($S.CompatibleSuspensionFamilies | Where-Object { ([string]$_.SourceEntry).Replace('\','/').Equals($entry.FullName.Replace('\','/'),[StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
                    $newText = Replace-SuspensionTravelAttribute $text 'Strength' $S.SuspensionStrength $counts 'Suspension strength (all compatible suspension variants)'
                    $newText = Replace-NumericAttribute $newText 'Height' $S.SuspensionHeight $counts 'Suspension height (all compatible suspension variants)'
                    $newText = Replace-SuspensionTravelAttribute $newText 'Damping' $S.SuspensionDamping $counts 'Suspension damping (all compatible suspension variants)'
                    $newText = Replace-NumericAttribute $newText 'DamageCapacity' $S.SuspensionDurability $counts 'Suspension durability (all compatible suspension variants)'
                    if($newText -cne $text){
                        Add-Count $counts ('Compatible suspension variants - family '+[string]$sf.Type) ([int]$sf.VariantCount)
                        Add-Count $counts ('SHARED compatible suspension families - base trucks using one or more') ([int]$S.SharedSuspensionTruckUsers)
                    }
                } elseif ($S.TargetTruckId -and $S.SharedWheelSourceEntry -and $entry.FullName.Replace('/', '\').Equals(([string]$S.SharedWheelSourceEntry).Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase)) {
                    $newText = Replace-NumericAttribute $text 'BodyFrictionAsphalt' $S.TireAsphalt $counts 'Tire asphalt grip (shared wheel family)'
                    $newText = Replace-NumericAttribute $newText 'BodyFriction' $S.TireOffroad $counts 'Tire off-road grip (shared wheel family)'
                    $newText = Replace-NumericAttribute $newText 'SubstanceFriction' $S.TireMud $counts 'Tire mud grip (shared wheel family)'
                    $newText = Replace-NumericAttribute $newText 'DamageCapacity' $S.TireDurability $counts 'Tire durability (shared wheel family)'
                    if($newText -cne $text){
                        Add-Count $counts ('SHARED wheel family '+[string]$S.SharedWheelType+' - base trucks using as default') ([int]$S.SharedWheelTruckUsers)
                    }
                } elseif ($S.TargetTruckId -and @($S.IndividualCraneAddonEntries | ForEach-Object { $_.Replace('\','/').ToLowerInvariant() }) -contains $entry.FullName.Replace('\','/').ToLowerInvariant()) {
                    # TEST 6.26.7: preserve proven hinge-only strength. Crane speed uses ControlledIK end-movement coefficients, including leading-decimal values.
                    # Motor Tau, prismatic/hinge Force (unless Strength changes), Constraint SpeedMult, and springs remain untouched.
                    $newText = Replace-CraneHingeMotorForce $text ([double]$S.CraneStrength) $counts
                    $newText = Replace-CraneControlledIKSpeed $newText ([double]$S.CraneSpeed) $counts
                } elseif ($S.TargetTruckId -and $S.IndividualServiceAddonEntries -contains $entry.FullName) {
                    # TEST 6.25.7: selected-truck compatible service addons can store fuel in two places:
                    # ordinary addon FuelCapacity and nested <TruckData FuelCapacity="..."> tank data.
                    # Keep exact selected-truck socket targeting; do not broaden to unrelated addons.
                    $newText=$text
                    if([math]::Abs([double]$S.ServiceFuel-1.0) -ge 0.0000001){
                        $mult=[double]$S.ServiceFuel
                        $truckDataPattern='(?is)(<TruckData\b[^>]*?\bFuelCapacity=")(-?\d+(?:\.\d+)?)(")'
                        $tdn=[regex]::Matches($newText,$truckDataPattern).Count
                        if($tdn -gt 0){
                            $newText=[regex]::Replace($newText,$truckDataPattern,{param($m)
                                $v=[double]::Parse($m.Groups[2].Value,[Globalization.CultureInfo]::InvariantCulture)
                                $m.Groups[1].Value + (Format-Number ($v*$mult)) + $m.Groups[3].Value
                            })
                            Add-Count $counts 'Service fuel capacity (compatible nested TruckData tanks)' $tdn
                        }
                        # Modify remaining FuelCapacity attributes, excluding those already handled inside TruckData tags,
                        # so nested tanks are not multiplied twice.
                        $fuelPattern='(?is)(<(?!TruckData\b)[^>]+?\bFuelCapacity=")(-?\d+(?:\.\d+)?)(")'
                        $fn=[regex]::Matches($newText,$fuelPattern).Count
                        if($fn -gt 0){
                            $newText=[regex]::Replace($newText,$fuelPattern,{param($m)
                                $v=[double]::Parse($m.Groups[2].Value,[Globalization.CultureInfo]::InvariantCulture)
                                $m.Groups[1].Value + (Format-Number ($v*$mult)) + $m.Groups[3].Value
                            })
                            Add-Count $counts 'Service fuel capacity (selected-truck compatible addons)' $fn
                        }
                    }
                    $newText=Replace-NumericAttribute $newText 'RepairsCapacity' $S.ServiceRepairs $counts 'Service repair points (selected-truck compatible addons)'
                    $newText=Replace-NumericAttribute $newText 'WheelRepairsCapacity' $S.ServiceWheels $counts 'Service spare wheels (selected-truck compatible addons)'
                    if($newText -cne $text){ Add-Count $counts 'Selected-truck compatible service addon XMLs affected' 1 }
                } elseif ($S.TargetTruckId -and @($S.IndividualEngineSourceEntries).Count -gt 0 -and (@($S.IndividualEngineSourceEntries | ForEach-Object {$_.Replace('/', '\')}) -contains $entry.FullName.Replace('/', '\'))) {
                    # RC3.6: modify EVERY named engine variant in every engine family declared compatible
                    # by the selected truck's EngineSocket Type. Identifiers remain untouched.
                    $familyType=''
                    for($ei=0;$ei -lt @($S.IndividualEngineSourceEntries).Count;$ei++){
                        if(([string]$S.IndividualEngineSourceEntries[$ei]).Replace('/','\').Equals($entry.FullName.Replace('/','\'),[StringComparison]::OrdinalIgnoreCase)){$familyType=[string]$S.IndividualEngineTypes[$ei];break}
                    }
                    $pattern='(?is)<Engine\b(?=[^>]*\bName="[^"]+")[^>]*>.*?</Engine>'
                    $ms=[regex]::Matches($text,$pattern)
                    if($ms.Count -lt 1){throw "RC3.6 engine safety stop: compatible family '$familyType' contains no named engine variants."}
                    $sb=New-Object Text.StringBuilder; $pos=0; $changedVariants=0
                    foreach($em in $ms){
                        [void]$sb.Append($text.Substring($pos,$em.Index-$pos)); $block=$em.Value; $mod=$block
                        $mod=Replace-NumericAttribute $mod 'Torque' $S.EngineTorque $counts 'Engine torque (all compatible engine variants)'
                        $mod=Replace-NumericAttribute $mod 'EngineResponsiveness' $S.EngineResponse $counts 'Engine responsiveness (all compatible engine variants)'
                        $mod=Replace-NumericAttribute $mod 'FuelConsumption' $S.EngineFuel $counts 'Engine fuel consumption (all compatible engine variants)'
                        $mod=Replace-NumericAttribute $mod 'DamageCapacity' $S.EngineDurability $counts 'Engine durability (all compatible engine variants)'
                        if([math]::Abs([double]$S.EngineResponse-1.0) -ge 0.0000001 -and -not [regex]::IsMatch($mod,'(?i)\bEngineResponsiveness="[^"]+"')){
                            $baseResponse=0.04; $tm=[regex]::Match($block,'(?i)\b_template="([^"]+)"')
                            if($tm.Success){$tn=[regex]::Escape($tm.Groups[1].Value);$tt=[regex]::Match($text,('(?is)<' + $tn + '\b[^>]*>'));if(-not $tt.Success){$tt=[regex]::Match($text,('(?is)<' + $tn + '\b[^>]*/>'))};if($tt.Success){$rm=[regex]::Match($tt.Value,'(?i)\bEngineResponsiveness="([0-9eE+\-.]+)"');if($rm.Success){$baseResponse=[double]::Parse($rm.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)}}}
                            $v=$baseResponse*[double]$S.EngineResponse;if($v -gt 1){$v=1};if($v -lt .01){$v=.01};$fmt=$v.ToString('0.######',[Globalization.CultureInfo]::InvariantCulture)
                            $op=[regex]::Match($mod,'(?is)<Engine\b[^>]*>');if(-not $op.Success){throw 'RC3.6 engine responsiveness safety stop.'};$nop=$op.Value.Insert($op.Value.Length-1,(' EngineResponsiveness="'+$fmt+'"'));$mod=$mod.Substring(0,$op.Index)+$nop+$mod.Substring($op.Index+$op.Length);Add-Count $counts 'Engine responsiveness (all compatible engine variants)' 1
                        }
                        if($mod -cne $block){$changedVariants++};[void]$sb.Append($mod);$pos=$em.Index+$em.Length
                    }
                    [void]$sb.Append($text.Substring($pos));$newText=$sb.ToString()
                    if($newText -cne $text){Add-Count $counts ('Compatible engine variants modified - family '+$familyType) $changedVariants; Add-Count $counts ('SHARED compatible engine families - base trucks using one or more') ([int]$S.SharedEngineTruckUsers)}
                } elseif ($S.TargetTruckId -and $S.IndividualGearboxSourceEntry -and $entry.FullName.Replace('/', '\').Equals(([string]$S.IndividualGearboxSourceEntry).Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase)) {
                    # TEST 6.25: permanent individual gearbox path uses the same attribute transformations as
                    # working All Trucks mode to the ENTIRE resolved stock gearbox family XML.
                    # This is intentionally a shared-family test: no cloning, renaming, or socket repointing.
                    $mod=$text
                    if([math]::Abs([double]$S.GearboxFuel-1.0)-ge 0.0000001){$mod=Replace-NumericAttribute $mod 'FuelConsumption' $S.GearboxFuel $counts 'Gearbox fuel consumption (shared gearbox family)'}
                    if([math]::Abs([double]$S.AwdFuel-1.0)-ge 0.0000001){$mod=Replace-NumericAttribute $mod 'AWDConsumptionModifier' $S.AwdFuel $counts 'AWD fuel penalty (shared gearbox family)'}
                    if([math]::Abs([double]$S.IdleFuel-1.0)-ge 0.0000001){$mod=Replace-NumericAttribute $mod 'IdleFuelModifier' $S.IdleFuel $counts 'Idle fuel use (shared gearbox family)'}
                    if([math]::Abs([double]$S.GearSpeed-1.0)-ge 0.0000001){$mod=Tune-GearboxProgression $mod $S.GearSpeed $counts 'Gearbox variants tuned (shared gearbox family)'}
                    if([math]::Abs([double]$S.GearboxDurability-1.0)-ge 0.0000001){$mod=Replace-NumericAttribute $mod 'DamageCapacity' $S.GearboxDurability $counts 'Gearbox durability (shared gearbox family)'}
                    $newText=$mod
                    if($newText -cne $text){ Add-Count $counts ('SHARED gearbox FAMILY '+[string]$S.SharedGearboxType+' - base trucks using selected default') ([int]$S.SharedGearboxTruckUsers) }
                } else {
                    $newText = Modify-Entry $entry.FullName $text $S $counts
                }
                # RC3.9.7: extreme durability is the final override so ordinary durability
                # multipliers cannot push the documented 64000 maximum higher or undo it.
                if ($S.DisableAllDamage) { $newText = Disable-GlobalComponentDamage $entry.FullName $newText $counts }
                $changed = ($newText -cne $originalText)
                if ($changed) { $modifiedFiles++ }
            }
            if ($WriteOutput) {
                $newEntry = $targetZip.CreateEntry($entry.FullName, [IO.Compression.CompressionLevel]::Optimal)
                $newEntry.LastWriteTime = $entry.LastWriteTime
                $dest = $newEntry.Open()
                try {
                    if ($changed) {
                        $newBytes = $utf8.GetBytes($newText)
                        $dest.Write($newBytes, 0, $newBytes.Length)
                    } else {
                        $dest.Write($bytes, 0, $bytes.Length)
                    }
                } finally { $dest.Dispose() }
            }
        }

    } finally {
        if ($null -ne $targetZip) { $targetZip.Dispose() }
        if ($null -ne $output) { $output.Dispose() }
        if ($null -ne $sourceZip) { $sourceZip.Dispose() }
        if ($null -ne $input) { $input.Dispose() }
    }
    # Individual-truck mode must prove that exactly the intended truck XML
    # actually changed BEFORE a rebuilt archive is ever installed over the live PAK.
    if ($WriteOutput -and $S.TargetTruckId -and $modifiedFiles -eq 0) {
        if ($tempPath -and (Test-Path -LiteralPath $tempPath)) { Remove-Item -LiteralPath $tempPath -Force }
        throw ("No applicable values were found: the selected truck '" + $S.TargetTruck + "' resolved correctly, but none of the selected settings apply to its truck-local XML. The live PAK was NOT replaced.")
    }

    # RC3.9.7: if Gear Tuning was requested, prove that at least one gearbox variant
    # was actually tuned before any live PAK replacement. All Trucks may legitimately scan
    # template/helper gearbox XMLs with no named variants, but the overall operation may not
    # silently succeed with zero tuned variants.
    if ([math]::Abs([double]$S.GearSpeed - 1.0) -ge 0.0000001) {
        $gearCount = 0
        if ($counts.ContainsKey('Gearbox variants tuned')) { $gearCount += [int]$counts['Gearbox variants tuned'] }
        if ($counts.ContainsKey('Gearbox variants tuned (shared gearbox family)')) { $gearCount += [int]$counts['Gearbox variants tuned (shared gearbox family)'] }
        if ($gearCount -lt 1) {
            if ($WriteOutput -and $tempPath -and (Test-Path -LiteralPath $tempPath)) { Remove-Item -LiteralPath $tempPath -Force }
            throw 'RC3.9.7 Gear Tuning safety stop: Gear Tuning was requested, but no gearbox variants were tuned. The live PAK was NOT replaced.'
        }
    }

    if ($WriteOutput) {
        $rollbackPath = Join-Path ([IO.Path]::GetDirectoryName($pak)) ('initial.editor.rollback.' + [guid]::NewGuid().ToString('N') + '.pak')
        try {
            Assert-Pak $tempPath
            [void](Test-PakCompatibility $tempPath)
            # Same-volume atomic replacement. If replacement fails, Windows leaves
            # the current live PAK intact; rollback is retained only during swap.
            [IO.File]::Replace($tempPath, $pak, $rollbackPath, $true)
            $tempPath = $null
            Assert-Pak $pak
            Set-LastEditorOutputHash $pak
        } catch {
            if ((Test-Path -LiteralPath $rollbackPath) -and -not (Test-Path -LiteralPath $pak)) {
                Move-Item -LiteralPath $rollbackPath -Destination $pak -Force
            }
            throw
        } finally {
            if ($tempPath -and (Test-Path -LiteralPath $tempPath)) { Remove-Item -LiteralPath $tempPath -Force }
            if (Test-Path -LiteralPath $rollbackPath) { Remove-Item -LiteralPath $rollbackPath -Force }
        }
    }
    # RC3.9.7: fail closed if Extreme Durability was requested but its global pass
    # did not actually touch the documented component families. This prevents a checked
    # GLOBAL option from ever silently becoming a truck-only Apply.
    if ($S.DisableAllDamage) {
        $durabilityKeys = @(
            'GLOBAL extreme durability - engine capacities maxed',
            'GLOBAL extreme durability - gearbox capacities maxed',
            'GLOBAL extreme durability - suspension capacities maxed',
            'GLOBAL extreme durability - wheel capacities maxed',
            'GLOBAL extreme durability - fuel tank capacities maxed'
        )
        foreach ($dk in $durabilityKeys) {
            if (-not $counts.ContainsKey($dk) -or [int]$counts[$dk] -lt 1) {
                if ($WriteOutput -and $tempPath -and (Test-Path -LiteralPath $tempPath)) { Remove-Item -LiteralPath $tempPath -Force }
                throw "RC3.9.7 safety stop: Extreme durability (GLOBAL) was enabled, but the global durability pass did not verify '$dk'. The live PAK was NOT replaced."
            }
        }
    }
    return [pscustomobject]@{ ModifiedFiles=$modifiedFiles; Counts=$counts; Backup=$backup; UpdateDetected=$script:UpdateDetected; Compatibility=$compat; TargetTruck=$S.TargetTruck; ExtremeDurabilityEnabled=[bool]$S.DisableAllDamage }
}

$script:CurrentVersion = [version]'1.1.3'
# IMPORTANT: use the revision-less Raw Gist URL so future edits are visible to already-installed copies.
$script:UpdateInfoUrl = 'https://gist.githubusercontent.com/WickedLord69/3c76989aaf94db0a829da18e01e4c49e/raw/gistfile1.txt'
$script:DefaultDownloadPage = 'https://mod.io/g/snowrunner/m/wl-simplistic-snowrunner-mod-editor#description'

function Get-OnlineUpdateInfo {
    $response = $null
    $reader = $null
    try {
        # HttpWebRequest is available in the .NET Framework runtime used by the packaged EXE.
        # Avoid System.Net.Http/HttpClient so the EXE does not depend on an extra assembly.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $request = [Net.HttpWebRequest]::Create($script:UpdateInfoUrl)
        $request.Method = 'GET'
        $request.Timeout = 3000
        $request.ReadWriteTimeout = 3000
        $request.UserAgent = 'WL-Simplistic-SnowRunner-Mod-Editor/1.1.3'
        $request.CachePolicy = New-Object Net.Cache.RequestCachePolicy([Net.Cache.RequestCacheLevel]::NoCacheNoStore)
        $response = $request.GetResponse()
        $reader = New-Object IO.StreamReader($response.GetResponseStream())
        $text = $reader.ReadToEnd()
        $remoteVersionText = $null
        $downloadPage = $script:DefaultDownloadPage
        foreach ($line in ($text -split "`r?`n")) {
            if ($line -match '^\s*Version\s*=\s*(.+?)\s*$') { $remoteVersionText = $Matches[1].Trim() }
            elseif ($line -match '^\s*DownloadPage\s*=\s*(.+?)\s*$') { $downloadPage = $Matches[1].Trim() }
        }
        if ([string]::IsNullOrWhiteSpace($remoteVersionText)) { throw 'The update information did not contain a Version value.' }
        try { $remoteVersion = [version]$remoteVersionText } catch { throw "The online version '$remoteVersionText' is not valid." }
        if ([string]::IsNullOrWhiteSpace($downloadPage)) { $downloadPage = $script:DefaultDownloadPage }
        [pscustomobject]@{ Version=$remoteVersion; VersionText=$remoteVersionText; DownloadPage=$downloadPage }
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($response) { $response.Dispose() }
    }
}

function Open-UpdateDownloadPage([string]$Url) {
    if ([string]::IsNullOrWhiteSpace($Url)) { $Url = $script:DefaultDownloadPage }
    Start-Process $Url
}

function Test-ForEditorUpdate([bool]$Manual = $false) {
    try {
        $info = Get-OnlineUpdateInfo
        if ($info.Version -gt $script:CurrentVersion) {
            $message = "A newer version of WL Simplistic SnowRunner Mod Editor is available.`r`n`r`nInstalled: v$($script:CurrentVersion)`r`nLatest: v$($info.VersionText)`r`n`r`nOpen the official mod.io download page?"
            $answer = [Windows.Forms.MessageBox]::Show($message, 'Update Available', 'YesNo', 'Information')
            if ($answer -eq 'Yes') { Open-UpdateDownloadPage $info.DownloadPage }
            return 'UpdateAvailable'
        }
        if ($Manual) {
            [Windows.Forms.MessageBox]::Show("You're up to date.`r`n`r`nInstalled: v$($script:CurrentVersion)`r`nLatest: v$($info.VersionText)", 'Check for Updates', 'OK', 'Information') | Out-Null
        }
        return 'Current'
    }
    catch {
        if ($Manual) {
            [Windows.Forms.MessageBox]::Show("Could not check for updates right now.`r`n`r`nThe editor can still be used normally.`r`n`r`n$($_.Exception.Message)", 'Check for Updates', 'OK', 'Warning') | Out-Null
        }
        # Startup checks fail silently by design; offline/update-server issues never block the editor.
        return 'Unavailable'
    }
}

function Format-Summary($Result, [string]$Heading) {
    $lines = New-Object Collections.Generic.List[string]
    $lines.Add($Heading)
    if ($Result.TargetTruck) { $lines.Add("Target: $($Result.TargetTruck)") }
    if ($Result.UpdateDetected) {
        $lines.Add('')
        $lines.Add('SnowRunner update detected. Compatibility passed and a new current-version original backup was created automatically.')
    }
    $lines.Add('')
    $lines.Add("XML files changed: $($Result.ModifiedFiles)")
    $lines.Add("Extreme durability (GLOBAL): $(if ($Result.ExtremeDurabilityEnabled) { 'ON' } else { 'OFF' })")
    foreach ($key in ($Result.Counts.Keys | Sort-Object)) { $lines.Add("$key`: $($Result.Counts[$key]) values") }
    $lines.Add('')
    $lines.Add("Original backup: $($Result.Backup)")
    return $lines -join [Environment]::NewLine
}

$form = New-Object Windows.Forms.Form
$form.Text = $script:AppName
$iconCandidate = if ($env:WL_SSME_ICON) { $env:WL_SSME_ICON } else { Join-Path $script:AppRoot 'assets\WL-icon.ico' }
if (Test-Path -LiteralPath $iconCandidate) { $form.Icon = New-Object Drawing.Icon($iconCandidate) }
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object Drawing.Size(790, 790)
$form.MinimumSize = New-Object Drawing.Size(790, 790)
$form.Font = New-Object Drawing.Font('Segoe UI', 9)
$form.BackColor = [Drawing.Color]::FromArgb(245,247,250)

$title = New-Object Windows.Forms.Label
$title.Text = 'WL Simplistic SnowRunner Mod Editor'
$title.Font = New-Object Drawing.Font('Segoe UI Semibold', 18)
$title.Location = New-Object Drawing.Point(22, 16)
$title.AutoSize = $true
$form.Controls.Add($title)

$subtitle = New-Object Windows.Forms.Label
$subtitle.Text = 'Global adjustments use the clean baseline; individual truck applies accumulate until Restore Original'
$subtitle.ForeColor = [Drawing.Color]::DimGray
$subtitle.Location = New-Object Drawing.Point(25, 51)
$subtitle.AutoSize = $true
$form.Controls.Add($subtitle)

$lblPak = New-Object Windows.Forms.Label
$lblPak.Text = 'Game file'
$lblPak.Location = New-Object Drawing.Point(25, 84)
$lblPak.AutoSize = $true
$form.Controls.Add($lblPak)

$txtPak = New-Object Windows.Forms.TextBox
$txtPak.Location = New-Object Drawing.Point(25, 105)
$txtPak.Size = New-Object Drawing.Size(625, 25)
$form.Controls.Add($txtPak)

$btnBrowse = New-Object Windows.Forms.Button
$btnBrowse.Text = 'Browse...'
$btnBrowse.Location = New-Object Drawing.Point(660, 103)
$btnBrowse.Size = New-Object Drawing.Size(92, 28)
$form.Controls.Add($btnBrowse)

$lblTruck = New-Object Windows.Forms.Label
$lblTruck.Text = 'Truck target'
$lblTruck.Location = New-Object Drawing.Point(25, 139)
$lblTruck.AutoSize = $true
$form.Controls.Add($lblTruck)

$cmbTruck = New-Object Windows.Forms.ComboBox
$cmbTruck.DropDownStyle = 'DropDownList'
$cmbTruck.Location = New-Object Drawing.Point(105, 135)
$cmbTruck.Size = New-Object Drawing.Size(430, 25)
[void]$cmbTruck.Items.Add('All Trucks')
$cmbTruck.SelectedIndex = 0
$form.Controls.Add($cmbTruck)

$btnScanTrucks = New-Object Windows.Forms.Button
$btnScanTrucks.Text = 'Scan Trucks'
$btnScanTrucks.Location = New-Object Drawing.Point(545, 134)
$btnScanTrucks.Size = New-Object Drawing.Size(90, 28)
$form.Controls.Add($btnScanTrucks)

$btnScanMods = New-Object Windows.Forms.Button
$btnScanMods.Text = 'Scan Mods'
$btnScanMods.Location = New-Object Drawing.Point(640, 134)
$btnScanMods.Size = New-Object Drawing.Size(90, 28)
$form.Controls.Add($btnScanMods)

$lblTruckCount = New-Object Windows.Forms.Label
$lblTruckCount.Text = 'Select initial.pak to scan trucks'
$lblTruckCount.ForeColor = [Drawing.Color]::DimGray
$lblTruckCount.Location = New-Object Drawing.Point(735, 140)
$lblTruckCount.Size = New-Object Drawing.Size(30, 35)
$form.Controls.Add($lblTruckCount)

$chkStockWheelSwap = New-Object Windows.Forms.CheckBox
$chkStockWheelSwap.Text = 'TEST 6.18: retired wheel-family substitution test'
$chkStockWheelSwap.Visible = $false
$chkStockWheelSwap.Location = New-Object Drawing.Point(105, 164)
$chkStockWheelSwap.Size = New-Object Drawing.Size(430, 24)
$chkStockWheelSwap.Checked = $false
$chkStockWheelSwap.Enabled = $false
$form.Controls.Add($chkStockWheelSwap)

$panel = New-Object Windows.Forms.Panel
$panel.Location = New-Object Drawing.Point(20, 190)
$panel.Size = New-Object Drawing.Size(740, 455)
$panel.AutoScroll = $true
$panel.BackColor = [Drawing.Color]::White
$panel.BorderStyle = 'FixedSingle'
$form.Controls.Add($panel)

function Add-Section([string]$Text, [int]$X, [int]$Y) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $Text
    $label.Font = New-Object Drawing.Font('Segoe UI Semibold', 11)
    $label.ForeColor = [Drawing.Color]::FromArgb(35,75,125)
    $label.Location = New-Object Drawing.Point($X,$Y)
    $label.AutoSize = $true
    $panel.Controls.Add($label)
}
function Add-Field([string]$Name, [string]$Default, [int]$X, [int]$Y) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $Name
    $label.Location = New-Object Drawing.Point($X,$Y)
    $label.Size = New-Object Drawing.Size(205,23)
    $panel.Controls.Add($label)
    $box = New-Object Windows.Forms.TextBox
    $box.Text = $Default
    $box.TextAlign = 'Right'
    $box.Location = New-Object Drawing.Point(($X+210),($Y-3))
    $box.Size = New-Object Drawing.Size(75,25)
    $panel.Controls.Add($box)
    $script:Fields[$Name] = $box
}
function Add-Combo([string]$Name, [string[]]$Items, [string]$Default, [int]$X, [int]$Y) {
    $label=New-Object Windows.Forms.Label; $label.Text=$Name; $label.Location=New-Object Drawing.Point($X,$Y); $label.Size=New-Object Drawing.Size(205,23); $panel.Controls.Add($label)
    $box=New-Object Windows.Forms.ComboBox; $box.DropDownStyle='DropDownList'; $box.Location=New-Object Drawing.Point(($X+210),($Y-3)); $box.Size=New-Object Drawing.Size(135,25)
    [void]$box.Items.AddRange($Items); $box.SelectedItem=$Default; $panel.Controls.Add($box); $script:Combos[$Name]=$box
}

function Add-Check([string]$Name, [bool]$Default, [int]$X, [int]$Y) {
    $box = New-Object Windows.Forms.CheckBox
    $box.Text = $Name
    $box.Checked = $Default
    $box.Location = New-Object Drawing.Point($X,$Y)
    $box.Size = New-Object Drawing.Size(300,25)
    $panel.Controls.Add($box)
    $script:Checks[$Name] = $box
}

function Set-TruckModeUi {
    $individual = ($cmbTruck.SelectedIndex -gt 0)
    $supportedFields = @('Engine torque','Engine responsiveness','Engine fuel consumption','Engine durability','Gearbox fuel consumption','AWD fuel penalty','Idle fuel use','Gearbox durability','Tire asphalt grip','Tire off-road grip','Tire mud grip','Tire durability','Suspension strength','Suspension height','Suspension damping','Suspension durability','Winch strength','Winch length','Truck fuel capacity','Maximum steering angle','Steering response','Fuel tank durability','Truck prices','Truck center-of-gravity drop','Service fuel capacity','Service repair points','Service spare wheels','Crane strength','Crane speed')
    foreach ($name in $script:Fields.Keys) {
        $script:Fields[$name].Enabled = (-not $individual -or $supportedFields -contains $name)
    }
    if ($script:Combos.ContainsKey('Gear tuning')) { $script:Combos['Gear tuning'].Enabled = $true }
    $supportedChecks = @('Always AWD','Always differential lock (unchecked = default)','Extreme durability (GLOBAL)','Autonomous winches','Unlock all trucks','All trucks in all regions')
    foreach ($name in $script:Checks.Keys) {
        $script:Checks[$name].Enabled = (-not $individual -or $supportedChecks -contains $name)
    }
    $selectedId = if($cmbTruck.SelectedItem -and $script:TruckTargets.ContainsKey([string]$cmbTruck.SelectedItem)){[string]$script:TruckTargets[[string]$cmbTruck.SelectedItem]}else{''}
    $chkStockWheelSwap.Enabled = $false
    $chkStockWheelSwap.Checked = $false
    if ($individual) {
        # Shared/global economy and cargo controls intentionally stay All-Trucks-only.
        # Reset them when entering Individual Truck mode so a preset cannot leave a hidden global value behind.
        $script:Fields['Cargo mass'].Text = '1.00'
        $script:Fields['Upgrade/addon prices'].Text = '1.00'
        $script:Fields['Addon/trailer center-of-gravity drop'].Text = '0.00'
        $script:Checks['Unlock all upgrades/addons'].Checked = $false
        $subtitle.Text = 'Individual official truck - shared component scope is reported in Preview'
    } else {
        $subtitle.Text = 'All Trucks - full global adjustment mode'
    }
}

function Set-Preset([string]$Name) {
    foreach ($field in $script:Fields.Values) { $field.Text = '1.00' }
    $script:Fields['Truck center-of-gravity drop'].Text = '0.00'
    $script:Fields['Addon/trailer center-of-gravity drop'].Text = '0.00'
    foreach ($check in $script:Checks.Values) { $check.Checked = $false }
    $values = @{}
    $enabled = @()
    if ($Name -eq 'Enhanced') {
        $values = @{
            'Engine torque'='1.25'; 'Engine responsiveness'='1.20'; 'Engine fuel consumption'='0.80'; 'Engine durability'='1.50'
            'Gearbox durability'='1.50'; 'Gearbox fuel consumption'='0.80'; 'AWD fuel penalty'='0.50'
            'Tire asphalt grip'='1.15'; 'Tire off-road grip'='1.35'; 'Tire mud grip'='1.50'; 'Tire durability'='1.50'
            'Suspension strength'='1.25'; 'Suspension height'='1.05'; 'Suspension durability'='1.50'
            'Truck fuel capacity'='1.25'; 'Fuel tank durability'='1.50'; 'Winch strength'='1.50'; 'Winch length'='1.25'
            'Crane strength'='1.50'; 'Crane speed'='1.25'; 'Service fuel capacity'='1.50'; 'Service repair points'='1.50'
            'Service spare wheels'='1.50'; 'Cargo mass'='0.80'; 'Truck prices'='0.75'; 'Upgrade/addon prices'='0.75'
            'Maximum steering angle'='1.15'; 'Steering response'='1.20'
            'Truck center-of-gravity drop'='0.25'; 'Addon/trailer center-of-gravity drop'='0.30'
        }
        $enabled = @('Always AWD','Autonomous winches','Unlock all trucks','All trucks in all regions','Unlock all upgrades/addons')
    }
    elseif ($Name -eq 'Overpowered') {
        $values = @{
            'Engine torque'='2.00'; 'Engine responsiveness'='2.00'; 'Engine fuel consumption'='0.25'; 'Engine durability'='5.00'
            'Gearbox durability'='5.00'; 'Gearbox fuel consumption'='0.25'; 'AWD fuel penalty'='0.00'; 'Idle fuel use'='0.25'
            'Tire asphalt grip'='4.00'; 'Tire off-road grip'='4.00'; 'Tire mud grip'='4.00'; 'Tire durability'='5.00'
            'Suspension strength'='3.00'; 'Suspension durability'='5.00'; 'Truck fuel capacity'='3.00'; 'Fuel tank durability'='5.00'
            'Winch strength'='5.00'; 'Winch length'='3.00'; 'Crane strength'='3.00'; 'Crane speed'='2.00'
            'Service fuel capacity'='5.00'; 'Service repair points'='5.00'; 'Service spare wheels'='5.00'; 'Cargo mass'='0.25'
            'Truck prices'='0.10'; 'Upgrade/addon prices'='0.10'; 'Maximum steering angle'='1.30'; 'Steering response'='1.75'
            'Truck center-of-gravity drop'='0.50'; 'Addon/trailer center-of-gravity drop'='0.60'
        }
        $enabled = @('Always AWD','Autonomous winches','Unlock all trucks','All trucks in all regions','Unlock all upgrades/addons')
    }
    foreach ($key in $values.Keys) { if ($script:Fields.ContainsKey($key)) { $script:Fields[$key].Text = $values[$key] } }
    if ($script:Combos.ContainsKey('Gear tuning')) { $script:Combos['Gear tuning'].SelectedItem = $(if($Name -eq 'Vanilla'){'Stock'}elseif($Name -eq 'Enhanced'){'Mild'}else{'High Performance'}) }
    foreach ($key in $enabled) { if ($script:Checks.ContainsKey($key)) { $script:Checks[$key].Checked = $true } }
    $lblStatus.Text = "$Name preset loaded. Click Preview or Apply when ready."
}

Add-Section 'POWER & FUEL' 18 16
Add-Field 'Engine torque' '1.00' 18 50
Add-Field 'Engine responsiveness' '1.00' 18 80
Add-Field 'Engine fuel consumption' '1.00' 18 110
Add-Field 'Truck fuel capacity' '1.00' 380 50
Add-Field 'Maximum steering angle' '1.00' 380 80
Add-Field 'Steering response' '1.00' 380 110

Add-Section 'GEARBOX' 18 155
Add-Field 'Gearbox fuel consumption' '1.00' 18 190
Add-Field 'AWD fuel penalty' '1.00' 18 220
Add-Field 'Idle fuel use' '1.00' 18 250
Add-Check 'Always AWD' $false 380 190
Add-Check 'Always differential lock (unchecked = default)' $false 380 220
Add-Check 'Extreme durability (GLOBAL)' $false 380 250

Add-Section 'TIRES' 18 295
Add-Field 'Tire asphalt grip' '1.00' 18 330
Add-Field 'Tire off-road grip' '1.00' 18 360
Add-Field 'Tire mud grip' '1.00' 18 390

Add-Section 'SUSPENSION' 380 295
Add-Field 'Suspension strength' '1.00' 380 330
Add-Field 'Suspension height' '1.00' 380 360
Add-Field 'Suspension damping' '1.00' 380 390
Add-Field 'Suspension durability' '1.00' 380 420

Add-Section 'RECOVERY & CRANES' 18 440
Add-Field 'Winch strength' '1.00' 18 475
Add-Field 'Winch length' '1.00' 18 505
Add-Field 'Crane strength' '1.00' 18 535
Add-Field 'Crane speed' '1.00' 18 565
Add-Check 'Autonomous winches' $false 380 475

Add-Section 'TRUCK ACCESS' 380 525
Add-Check 'Unlock all trucks' $false 380 560
Add-Check 'All trucks in all regions' $false 380 590

Add-Section 'MORE PERFORMANCE & DURABILITY' 18 630
Add-Combo 'Gear tuning' @('Stock','Mild','Performance','High Performance','Extreme') 'Stock' 18 665
Add-Field 'Engine durability' '1.00' 18 695
Add-Field 'Gearbox durability' '1.00' 18 725
Add-Field 'Tire durability' '1.00' 18 755
Add-Field 'Fuel tank durability' '1.00' 18 785

Add-Section 'SERVICE & CARGO' 380 630
Add-Field 'Service fuel capacity' '1.00' 380 665
Add-Field 'Service repair points' '1.00' 380 695
Add-Field 'Service spare wheels' '1.00' 380 725
Add-Field 'Cargo mass' '1.00' 380 755

Add-Section 'ECONOMY & UPGRADES' 18 835
Add-Field 'Truck prices' '1.00' 18 870
Add-Field 'Upgrade/addon prices' '1.00' 18 900
Add-Check 'Unlock all upgrades/addons' $false 380 870

Add-Section 'STABILITY' 380 900
Add-Field 'Truck center-of-gravity drop' '0.00' 380 935
Add-Field 'Addon/trailer center-of-gravity drop' '0.00' 380 965

Add-Section 'QUICK PRESETS' 18 1010
$btnVanilla = New-Object Windows.Forms.Button
$btnVanilla.Text = 'Vanilla / Reset'
$btnVanilla.Location = New-Object Drawing.Point(18,1045)
$btnVanilla.Size = New-Object Drawing.Size(105,30)
$panel.Controls.Add($btnVanilla)
$btnEnhanced = New-Object Windows.Forms.Button
$btnEnhanced.Text = 'Enhanced'
$btnEnhanced.Location = New-Object Drawing.Point(133,1045)
$btnEnhanced.Size = New-Object Drawing.Size(105,30)
$panel.Controls.Add($btnEnhanced)
$btnOverpowered = New-Object Windows.Forms.Button
$btnOverpowered.Text = 'Overpowered'
$btnOverpowered.Location = New-Object Drawing.Point(248,1045)
$btnOverpowered.Size = New-Object Drawing.Size(115,30)
$panel.Controls.Add($btnOverpowered)
$presetNote = New-Object Windows.Forms.Label
$presetNote.Text = 'Your last applied values are saved automatically.'
$presetNote.ForeColor = [Drawing.Color]::DimGray
$presetNote.Location = New-Object Drawing.Point(380,1051)
$presetNote.AutoSize = $true
$panel.Controls.Add($presetNote)
$panel.AutoScrollMinSize = New-Object Drawing.Size(0,1095)

$btnVanilla.Add_Click({ Set-Preset 'Vanilla' })
$btnEnhanced.Add_Click({ Set-Preset 'Enhanced' })
$btnOverpowered.Add_Click({ Set-Preset 'Overpowered' })

$lblHint = New-Object Windows.Forms.Label
$lblHint.Text = '1.00 = original value   |   1.50 = +50%   |   0.50 = half'
$lblHint.ForeColor = [Drawing.Color]::DimGray
$lblHint.Location = New-Object Drawing.Point(25, 655)
$lblHint.AutoSize = $true
$form.Controls.Add($lblHint)

$btnPreview = New-Object Windows.Forms.Button
$btnPreview.Text = 'Preview Changes'
$btnPreview.Location = New-Object Drawing.Point(25, 688)
$btnPreview.Size = New-Object Drawing.Size(140, 35)
$form.Controls.Add($btnPreview)

$btnRestore = New-Object Windows.Forms.Button
$btnRestore.Text = 'Restore Original'
$btnRestore.Location = New-Object Drawing.Point(175, 688)
$btnRestore.Size = New-Object Drawing.Size(140, 35)
$form.Controls.Add($btnRestore)

$btnUpdates = New-Object Windows.Forms.Button
$btnUpdates.Text = 'Check for Updates'
$btnUpdates.Location = New-Object Drawing.Point(325, 688)
$btnUpdates.Size = New-Object Drawing.Size(130, 35)
$form.Controls.Add($btnUpdates)

$btnApply = New-Object Windows.Forms.Button
$btnApply.Text = 'APPLY MODS'
$btnApply.Font = New-Object Drawing.Font('Segoe UI Semibold', 10)
$btnApply.BackColor = [Drawing.Color]::FromArgb(45,125,75)
$btnApply.ForeColor = [Drawing.Color]::White
$btnApply.FlatStyle = 'Flat'
$btnApply.Location = New-Object Drawing.Point(612, 688)
$btnApply.Size = New-Object Drawing.Size(140, 35)
$form.Controls.Add($btnApply)

$lblStatus = New-Object Windows.Forms.Label
$lblStatus.Text = 'Ready.'
$lblStatus.Location = New-Object Drawing.Point(465, 696)
$lblStatus.Size = New-Object Drawing.Size(135, 25)
$lblStatus.TextAlign = 'MiddleLeft'
$form.Controls.Add($lblStatus)

$btnUpdates.Add_Click({
    $oldStatus = $lblStatus.Text
    try {
        $form.UseWaitCursor = $true
        $lblStatus.Text = 'Checking updates...'
        [Windows.Forms.Application]::DoEvents()
        [void](Test-ForEditorUpdate $true)
    }
    finally {
        $form.UseWaitCursor = $false
        $lblStatus.Text = $oldStatus
    }
})

$btnBrowse.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select SnowRunner initial.pak'
    $dialog.Filter = 'SnowRunner initial.pak|initial.pak|PAK files|*.pak|All files|*.*'
    if ($txtPak.Text -and (Test-Path -LiteralPath $txtPak.Text)) { $dialog.InitialDirectory = [IO.Path]::GetDirectoryName($txtPak.Text) }
    if ($dialog.ShowDialog() -eq 'OK') { $txtPak.Text = $dialog.FileName; try { Refresh-TruckTargets } catch { $lblStatus.Text = 'Truck scan failed.' } }
})

$btnScanTrucks.Add_Click({ try { Refresh-TruckTargets; $lblStatus.Text = "Official truck list refreshed: $($cmbTruck.Items.Count-1) found." } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null; $lblStatus.Text='Truck scan failed.' } })
$btnScanMods.Add_Click({ try { $n = Show-ModScanDiagnostic; $lblStatus.Text = "Read-only installed-mod scan complete: $n truck definition(s) found." } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null; $lblStatus.Text='Mod scan failed.' } })

$cmbTruck.Add_SelectedIndexChanged({
    if ($cmbTruck.SelectedIndex -gt 0) {
        $lblStatus.Text = 'Individual truck mode: Preview changes before Apply; shared component scope is reported.'
        Set-TruckModeUi
    } else { $lblStatus.Text = 'All Trucks mode: full v1.0.0 behavior.'; Set-TruckModeUi }
})

$btnPreview.Add_Click({
    try {
        $form.UseWaitCursor = $true
        $lblStatus.Text = 'Scanning original values...'
        [Windows.Forms.Application]::DoEvents()
        $s = Get-Settings
        Save-Settings $s
        $r = Process-Pak $s $false
        [Windows.Forms.MessageBox]::Show((Format-Summary $r 'Preview complete - no files were changed.'), $script:AppName, 'OK', 'Information') | Out-Null

        $lblStatus.Text = "Preview: $($r.ModifiedFiles) XML files"
    } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null; $lblStatus.Text='Preview failed.' }
    finally { $form.UseWaitCursor = $false }
})

$btnApply.Add_Click({
    try {
        $s = Get-Settings
        Assert-Pak $s.PakPath $true
        Assert-SnowRunnerClosed
        $targetNote = if ($s.TargetTruckId) { "Target ONLY: $($s.TargetTruck)`r`n`r`nIndividual mode modifies the selected truck plus any EXISTING shared component families reported by Preview. Other trucks using those same engine/gearbox/tire/suspension/winch definitions may also be affected. Extreme Durability is always GLOBAL and affects the full base-game fleet.`r`n`r`nCargo Mass, Upgrade/Addon Prices, Addon/Trailer COG, and Unlock All Upgrades/Addons are global-only and disabled here.`r`n`r`nApply now?" } else { 'Target: All Trucks`r`n`r`nSnowRunner is closed. Apply these settings to initial.pak now?' }
        $answer = [Windows.Forms.MessageBox]::Show($targetNote, $script:AppName, 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        $form.UseWaitCursor = $true
        $lblStatus.Text = 'Building modified initial.pak...'
        [Windows.Forms.Application]::DoEvents()
        Save-Settings $s
        $r = Process-Pak $s $true
        [Windows.Forms.MessageBox]::Show((Format-Summary $r 'Mods applied successfully.'), $script:AppName, 'OK', 'Information') | Out-Null
        $lblStatus.Text = "Applied: $($r.ModifiedFiles) XML files"
    } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null; $lblStatus.Text='Apply failed; original is safe.' }
    finally { $form.UseWaitCursor = $false }
})

$btnRestore.Add_Click({
    try {
        Assert-Pak $txtPak.Text.Trim() $true
        $pak = [IO.Path]::GetFullPath($txtPak.Text.Trim())
        Assert-SnowRunnerClosed
        $backup = Get-BackupPath $pak
        $metaPath = Get-BackupMetaPath $pak
        if (-not (Test-Path -LiteralPath $backup) -or -not (Test-Path -LiteralPath $metaPath)) { throw 'No trusted current-version backup exists yet. Use Epic Games Verify, then run Preview once to establish a fresh backup.' }
        $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
        if ((Get-FileSha256 $backup) -ne $meta.BackupHash) { throw 'Backup safety check failed. Do not restore this backup. Use Epic Games Verify instead.' }
        $answer = [Windows.Forms.MessageBox]::Show('Replace initial.pak with the verified current-version original backup?', $script:AppName, 'YesNo', 'Warning')
        if ($answer -eq 'Yes') {
            [IO.File]::Copy($backup, $pak, $true)
            $lblStatus.Text = 'Original initial.pak restored.'
            [Windows.Forms.MessageBox]::Show('The original initial.pak has been restored.', $script:AppName, 'OK', 'Information') | Out-Null
        }
    } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, $script:AppName, 'OK', 'Error') | Out-Null }
})

Load-Settings
if ($txtPak.Text -and (Test-Path -LiteralPath $txtPak.Text)) { try { Refresh-TruckTargets } catch {} }
$script:StartupUpdateCheckDone = $false
$form.Add_Shown({
    if (-not $script:StartupUpdateCheckDone) {
        $script:StartupUpdateCheckDone = $true
        [Windows.Forms.Application]::DoEvents()
        [void](Test-ForEditorUpdate $false)
    }
})
[void]$form.ShowDialog()
