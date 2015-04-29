function Single
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $input,
        [Parameter(Mandatory=$false)]
        $predicate
    )

    begin
    {
        $hasMatch = $false
        $accepted = $null
    }
    process
    {
        if ($predicate -eq $null -or (& $predicate $input))
        {
            if ($hasMatch) { throw "Multiple elements matching predicate found. First element was [$accepted]. This element is [$_]." }

            $hasMatch = $true
            $accepted = $_
        }
    }
    end
    {
        if ($accepted -eq $null) { throw "No elements matching predicate found." }
        return $accepted
    }
}

function Any
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $input,
        [Parameter(Mandatory=$false)]
        [scriptblock]$predicate
    )

    begin
    {
        $hasMatch = $false
    }
    process
    {
        if ((-not $hasMatch) -and ($predicate -eq $null) -or (& $predicate $_))
        {
            write-verbose "[$_] matched [$predicate], returning true."
            $hasMatch = $true
        }
        else
        {
            write-verbose "[$_] does not match when tested with [$predicate]"
        }
    }
    end
    {
        return $hasMatch
    }
}