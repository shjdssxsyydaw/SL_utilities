#require -version 2.0  
#$MyInvocation
#$PWD

$cpus = Get-WmiObject Win32_Processor -Property "numberOfCores", "NumberOfLogicalProcessors" | Select-Object -Property "numberOfCores", "NumberOfLogicalProcessors"

# create a pool of 3 runspaces  
$pool = [runspacefactory]::CreateRunspacePool(1, $cpus.numberOfCores )  
$pool.Open()  
 
write-host "Available Runspaces: $($pool.GetAvailableRunspaces())" 
 
$jobs = @()  
$waits = @()  
 
# run 6 background pipelines  
 foreach ($file in get-ChildItem *.fmb) {
    Echo $file.name
    if ($file.IsReadOnly -eq $true)  
{  
    Echo "making writable"
  $file.IsReadOnly = $false   
}
    # create a "powershell pipeline runner"  
   $Powershell = [powershell]::create()  
     
   # assign our pool of 3 runspaces to use  
   $Powershell.runspacepool = $pool 
   
   $Powershell | Add-Member NoteProperty TargetFile $file

   
   # test command: beep and wait a certain time  
#   [void]$ps[-1].AddScript(  "frmcmp module=$file userid=mi_uni/saffron@mid04d  module_type=LIBRARY  logon=YES compile_all=YES batch=YES window_state=MINIMIZE")  
   #[void]$Powershell.AddScript(  "dir $file ; sleep 1;")  
   #[void]$Powershell.AddScript(  "frmcmp module=$file userid=mi_uni/saffron@mid04d  module_type=LIBRARY  logon=YES compile_all=YES batch=YES window_state=MINIMIZE; sleep 1 ;")  
   #[void]$Powershell.AddScript(  "cd $PWD ; frmcmp module=$file userid=mi_uni/saffron@mid04d  module_type=FORM  logon=YES compile_all=YES batch=YES window_state=MINIMIZE; statistics=yes; sleep 1 ")  
   [void]$Powershell.AddScript(  "cd $PWD ; .\compile_single.bat $file ")  
          
   # start job  
   #write-host "$file will be compiled " 
   $runspace = $Powershell.BeginInvoke();  
   
   $jobs += @(, ($powershell, $runspace));
     
   # store wait handles for WaitForAll call  
   $waits += $runspace.AsyncWaitHandle 
   
   #Echo $jobs
  }


# wait 20 seconds for all jobs to complete, else abort  
$success = [System.Threading.WaitHandle]::WaitAll($waits)  
 
write-host "All completed? $success" 

# end async call  
foreach ($x in $jobs)
{
  $ps = $x[0]
  $rs = $x[1]
 
    write-host "Completing job " $ps.TargetFile
 
    try {  
 
        # complete async job  
        $ps.EndInvoke($rs)  
 
    } catch {  
      
        # oops-ee!  
        write-warning "error: $_" 
    }  
 
    # dump info about completed pipelines  
    $info = $ps.InvocationStateInfo  
    write-host "State: $($info.state) ; Reason: $($info.reason)" 
}  
 
     
# should show 3 again.  
write-host "Available runspaces: $($pool.GetAvailableRunspaces())" 

$pool.Close() 