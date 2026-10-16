#Requires -Version 7.0
<#
.SYNOPSIS
    L00, dio B: zaposlenici Adria Motora iz kadrovskog izvoza u Entra ID.

.DESCRIPTION
    Bez -Izvrsi skripta samo cita CSV i ispisuje plan. Ne spaja se nikamo i nista ne mijenja.
    S -Izvrsi spaja se na Microsoft Graph i:
      1. kreira aktivne zaposlenike (preskace one s datumom odlaska u proslosti),
      2. postavlja nadredjene,
      3. kreira dinamicke grupe po odjelima,
      4. kreira dinamicku grupu za licencu i dodjeljuje joj Business Premium,
      5. Dariju dodjeljuje uloge Global Reader i Billing Administrator.
    Skripta je idempotentna: sto vec postoji, preskace.

.EXAMPLE
    .\L00-kreiraj-korisnike.ps1            # samo plan
    .\L00-kreiraj-korisnike.ps1 -Izvrsi    # stvarne promjene
#>
[CmdletBinding()]
param(
    [string]$CsvPath      = (Join-Path $PSScriptRoot 'zaposlenici_adria_motori.csv'),
    [string]$Domena       = 'adriamotorilab.onmicrosoft.com',
    [string]$Tvrtka       = 'Adria Motori d.o.o.',
    [string]$LozinkeIzlaz = (Join-Path $HOME 'adria_privremene_lozinke.csv'),
    [switch]$Izvrsi
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 1. Pomocne funkcije
# ---------------------------------------------------------------------------

# Hrvatska slova zadana su kodovima znakova, pa skripta radi neovisno o kodiranju datoteke.
$script:Translit = @{
    ([string][char]0x010D) = 'c'   # c s kvacicom
    ([string][char]0x0107) = 'c'   # c s crticom
    ([string][char]0x0161) = 's'   # s s kvacicom
    ([string][char]0x017E) = 'z'   # z s kvacicom
    ([string][char]0x0111) = 'd'   # dj
}

function ConvertTo-Slug {
    # "Korisnicka sluzba" s dijakritikom -> "korisnicka-sluzba", "Simic" s dijakritikom -> "simic"
    param([Parameter(Mandatory)][string]$Tekst)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($znak in $Tekst.Trim().ToLowerInvariant().ToCharArray()) {
        $z = [string]$znak
        if     ($script:Translit.ContainsKey($z)) { [void]$sb.Append($script:Translit[$z]) }
        elseif ($z -cmatch '^[a-z0-9]$')         { [void]$sb.Append($z) }
        elseif ($z -match '^[\s\-_]$')           { [void]$sb.Append('-') }
        # sve ostalo (tocke, apostrofi) se izbacuje
    }
    return (($sb.ToString() -replace '-{2,}', '-').Trim('-'))
}

function New-PrivremenaLozinka {
    param([int]$Duljina = 20)
    $skupovi = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnpqrstuvwxyz', '23456789', '!@#%*-_=+?')
    $rng = [System.Security.Cryptography.RandomNumberGenerator]
    # po jedan znak iz svakog skupa, da lozinka sigurno zadovolji pravila slozenosti
    $znakovi = [System.Collections.Generic.List[char]]::new()
    foreach ($s in $skupovi) { $znakovi.Add($s[$rng::GetInt32($s.Length)]) }
    $svi = -join $skupovi
    while ($znakovi.Count -lt $Duljina) { $znakovi.Add($svi[$rng::GetInt32($svi.Length)]) }
    # Fisher-Yates mijesanje, da prva cetiri znaka ne budu predvidljiva
    for ($i = $znakovi.Count - 1; $i -gt 0; $i--) {
        $j = $rng::GetInt32($i + 1)
        $tmp = $znakovi[$i]; $znakovi[$i] = $znakovi[$j]; $znakovi[$j] = $tmp
    }
    return (-join $znakovi)
}

# ---------------------------------------------------------------------------
# 2. Citanje i provjera kadrovskog izvoza
# ---------------------------------------------------------------------------
if (-not (Test-Path $CsvPath)) { throw "Ne nalazim CSV: $CsvPath" }

# Zaglavlja iz HR sustava imaju razmake i dijakritiku; zamjenjujemo ih ASCII imenima
# i preskacemo prvi red (originalno zaglavlje).
$zaglavlja = 'Ime','Prezime','RadnoMjesto','Odjel','Lokacija','Nadredjeni','DatumZaposlenja','DatumOdlaska','SluzbeniMobitel'
$redovi = @(Import-Csv -Path $CsvPath -Delimiter ';' -Encoding utf8 -Header $zaglavlja | Select-Object -Skip 1)

$danas   = (Get-Date).Date
$otisli  = @($redovi | Where-Object { $_.DatumOdlaska -and ([datetime]$_.DatumOdlaska -le $danas) })
$aktivni = @($redovi | Where-Object { -not $_.DatumOdlaska -or ([datetime]$_.DatumOdlaska -gt $danas) })

# Lokacija korisnika (usageLocation) je obavezna za dodjelu licence.
$zemlja = @{ 'Zagreb' = 'HR'; 'Ljubljana' = 'SI' }

$plan = @(foreach ($r in $aktivni) {
    if (-not $zemlja.ContainsKey($r.Lokacija)) { throw "Nepoznata lokacija '$($r.Lokacija)' za $($r.Ime) $($r.Prezime)" }
    $lokalni = '{0}.{1}' -f (ConvertTo-Slug $r.Ime), (ConvertTo-Slug $r.Prezime)
    [pscustomobject]@{
        DisplayName   = "$($r.Ime) $($r.Prezime)"
        GivenName     = $r.Ime
        Surname       = $r.Prezime
        UPN           = "$lokalni@$Domena"
        MailNickname  = $lokalni
        JobTitle      = $r.RadnoMjesto
        Department    = $r.Odjel
        Office        = $r.Lokacija
        UsageLocation = $zemlja[$r.Lokacija]
        Nadredjeni    = $r.Nadredjeni
    }
})

$duplikati = $plan | Group-Object UPN | Where-Object Count -gt 1
if ($duplikati) { throw "Dupla korisnicka imena: $($duplikati.Name -join ', ')" }

$odjeli = @($plan.Department | Sort-Object -Unique)

# ---------------------------------------------------------------------------
# 3. Plan
# ---------------------------------------------------------------------------
Write-Host "`n=== PLAN ===" -ForegroundColor Cyan
Write-Host ("Redova u izvozu: {0} | aktivnih: {1} | otislih: {2}" -f $redovi.Count, $plan.Count, $otisli.Count)
$plan | Format-Table DisplayName, UPN, Department, UsageLocation, Nadredjeni -AutoSize | Out-Host
foreach ($o in $otisli) {
    Write-Host ("PRESKACEM, odlazak {0}: {1} {2}" -f $o.DatumOdlaska, $o.Ime, $o.Prezime) -ForegroundColor Yellow
}
Write-Host "`nGrupe po odjelima:" -ForegroundColor Cyan
foreach ($o in $odjeli) { Write-Host ("  GRP-Odjel-{0}   pravilo: user.department -eq `"{0}`"" -f $o) }
Write-Host "  GRP-Licenca-BusinessPremium   pravilo: companyName = $Tvrtka i racun omogucen"
Write-Host "Uloge: Dario Novak -> Global Reader, Billing Administrator"

if (-not $Izvrsi) {
    Write-Host "`nOvo je bio samo plan, nista nije promijenjeno. Za izvrsenje: .\L00-kreiraj-korisnike.ps1 -Izvrsi" -ForegroundColor Green
    return
}

# Potvrda prije promjena, kao kod terraform apply: prihvaca se samo tocno DA
$odgovor = Read-Host "`nOvo mijenja tenant $Domena. Za nastavak upisi DA"
if ($odgovor -cne 'DA') {
    Write-Host 'Prekinuto. Nista nije promijenjeno.' -ForegroundColor Yellow
    return
}

# ---------------------------------------------------------------------------
# 4. Spajanje na Microsoft Graph
# ---------------------------------------------------------------------------
$potrebniModuli = 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Users', 'Microsoft.Graph.Groups',
                  'Microsoft.Graph.Identity.DirectoryManagement', 'Microsoft.Graph.Identity.Governance'
foreach ($m in $potrebniModuli) {
    if (-not (Get-Module -ListAvailable -Name $m)) { throw "Nedostaje modul $m. Instaliraj: Install-Module $m -Scope CurrentUser" }
}

$opsezi = @(
    'User.ReadWrite.All',                  # kreiranje korisnika i nadredjenih
    'Group.ReadWrite.All',                 # kreiranje grupa
    'Directory.ReadWrite.All',             # dodjela licence grupi
    'RoleManagement.ReadWrite.Directory',  # dodjela administratorskih uloga
    'Organization.Read.All'                # citanje pretplata (SKU)
)
Connect-MgGraph -TenantId $Domena -Scopes $opsezi -NoWelcome

# Zastita od pokretanja na krivom tenantu
$ctx = Get-MgContext
if ($ctx.Account -notlike "*@$Domena") {
    Disconnect-MgGraph | Out-Null
    throw "Spojen si kao '$($ctx.Account)', a skripta je za $Domena. Prekidam bez promjena."
}
Write-Host "Spojen kao $($ctx.Account)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. Korisnici
# ---------------------------------------------------------------------------
$idPoImenu = @{}
$lozinke = [System.Collections.Generic.List[object]]::new()

foreach ($k in $plan) {
    $postojeci = Get-MgUser -Filter "userPrincipalName eq '$($k.UPN)'" -Property Id, UserPrincipalName
    if ($postojeci) {
        Write-Host "Postoji, preskacem: $($k.UPN)"
        $idPoImenu[$k.DisplayName] = $postojeci.Id
        continue
    }
    $lozinka = New-PrivremenaLozinka
    $novi = New-MgUser -AccountEnabled `
        -DisplayName $k.DisplayName -GivenName $k.GivenName -Surname $k.Surname `
        -UserPrincipalName $k.UPN -MailNickname $k.MailNickname `
        -JobTitle $k.JobTitle -Department $k.Department -OfficeLocation $k.Office `
        -CompanyName $Tvrtka -UsageLocation $k.UsageLocation `
        -PasswordProfile @{ Password = $lozinka; ForceChangePasswordNextSignIn = $true }
    $idPoImenu[$k.DisplayName] = $novi.Id
    $lozinke.Add([pscustomobject]@{ UPN = $k.UPN; PrivremenaLozinka = $lozinka })
    Write-Host "Kreiran: $($k.UPN)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 6. Nadredjeni
# ---------------------------------------------------------------------------
foreach ($k in ($plan | Where-Object Nadredjeni)) {
    $sefId = $idPoImenu[$k.Nadredjeni]
    if (-not $sefId) { Write-Warning "Nadredjeni '$($k.Nadredjeni)' za $($k.DisplayName) nije medju aktivnima."; continue }
    Set-MgUserManagerByRef -UserId $idPoImenu[$k.DisplayName] -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$sefId" }
}
Write-Host "Nadredjeni postavljeni." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 7. Dinamicke grupe
# ---------------------------------------------------------------------------
function New-DinamickaGrupa {
    param([string]$Ime, [string]$Nadimak, [string]$Pravilo, [string]$Opis)
    $postoji = Get-MgGroup -Filter "displayName eq '$Ime'"
    if ($postoji) { Write-Host "Grupa postoji, preskacem: $Ime"; return $postoji }
    $g = New-MgGroup -DisplayName $Ime -Description $Opis `
        -MailEnabled:$false -MailNickname $Nadimak -SecurityEnabled `
        -GroupTypes @('DynamicMembership') `
        -MembershipRule $Pravilo -MembershipRuleProcessingState 'On'
    Write-Host "Kreirana grupa: $Ime" -ForegroundColor Green
    return $g
}

foreach ($o in $odjeli) {
    $null = New-DinamickaGrupa -Ime "GRP-Odjel-$o" -Nadimak ('grp-odjel-' + (ConvertTo-Slug $o)) `
        -Pravilo "(user.department -eq `"$o`")" `
        -Opis "Zaposlenici odjela $o. Dinamicka grupa iz atributa department."
}

$grpLicenca = New-DinamickaGrupa -Ime 'GRP-Licenca-BusinessPremium' -Nadimak 'grp-licenca-bp' `
    -Pravilo "(user.companyName -eq `"$Tvrtka`") -and (user.accountEnabled -eq true)" `
    -Opis 'Svi aktivni zaposlenici. Grupi je dodijeljena licenca Business Premium.'

# ---------------------------------------------------------------------------
# 8. Licenca preko grupe
# ---------------------------------------------------------------------------
$sku = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq 'SPB' -and $_.CapabilityStatus -eq 'Enabled' } | Select-Object -First 1
if (-not $sku) {
    Get-MgSubscribedSku | Format-Table SkuPartNumber, CapabilityStatus, ConsumedUnits -AutoSize | Out-Host
    throw 'Ne nalazim aktivnu licencu SPB (Business Premium). Posalji mi tablicu iznad.'
}
$null = Set-MgGroupLicense -GroupId $grpLicenca.Id -AddLicenses @(@{ SkuId = $sku.SkuId }) -RemoveLicenses @()
Write-Host "Licenca Business Premium dodijeljena grupi $($grpLicenca.DisplayName)." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 9. Darijeve uloge
# ---------------------------------------------------------------------------
$darioId = $idPoImenu['Dario Novak']
foreach ($uloga in 'Global Reader', 'Billing Administrator') {
    $def = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$uloga'"
    $vec = Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$darioId'" |
           Where-Object RoleDefinitionId -eq $def.Id
    if ($vec) { Write-Host "Dario vec ima ulogu: $uloga"; continue }
    $null = New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $darioId -RoleDefinitionId $def.Id -DirectoryScopeId '/'
    Write-Host "Dariju dodijeljena uloga: $uloga" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 10. Privremene lozinke i odjava
# ---------------------------------------------------------------------------
if ($lozinke.Count -gt 0) {
    $lozinke | Export-Csv -Path $LozinkeIzlaz -NoTypeInformation -Encoding utf8 -Append
    Write-Host "Privremene lozinke spremljene u: $LozinkeIzlaz" -ForegroundColor Yellow
    Write-Host "To je tajna: ne salji je u chat i obrisi datoteku kad zatvoris L00." -ForegroundColor Yellow
}
Disconnect-MgGraph | Out-Null
Write-Host "`nGotovo. Dinamickim grupama treba nekoliko minuta da se napune." -ForegroundColor Cyan
