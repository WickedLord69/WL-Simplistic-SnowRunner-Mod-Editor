$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$editorScript = Join-Path $root 'WL-Simplistic-SnowRunner-Mod-Editor.ps1'
$iconPath = Join-Path $root 'assets\WL-icon.ico'
$outputPath = Join-Path $root 'WL-Simplistic-SnowRunner-Mod-Editor.exe'

if (-not (Test-Path -LiteralPath $editorScript)) { throw "Missing editor script: $editorScript" }
if (-not (Test-Path -LiteralPath $iconPath)) { throw "Missing application icon: $iconPath" }

$payload = [Convert]::ToBase64String([IO.File]::ReadAllBytes($editorScript))
$iconPayload = [Convert]::ToBase64String([IO.File]::ReadAllBytes($iconPath))
$source = @'
using System;
using System.Diagnostics;
using System.IO;

internal static class Program
{
    private const string Payload = "__PAYLOAD__";
    private const string IconPayload = "__ICON_PAYLOAD__";

    [STAThread]
    private static void Main()
    {
        string appRoot = AppDomain.CurrentDomain.BaseDirectory;
        string tempScript = Path.Combine(Path.GetTempPath(), "WL-SSME-" + Guid.NewGuid().ToString("N") + ".ps1");
        string tempIcon = Path.Combine(Path.GetTempPath(), "WL-SSME-" + Guid.NewGuid().ToString("N") + ".ico");
        try
        {
            File.WriteAllBytes(tempScript, Convert.FromBase64String(Payload));
            File.WriteAllBytes(tempIcon, Convert.FromBase64String(IconPayload));
            var start = new ProcessStartInfo();
            start.FileName = "powershell.exe";
            start.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + tempScript + "\"";
            start.WorkingDirectory = appRoot;
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.EnvironmentVariables["WL_SSME_ROOT"] = appRoot;
            start.EnvironmentVariables["WL_SSME_ICON"] = tempIcon;
            using (Process process = Process.Start(start))
            {
                process.WaitForExit();
            }
        }
        finally
        {
            try { if (File.Exists(tempScript)) File.Delete(tempScript); } catch { }
            try { if (File.Exists(tempIcon)) File.Delete(tempIcon); } catch { }
        }
    }
}
'@
$source = $source.Replace('__PAYLOAD__', $payload)
$source = $source.Replace('__ICON_PAYLOAD__', $iconPayload)

if (Test-Path -LiteralPath $outputPath) { [IO.File]::Delete($outputPath) }
$compilerOptions = '/win32icon:"' + $iconPath + '"'
$addTypeCommand = Get-Command Add-Type
if ($addTypeCommand.Parameters.ContainsKey('CompilerOptions')) {
    # PowerShell 7+
    Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $outputPath -OutputType WindowsApplication -CompilerOptions $compilerOptions
}
elseif ($addTypeCommand.Parameters.ContainsKey('CompilerParameters')) {
    # Windows PowerShell 5.1 (included with Windows 10 and Windows 11)
    $codeProvider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters
    $compilerParameters.GenerateExecutable = $true
    $compilerParameters.GenerateInMemory = $false
    $compilerParameters.OutputAssembly = $outputPath
    $compilerParameters.CompilerOptions = '/target:winexe ' + $compilerOptions
    [void]$compilerParameters.ReferencedAssemblies.Add('System.dll')
    try {
        $compileResult = $codeProvider.CompileAssemblyFromSource($compilerParameters, [string]$source)
        if ($compileResult.Errors.HasErrors) {
            $errorText = ($compileResult.Errors | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
            throw "C# compiler failed:$([Environment]::NewLine)$errorText"
        }
    }
    finally {
        $codeProvider.Dispose()
    }
}
else {
    throw 'This PowerShell installation does not expose a supported C# compiler interface.'
}

if (-not (Test-Path -LiteralPath $outputPath)) { throw 'The executable was not created.' }
Write-Host ''
Write-Host 'Build complete:' -ForegroundColor Green
Write-Host $outputPath
Write-Host ''
Write-Host 'Launch the EXE and complete one Preview, Apply and Restore test before public upload.'
