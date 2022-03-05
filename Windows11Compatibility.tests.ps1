
#Requires -RunAsAdministrator
#Requires -Module Pester

Param(
    [parameter(Mandatory = $false)]
    [string[]]$ServerList = 'localhost'
)

$InvokePester = @{
    Output = 'Detailed'
    Container = New-PesterContainer -Data @{ ServerList = $ServerList } -ScriptBlock {
        Param(
            [parameter(Mandatory = $false)]
            [string[]]$ServerList = 'localhost'
        )
        Describe -Name 'Windows 11 Compatibility' -Fixture {
            Context -Name "Testing Computer: <_>" -Foreach $ServerList -Fixture {
                BeforeAll {
                    $CimSession = New-CimSession -ComputerName $_ -Authentication Negotiate -Name $PSItem -SessionOption (New-CimSessionOption -SkipCACheck -SkipCNCheck) -ErrorAction Stop
                    $PSSession = New-PSSession -ComputerName $_ -EnableNetworkAccess  -ErrorAction Stop
                    $VideoProcessors = @(@(Get-ciminstance -Query "SELECT VideoProcessor, CurrentVerticalResolution FROM win32_VideoController WHERE VideoProcessor IS NOT NULL" -CimSession $CimSession).ForEach({
                        (@{
                                    'VideoProcessor'            = $PSItem.VideoProcessor
                                    'CurrentVerticalResolution' = $PSItem.CurrentVerticalResolution
                                })
                            }))
                }
                It -Name 'Processor Clock Speed should be Greater than 1' -Test {
                    if(-not $CimSession){
                        Set-ItResult -Skipped -Because 'CimSession not created'
                    }
                    else{                        
                        [math]::round((Get-CimInstance -Query "SELECT CurrentClockSpeed FROM Win32_Processor" -CimSession $CimSession).CurrentClockSpeed / 1000, 1) | Should -BeGreaterThan 1
                    }
                }
                It -Name 'Number of Cores should be Greater than 2' -Test {
                    if(-not $CimSession){
                        Set-ItResult -Skipped -Because 'CimSession not created'
                    }
                    else{                        
                        (Get-CimInstance -Query "SELECT NumberOfCores FROM Win32_Processor" -CimSession $CimSession).NumberOfCores | Should -BeGreaterThan 2
                    }
                }
                It -Name 'Physical Memory Should be Greater than 4Gb' -Test {
                    if(-not $CimSession){
                        Set-ItResult -Skipped -Because 'CimSession not created'
                    }
                    else{                        
                        [math]::round(((Get-CimInstance -Query "SELECT TotalPhysicalMemory FROM win32_computersystem" -CimSession $CimSession).TotalPhysicalMemory) / 1GB) | Should -BeGreaterThan 4
                    }
                }
                It -Name 'FreeSpace Should be Greater than 64Gb' -Test {
                    if(-not $CimSession){
                        Set-ItResult -Skipped -Because 'CimSession not created'
                    }
                    else{                        
                        $SystemDrive = (get-ciminstance -Query "SELECT systemdrive FROM Win32_OperatingSystem" -CimSession $CimSession).systemdrive
                        [math]::round((Get-CimInstance -Query "SELECT FreeSpace FROM Win32_LogicalDisk WHERE DeviceId LIKE '$SystemDrive'").FreeSpace / 1GB, 0)  | Should -BeGreaterThan 64
                    }
                }
                It -Name 'Graphics resolution for <VideoProcessor> should be greater than 720p' -TestCases $VideoProcessors -Test {
                    param($VideoProcessor, $CurrentVerticalResolution)
                    if(-not $CimSession){
                        Set-ItResult -Skipped -Because 'CimSession not created'
                    }
                    else{                        
                        $CurrentVerticalResolution | Should -BeGreaterThan 720
                    }
                }
                It -Name 'Boot Loader Should be UEFI' -Test {
                    if(-not $PSSession){
                        Set-ItResult -Skipped -Because 'CimSession not created'
                    }
                    else{ 
                        $BiosFirmwareType = (Invoke-Command -Session $PSSession -ScriptBlock {
                            (Get-ComputerInfo).BiosFirmwareType
                        }).Value 
                        $BiosFirmwareType | Should -Be 'UEFI'
                    }
                }
                It -Name 'TPM Module should be Version 2.x' -Test {
                    if(-not $CimSession){
                        Set-ItResult -Skipped -Because 'CimSession not created'
                    }
                    else{ 
                        $TPM = Get-CimInstance -Namespace 'Root\CIMV2\Security\MicrosoftTpm' -Query "Select IsEnabled_InitialValue, SpecVersion from win32_tpm WHERE SpecVersion like '%2.0%'" -CimSession $CimSession
                        $TPM.IsEnabled_InitialValue | Should -Be $true
                        $TPM.SpecVersion | Should -Match '2.0'
                    }
                }
                It -Name 'Secure Boot should be enabled' -Test {
                    $UEFISecureBootEnabled = [bool](Invoke-Command -Session $PSSession -ScriptBlock {
                        (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\control\SecureBoot\State' -Name 'UEFISecureBootEnabled').UEFISecureBootEnabled
                    }).Value
                    $UEFISecureBootEnabled | Should -Be $true
                }
                AfterAll {
                    Remove-CimSession -CimSession $CimSession
                    Remove-PSSession -Session $PSSession
                }
            } 
        }
    }
}
Invoke-Pester @InvokePester