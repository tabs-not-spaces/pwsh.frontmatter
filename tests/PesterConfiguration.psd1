@{
    Run          = @{
        Path = '.'
    }
    Output       = @{
        Verbosity = 'Detailed'
    }
    TestResult   = @{
        Enabled      = $true
        OutputFormat = 'NUnitXml'
        OutputPath   = 'testResults.xml'
    }
    Should       = @{
        ErrorAction = 'Stop'
    }
}
