
# This program:
# 1) Takes in a pdf
# 2) Writes the output to a text file
# 3) Iterates through the textfile line by line
# 4) Pulls out elements by regex
# 5) Writes the output to a json file

$pdf = $args[0]

# variables for elements we want to extract
$citationType = ""
$citationValue = ""
$caseNumber = ""
$panelLocation = ""
[String[]] $panelMembers
[String[]] $claimants
[String[]] $defendants

# flags for whether we keep appending values to collections
$panelList = $false
$claimantList = $false
$defendantList = $false

# Matching regex - eg. Does this look like a location,digest,citation,date etc...
$citationMatchRegex = "\[\d{4}\]\s\w{3,4}\s\d{2,3}" # Refactor using more cases, in this we're just looking for the citation value in the end
$caseNumberMatchRegex = "(?i)(Case Number:)"

$panelListBeginRegex = "(?i)(^Before:$)"
$panelListEndRegex = "(?i)(^Between:$)"

$claimantListBeginRegex = "(?i)(^Between:$)"
$claimantListEndRegex = "(?i)(^Claimant$)"

$defendantListBeginRegex = "(?i)(^Claimant$)"
$defendantListEndRegex = "(?i)(^Defendants$)"

# Extraction regex eg. How we pull out the data we want from the string
$caseNumberRegex = "[^(Case Number:)]+[a-zA-Z\s()]+"
$citationTypeRegex = "[\w\s]+(?=\s\[)"
$citationValueRegex = "\[\d{4}\]\s\w{3,4}\s\d{2,3}"
$panelMembersRegex = "(?i)(Honourable|Justice|Professor|QC)" # TODO: Right now we have to try to find titles/roles to grab the panel hearing names, must be better way
$panelLocationRegex = "(Sitting as a Tribunal in)"
$defendantRegex = "(?<=\)\s)[\w\s]+" # We have to use a positive lookbehind since defendants are listed in parentheses eg. (1) Visa etc..

# If the text output is already there, delete it (test code)
if([System.IO.File]::Exists("$(Get-Location)\intermediate.txt")){
    Remove-Item "$(Get-Location)\intermediate.txt"
}

# Ingest file and convert it
pdfToText $pdf intermediate.txt

# Loop through the file we just made line by line and pick out the parts we want
foreach($line in Get-Content .\intermediate.txt){

    # Does it look like a citation?
    if($line -match $citationMatchRegex){
        $line -match $citationTypeRegex | Out-Null
        $citationType = $matches[0].Trim()
        $line -match $citationValueRegex | Out-Null
        $citationValue = $matches[0].Trim()
    }

    # Does it look like a case number?
    if($line -match $caseNumberMatchRegex){
        $line -match $caseNumberRegex | Out-Null
        $caseNumber = $matches[0]
    }

    # Panel 
    # Does it seem like a panel list?
    if($line -match $panelListBeginRegex){
        $panelList=$true
    }

    # If we are in the middle of a panel list, we need to loop for the elements we want
    if($panelList){
        $matches.clear()
        if($line -match $panelMembersRegex){
            $panelMembers += $line.Trim()
        }
        
        if($line -match $panelLocationRegex){
            $panelLocation = $line.Trim()
        }
    }

    # If the list ends we've to end the inner search
    if($line -match $panelListEndRegex){
        $claimantList=$false
    }

    # Claimants
    # Does it seem like a list of claimants?
    if($line -match $claimantListBeginRegex){
        $claimantList=$true
    }

    # If the list ends we've to end the inner search
    if($line -match $claimantListEndRegex){
        $claimantList=$false
    }

    # If we are in the middle of a claimant list, we need to loop for the elements we want
    if($claimantList){
        if(!($line -match $claimantListBeginRegex -or $line -match $claimantListEndRegex)){
            $claimants += $line.Trim()
        }
    }

    # Defendants
    # If we are in the middle of a defendant list, we need to loop for the elements we want
    if($defendantList){
        $matches.clear()
        if(!($line -match $defendantListBeginRegex -or $line -match $defendantListEndRegex)){
            $line -match $defendantRegex | Out-Null
            $defendants += $matches[0]
            
        }
    }

    # Does it seem like a list of defendants?
    if($line -match $defendantListBeginRegex){
        $defendantList=$true
    }

    # If the list ends we've to end the inner search
    if($line -match $defendantListEndRegex){
        $defendantList=$false
    }
}

# Remove the text file since we're done reading it
Remove-Item "$(Get-Location)\intermediate.txt"

# Assign the result to variables using regex (this needs to be much more complex in the future.)
# Being able to answer "what is this?" when handling a block of text is critical to automated file ingestion

# TODO: find a better way to output arrays, powershell concatenates them into a string without delimiters
# Assembling the json
$citationJson = @()
$citationJson += [PSCustomObject]@{
    type=$citationType
    value=$citationValue
}

$panelJson = @()
$panelJson += [PSCustomObject]@{
    location=$panelLocation
    members=$panelMembers
}

$json = [pscustomobject]@{
    'panel'=$panelJson
    'citation'=$citationJson
    'case_number'=$caseNumber
    'claimants'=$claimants
    'defendants'=$defendants
}

# Comment this line if you don't want to print to the console
$json | ConvertTo-Json

# If the json file is already there, delete it (test code)
if([System.IO.File]::Exists("$(Get-Location)\output.json")){
    Remove-Item "$(Get-Location)\output.json"
}

# Create the json file
$json | ConvertTo-Json | Out-File "$(Get-Location)\output.json"
