
$limit = 500
$selected = ( "ObjectName", "SlaDomain", "TotalLocalStorage", "TotalArchiveStorage", "LastSnapshot")
$report_name = "Object Protection Summary"
$item_to_report = 'VmwareVirtualMachine'
$base_folder = 'UF Hosting'

$uri = [uri]::EscapeUriString('report?name='+$report_name)
$report= ((Invoke-RubrikRESTCALL -Method GET -Endpoint $uri -api 'internal').data)
foreach($r in $report){
  if ($r.name -eq $report_name){$report_id = $r.id;}
  }
Write-Host $("Report is $report_id")
if ($report_id){
  $uri = [uri]::EscapeUriString("report/$($report_id)/table")
  $payload = @{
    "limit" = $limit
  }
  $report_results = (Invoke-RubrikRESTCALL -Method POST -Endpoint $uri -api 'internal' -Body $payload)
  $report_columns = '"{0}"' -f ($report_results.columns -join '","')
  $report_data = $report_results.dataGrid
  while ($report_results.hasMore){
    $payload = @{
      "limit" = $limit
      "cursor" = "$($report_results.cursor)"
    }
    $report_results = (Invoke-RubrikRESTCALL -Method POST -Endpoint $uri -api 'internal' -Body  $payload)
    $report_data += $report_results.dataGrid
  }

  $columns = $selected
  $columns += "Status"
  $columns += "BusinessUnit"
  Write-Host ('"{0}"' -f ($columns -join '","'))
  foreach ($report_line in $report_data){
    $last_status = ''
    $report_out = @()
    if ($report_line[$($report_results.columns.indexOf("ObjectType"))] -notcontains $item_to_report){continue}
    foreach($f in $selected){
      $report_out += $report_line[$($report_results.columns.indexOf($f))]
    }
    $uri = [uri]::EscapeUriString("event?limit=1&event_type=Backup&object_ids=$($report_line[$report_results.columns.indexOf('ObjectId')])")
    $last_status = ((Invoke-RubrikRESTCALL -Method GET -Endpoint $uri -api 'internal').data[0].eventStatus)
    $report_out += $last_status
    $uri = [uri]::EscapeUriString("vmware/vm/$($report_line[$report_results.columns.indexOf('ObjectId')])")
    $vm_detail = ((Invoke-RubrikRESTCALL -Method GET -Endpoint $uri -api 'v1').folderPath)
    foreach ($folderPath in $vm_detail){
      if ($getNext){$report_out += $folderPath.name;$getNext=0;}
      if ($folderPath.name -eq $base_folder){$getNext=1}
    }
    $report_out = '"{0}"' -f ($report_out -join '","')
    Write-Host $report_out
  }
}
