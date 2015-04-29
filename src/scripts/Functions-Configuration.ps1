function Get-SubstitutionsForLiveAgentServiceS3Logs
{
    $bucketName = ($OctopusParameters["LogsBucketName"]).ToLowerInvariant()
    $environment = ($OctopusParameters["Octopus.Environment.Name"])

    return @{
        "@@BUCKET_NAME"=$bucketName;
        "@@ENVIRONMENT"=$environment;
    }
}

function Get-SubstitutionsForRavenDBLogEvents
{
    $environment = ($OctopusParameters["Octopus.Environment.Name"])

    return @{
        "@@ENVIRONMENT"=$environment;
    }
}