$ErrorActionPreference = 'Stop'

$siteRoot = Split-Path $PSScriptRoot -Parent
$indexPath = Join-Path $siteRoot 'index.html'
$i18nPath = Join-Path $siteRoot 'js\i18n.js'
$mainJsPath = Join-Path $siteRoot 'js\main.js'
$guideDirectory = Join-Path $siteRoot 'poradnik'
$expectedPath = Join-Path $PSScriptRoot 'location-claims.expected.json'

$index = Get-Content -Raw -Encoding UTF8 $indexPath
$i18n = Get-Content -Raw -Encoding UTF8 $i18nPath
$mainJs = Get-Content -Raw -Encoding UTF8 $mainJsPath
$expected = Get-Content -Raw -Encoding UTF8 $expectedPath | ConvertFrom-Json
$guideFiles = Get-ChildItem -LiteralPath $guideDirectory -Filter '*.html' -File
$guidePages = $guideFiles | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Content = Get-Content -Raw -Encoding UTF8 $_.FullName
    }
}

$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Assert-DoesNotMatch {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    Assert-True -Condition ($Content -notmatch $Pattern) -Message $Message
}

function Get-I18nLocaleBlocks {
    param([string]$Content)

    $plStart = $Content.IndexOf('    pl: {')
    $enStart = $Content.IndexOf('    en: {')
    $zhStart = $Content.IndexOf('    zh: {')
    if ($plStart -lt 0 -or $enStart -lt 0 -or $zhStart -lt 0) {
        throw 'Could not locate all three i18n language blocks.'
    }

    return @{
        pl = $Content.Substring($plStart, $enStart - $plStart)
        en = $Content.Substring($enStart, $zhStart - $enStart)
        zh = $Content.Substring($zhStart)
    }
}

function Get-I18nValue {
    param(
        [string]$Block,
        [string]$Key,
        [string]$Locale
    )

    $pattern = '"' + [regex]::Escape($Key) + '"\s*:\s*"((?:\\.|[^"])*)"'
    $match = [regex]::Match($Block, $pattern)
    if (-not $match.Success) {
        $script:failures.Add("Missing $Locale translation for $Key.")
        return $null
    }

    return ('"' + $match.Groups[1].Value + '"') | ConvertFrom-Json
}

function Get-IndexValue {
    param(
        [string]$Content,
        [string]$Key
    )

    $pattern = '(?s)data-i18n="' + [regex]::Escape($Key) + '"[^>]*>([^<]*)<'
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        $script:failures.Add("Missing default homepage content for $Key.")
        return $null
    }

    return $match.Groups[1].Value
}

function Get-ExpectedValue {
    param(
        [object]$ExpectedSet,
        [string]$Key
    )

    $property = $ExpectedSet.PSObject.Properties[$Key]
    if ($null -eq $property) {
        throw "Missing expected value for $Key."
    }

    return $property.Value
}

$locationKeys = @(
    'hero.badge',
    'slide.4.desc',
    's.warehouse.d',
    'about.p2',
    'about.f.wh',
    'about.f.hq',
    'contact.address.value',
    'contact.map.cn',
    'footer.tagline',
    'faq.a5',
    'faq.a6'
)

$localeBlocks = Get-I18nLocaleBlocks $i18n
foreach ($locale in @('pl', 'en', 'zh')) {
    foreach ($key in $locationKeys) {
        $value = Get-I18nValue -Block $localeBlocks[$locale] -Key $key -Locale $locale
        $expectedValue = Get-ExpectedValue -ExpectedSet $expected.$locale -Key $key
        Assert-True -Condition ($value -ceq $expectedValue) -Message "$locale translation for $key does not match the Qingdao-only allowlist."
    }
}

foreach ($key in $locationKeys) {
    $value = Get-IndexValue -Content $index -Key $key
    $expectedValue = Get-ExpectedValue -ExpectedSet $expected.default -Key $key
    Assert-True -Condition ($value -ceq $expectedValue) -Message "Default homepage content for $key does not match the Qingdao-only allowlist."
}

$deliveryKeys = @('s.logistics.d', 'p.s5.d', 'faq.a1')
foreach ($locale in @('pl', 'en', 'zh')) {
    foreach ($key in $deliveryKeys) {
        $value = Get-I18nValue -Block $localeBlocks[$locale] -Key $key -Locale $locale
        $expectedValue = Get-ExpectedValue -ExpectedSet $expected.$locale -Key $key
        Assert-True -Condition ($value -ceq $expectedValue) -Message "$locale translation for $key does not match the approved delivery allowlist."
    }
}
foreach ($key in $deliveryKeys) {
    $value = Get-IndexValue -Content $index -Key $key
    $expectedValue = Get-ExpectedValue -ExpectedSet $expected.default -Key $key
    Assert-True -Condition ($value -ceq $expectedValue) -Message "Default homepage content for $key does not match the approved delivery allowlist."
}

$expectedEnglishHero = Get-ExpectedValue -ExpectedSet $expected.en -Key 'hero.badge'
Assert-True -Condition ($expectedEnglishHero -ceq 'Headquarters and warehouse: Qingdao, China') -Message 'Qingdao-only allowlist control was rejected.'
Assert-True -Condition ('Headquarters: Warsaw, Poland' -cne $expectedEnglishHero) -Message 'Warsaw location mutation was not rejected.'
Assert-True -Condition ('Headquarters: Qingdao, China; branch office: Shenzhen, China' -cne $expectedEnglishHero) -Message 'Mixed Qingdao and Shenzhen mutation was not rejected.'
$expectedEnglishDelivery = Get-ExpectedValue -ExpectedSet $expected.en -Key 'p.s5.d'
Assert-True -Condition ($expectedEnglishDelivery -match 'your warehouse') -Message 'Customer warehouse allowlist control was rejected.'
Assert-True -Condition ('We deliver to our Warsaw warehouse.' -cne $expectedEnglishDelivery) -Message 'Aeltras warehouse mutation was not rejected.'

$homeAndTranslations = $index + "`n" + $i18n
Assert-DoesNotMatch $homeAndTranslations '(?i)KSSE' 'Homepage still implies a Polish KSSE location.'

Assert-True -Condition (($index | Select-String -Pattern 'id="map-qingdao"' -AllMatches).Matches.Count -eq 1) -Message 'Homepage must render exactly one Qingdao map container.'
Assert-DoesNotMatch $index 'id="map-chorzow"' 'Homepage still renders the Polish map container.'
Assert-DoesNotMatch $mainJs 'map-chorzow|50\.2945|18\.9681' 'Map script still initializes the former Polish map.'

function Add-SchemaObjects {
    param(
        [object]$Value,
        [System.Collections.Generic.List[object]]$Collection
    )

    if ($null -eq $Value -or $Value -is [string]) {
        return
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        [void]$Collection.Add($Value)
        foreach ($property in $Value.PSObject.Properties) {
            Add-SchemaObjects -Value $property.Value -Collection $Collection
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            Add-SchemaObjects -Value $item -Collection $Collection
        }
    }
}

$schemaObjects = [System.Collections.Generic.List[object]]::new()
$schemaSources = @([PSCustomObject]@{ Name = 'index.html'; Content = $index }) + $guidePages
$schemaBlockCount = 0
foreach ($source in $schemaSources) {
    $schemaMatches = [regex]::Matches($source.Content, '(?s)<script type="application/ld\+json">\s*(.*?)\s*</script>')
    $schemaBlockCount += $schemaMatches.Count
    foreach ($schemaMatch in $schemaMatches) {
        try {
            $schema = $schemaMatch.Groups[1].Value | ConvertFrom-Json
            Add-SchemaObjects -Value $schema -Collection $schemaObjects
        } catch {
            $failures.Add("$($source.Name) contains invalid JSON-LD: $($_.Exception.Message)")
        }
    }
}

Assert-True -Condition ($schemaBlockCount -gt 0) -Message 'No JSON-LD blocks were found.'
$postalAddresses = @($schemaObjects | Where-Object { $_.'@type' -eq 'PostalAddress' })
$addressedAeltrasOrganizations = @($schemaObjects | Where-Object {
    $_.PSObject.Properties.Name -contains 'address' -and
    ($_.name -like 'Aeltras*' -or $_.'@id' -eq 'https://aeltras.pl/#organization' -or $_.'@type' -eq 'ProfessionalService')
})
$faqSchemas = @($schemaObjects | Where-Object { $_.'@type' -eq 'FAQPage' -and $_.'@id' -eq 'https://aeltras.pl/#faq' })

Assert-True -Condition ($postalAddresses.Count -eq 1) -Message 'All site JSON-LD must contain exactly one postal address.'
Assert-True -Condition ($addressedAeltrasOrganizations.Count -eq 1) -Message 'All site JSON-LD must contain exactly one addressed Aeltras organization.'
if ($postalAddresses.Count -eq 1 -and $addressedAeltrasOrganizations.Count -eq 1) {
    $organization = $addressedAeltrasOrganizations[0]
    $address = $postalAddresses[0]
    $addressProperties = @($address.PSObject.Properties.Name | Sort-Object)
    $expectedAddressProperties = @('@type', 'addressCountry', 'addressLocality', 'addressRegion') | Sort-Object

    Assert-True -Condition (($addressProperties -join ',') -ceq ($expectedAddressProperties -join ',')) -Message 'Structured organization address contains unexpected location fields.'
    Assert-True -Condition ($organization.address -eq $address) -Message 'The sole postal address is not attached to the Aeltras organization.'
    Assert-True -Condition ($address.addressLocality -ceq 'Qingdao') -Message 'Structured data must identify Qingdao as the company locality.'
    Assert-True -Condition ($address.addressRegion -ceq 'Shandong') -Message 'Structured data must identify Shandong as the company region.'
    Assert-True -Condition ($address.addressCountry -ceq 'CN') -Message 'Structured data must identify China as the company address country.'
    Assert-True -Condition ($organization.description -ceq $expected.schema.organization_description) -Message 'Structured company description does not match the Qingdao-only allowlist.'
}
Assert-True -Condition ($faqSchemas.Count -eq 1) -Message 'Site JSON-LD must contain exactly one homepage FAQ schema.'
if ($faqSchemas.Count -eq 1) {
    $faqSchema = $faqSchemas[0]
    Assert-True -Condition ($faqSchema.mainEntity[4].acceptedAnswer.text -ceq (Get-ExpectedValue -ExpectedSet $expected.default -Key 'faq.a5')) -Message 'Structured FAQ warehouse answer does not match the Qingdao-only allowlist.'
    Assert-True -Condition ($faqSchema.mainEntity[5].acceptedAnswer.text -ceq (Get-ExpectedValue -ExpectedSet $expected.default -Key 'faq.a6')) -Message 'Structured FAQ company-location answer does not match the Qingdao-only allowlist.'
}

$metaDescription = [regex]::Match($index, '<meta\s+name="description"\s+content="([^"]+)"')
$ogDescription = [regex]::Match($index, '<meta\s+property="og:description"\s+content="([^"]+)"')
Assert-True -Condition ($metaDescription.Success -and $metaDescription.Groups[1].Value -ceq $expected.meta.description) -Message 'Homepage metadata description does not match the Qingdao-only allowlist.'
Assert-True -Condition ($ogDescription.Success -and $ogDescription.Groups[1].Value -ceq $expected.meta.og_description) -Message 'Open Graph description does not match the Qingdao-only allowlist.'

foreach ($page in $guidePages) {
    $footerLocation = [regex]::Match($page.Content, '(?s)<footer>\s*<p class="footer-logo".*?</p>\s*<p>(.*?)</p>')
    Assert-True -Condition ($footerLocation.Success -and $footerLocation.Groups[1].Value -ceq 'Centrum operacyjne: Qingdao, Chiny') -Message "$($page.Name) footer location is not exactly Qingdao-only."
}

Assert-True -Condition ($index -match 'Transport z Chin do Polski') -Message 'Normal Poland-facing logistics copy was removed from the homepage.'
Assert-True -Condition ($i18n -match 'Zabrze, Polska') -Message 'The Polish client case location was removed.'
Assert-True -Condition ($i18n -match 'Gliwice, Polska') -Message 'The Gliwice client case location was removed.'
Assert-True -Condition ($i18n -match 'Krak\\u00F3w, Polska') -Message 'The Krakow client case location was removed.'
Assert-True -Condition (($guidePages | Where-Object Name -eq 'transport-z-chin-do-polski.html').Content -match 'magazyn odbiorcy w Polsce') -Message 'Legitimate customer warehouse copy in Poland was removed.'

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

Write-Output "PASS: Qingdao is the only Aeltras location advertised across the homepage and $($guideFiles.Count) guide pages."
