# Paus

En iPhone-app som blockerar sociala medier och andra appar som stjäl tid. "Paus" är ett arbetsnamn.

## Funktioner

- **Pip**: en animerad maskot vars humör följer vad du gör. Den är zen under fokus, sömnig sent på kvällen, peppad när streaken lever och lite ledsen när gränsen är slut. Pip får nya prylar på nivå 3, 6 och 8.
- **XP och nivåer**: från *Scrollzombie* till *Legend*. Du får XP för fokuspass (1 per minut + bonus), för att stänga en blockerad app, för att tacka nej till en paus och för att hålla dig under den dagliga gränsen.
- **Dagens belöning och streak**: en belöning per dag som växer med streaken. En påminnelse kl. 18.30 ser till att streaken inte bryts.
- **Dagliga uppdrag**: tre nya uppdrag varje dag.
- **Troféer**: elva troféer att låsa upp.
- **Fokuspass, scheman, daglig gräns och medvetna pauser** som blockerar via iOS Skärmtid, även när appen är stängd.
- **Paus Pro (29 kr/mån eller 219 kr/år, 7 dagar gratis)**: obegränsade scheman, daglig gräns, strikt fokus och en AI-coach. Pip skriver då personliga meddelanden med Apple Intelligence direkt i telefonen, där det finns. Gratisversionen har fokuspass, ett schema, pauser och hela spelsystemet.
- **Egen spärrskärm** på svenska: "Pip säger nej till TikTok", där *Stäng* ger XP.
- **Liga**: veckopoäng och grupper om upp till 30 spelare per division (Brons → Silver → Guld → Diamant → Legend). De bästa i gruppen går upp och de sämsta åker ner. Det finns också topplistor för Sverige och världen. Man syns med smeknamn och kan anmäla eller blockera andra, och lämna ligan.

Appen använder Apples Skärmtid-ramverk (FamilyControls, ManagedSettings och DeviceActivity), StoreKit 2 och, på iOS 26, Foundation Models.

## Kom igång i Xcode

1. Klona repot i Xcode (*Integrate → Clone…* eller startfönstret):
   `https://github.com/aronleijon-wq/App-blockering.git`
2. Öppna `Paus.xcodeproj`.
3. Välj projektet **Paus** i listan till vänster. Gå till *Build Settings* och sök på `PAUS_BUNDLE_PREFIX`. Byt `se.aronleijon.paus` till ett eget id om Xcode säger att det är upptaget. App Group och alla bundle-id:n byggs från det värdet.
4. För var och en av de fyra targets (**Paus**, **PausMonitor**, **PausShieldConfiguration** och **PausShieldAction**) går du till *Signing & Capabilities* och väljer ditt Team.
5. Anslut din iPhone, välj den som mål och tryck på ▶︎.
6. Testa prenumerationen utan riktiga pengar: gå till *Product → Scheme → Edit Scheme… → Run → Options* och välj `Paus.storekit` under *StoreKit Configuration*.

**Ligan (CloudKit):**
1. Under *Signing & Capabilities* för target **Paus**, kontrollera att *iCloud* finns med, att *CloudKit* är ikryssat och att containern `iCloud.se.aronleijon.paus` är vald. Om den saknas: klicka på **+ Capability**, välj **iCloud** och skapa containern.
2. Kör appen och välj ett smeknamn i Liga-fliken, så skapas posttypen `Player` automatiskt i utvecklingsmiljön.
3. Öppna [CloudKit Console](https://icloud.developer.apple.com) → din container → *Schema* → *Indexes* → `Player`, och lägg till:
   - **Queryable:** `recordName`, `weekKey`, `groupID`, `division`, `country`
   - **Sortable:** `weeklyPoints`, `joinedAt`
4. Före lansering: *Deploy Schema Changes* till produktion.

Inskickade anmälningar sparas som posttypen `Report` och kan granskas i CloudKit Console.

**Inför App Store:** skapa två automatiskt förnyade prenumerationer i samma prenumerationsgrupp i App Store Connect: `paus.pro.yearly` för 219 kr/år och `paus.pro.monthly` för 29 kr/mån. Lägg till ett introduktionserbjudande med 7 dagar gratis på båda.

**Viktigt:**
- Skärmtid-funktionerna fungerar inte i simulatorn. Testa på en riktig iPhone.
- Capability-en *Family Controls* kräver ett betalt Apple Developer-konto (99 USD/år). För att publicera i App Store måste du dessutom ansöka hos Apple om distributionsrätt för Family Controls, för appen och alla tre tillägg.

## Integritet och moderering

- **Integritetspolicy** finns i appen (*Regler → Om och integritet*, på köpsidan och vid val av smeknamn) och som `PRIVACY.md` för webben.
- **Kontakt och ansvarig:** fyll i ditt namn och din supportadress i `Paus/AppInfo.swift`. Xcode visar en varning tills det är gjort. Lägg in samma uppgifter i `PRIVACY.md`.
- **Radera data:** *Lämna ligan* tar bort ligaposten, och *Radera all min data* tar bort allt (spärrat under strikt fokus).
- **Moderering:** anmälningar hamnar som `Report`-poster i CloudKit Console. Ta bort ett olämpligt namn genom att radera spelarens `Player`-post (id:t står i anmälan). Apple förväntar sig att anmälningar hanteras inom 24 timmar.
- **Integritetsmanifest:** `Shared/PrivacyInfo.xcprivacy` deklarerar UserDefaults och den data ligan samlar in.

## Lanseringschecklista

1. Fyll i `Paus/AppInfo.swift` och `PRIVACY.md`, och publicera `PRIVACY.md` på en webbadress (till exempel landningssidan).
2. Ansök om distributionsrätt för Family Controls för alla fyra bundle-id:n: <https://developer.apple.com/contact/request/family-controls-distribution>
3. CloudKit: lägg till index (se ovan) och *Deploy Schema Changes* till produktion.
4. App Store Connect: skapa appen, båda prenumerationerna, avtalet för betalappar, bank- och skatteuppgifter, och ansök om Small Business Program.
5. Fyll i *App Privacy*: User ID, Other User Content (smeknamn), Gameplay Content (poäng) och Coarse Location (land), alla kopplade till användaren, för appens funktion och inte för spårning.
6. Åldersgräns: svara att appen har användargenererat innehåll (smeknamn).
7. Ladda upp via *Product → Archive*, testa med TestFlight och skicka in för granskning.

## Projektstruktur

| Mapp | Innehåll |
| --- | --- |
| `Paus/` | Själva appen: SwiftUI-vyer och `AppModel` |
| `Shared/` | Kod som både appen och tilläggen använder: lagring i App Group, sköld och schemaläggning |
| `Paus/Design/` | Färger, knappstilar, maskoten Pip och konfetti |
| `PausCore/` | Ren logik för scheman, regler, pauser, XP, nivåer, uppdrag, troféer, ligapoäng och divisioner, med enhetstester (`swift test`) |
| `PausMonitor/` | DeviceActivity-tillägg som startar och stoppar blockeringen när ett schema, ett fokuspass eller en paus börjar eller slutar |
| `PausShieldConfiguration/` | Utseendet på spärrskärmen |
| `PausShieldAction/` | Vad knapparna på spärrskärmen gör |
| `Config/` | Info.plist och entitlements för varje target |

All logik som avgör *om* något ska blockeras finns i `BlockEngine`, som appen och tilläggen delar. Varje händelse (ett schema börjar, en paus tar slut, gränsen nås och så vidare) uppdaterar det delade tillståndet och anropar sedan `ShieldController.refresh()`.

## Tester och CI

GitHub Actions kör enhetstesterna för `PausCore` och bygger appen med alla tillägg, utan signering, på varje push (`.github/workflows/ios.yml`). Bygget körs både med standardversionen av Xcode och med den senaste, så att även koden för Apple Intelligence kompileras. Lokalt:

```sh
cd PausCore && swift test
```

## Kända begränsningar

- Om man avinstallerar appen försvinner blockeringen. Det kan iOS inte förhindra, men en Skärmtid-kod under Inställningar gör det svårare.
- Pausknappen på spärrskärmen kan inte öppna appen direkt, eftersom iOS inte tillåter det. Den skickar i stället en notis som öppnar Paus.
- På iOS före 17.4 kan en ändrad daglig gräns börja räkna om från noll för resten av dagen.
