param(
  [Parameter(Mandatory=$True)]
  [String]$ResourceGroupName,

  [Parameter(Mandatory=$True)]
  [String]$VisioPageName,

  [Parameter(Mandatory=$True)]
  [String]$FilePath
)
$VirtualMachines = Get-AzureRmVM
$NetworkInterfaces = Get-AzureRmNetworkInterface
$VisioDiagram = New-Object -ComObject Visio.Application
$Documents = $VisioDiagram.Documents
$VisioDocument = $Documents.Add('')

$Pages = $VisioDiagram.ActiveDocument.Pages

$Page = $Pages.Item(1)
$Page.Name = 'Development'
$Page.AutoSize = $true

$Stencil = $VisioDiagram.Documents.Add('Basic Shapes.vss')
$AzureStencil = $VisioDiagram.Documents.OpenEx("$env:USERPROFILE\Documents\My Shapes\Symbols\CnE_Cloud\CnE_CloudV2.6.vss",64)

$ResourceGroup = $AzureStencil.Masters('Resource Group')
$ResourceGroup = $Page.Drop($ResourceGroup,4,10)
$ResourceGroup.Text = $ResourceGroupName

$Xposition = 0
$YPosition = 8
Foreach($VirtualMachine in ($VirtualMachines | Where-Object -Property ResourceGroupName -Like -Value $ResourceGroupName)){
  $VirtualMachineShape = $AzureStencil.Masters('Virtual Machine')
  $Shape = $Page.Drop($VirtualMachineShape,$Xposition,$YPosition)
  $Shape.AutoConnect($ResourceGroup,0)
  $Shape.Text = "$($VirtualMachine.Name) `n $(((($NetworkInterfaces | Where-Object -Property Id -EQ -Value $VirtualMachine.NetworkProfile.NetworkInterfaces.id).IpConfigurations.PrivateIPAddress)))"
  
  If($Xposition -le 10){
    $Xposition++
  }
  else{
    $Xposition = 0
    $YPosition--
  }
}

$Page.ResizeToFitContents()

$VisioDocument.SaveAs((Resolve-Path $FilePath).Path)
$VisioDiagram.Quit()