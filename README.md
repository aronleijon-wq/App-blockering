# Paus

En iPhone-app som blockerar sociala medier och andra appar som stjäl tid. "Paus" är ett arbetsnamn.

## Funktioner

- **Fokuspass**: blockera de valda apparna direkt i 25, 50 eller 90 minuter. Med *strikt fokus* går passet inte att avbryta.
- **Scheman**: automatisk blockering vissa dagar och tider, till exempel vardagar 08–15 eller varje kväll 22–07.
- **Daglig gräns**: när du har använt apparna en viss tid under dagen blockeras de till midnatt.
- **Medvetna pauser**: behöver du ändå in kan du ta en kort paus. Först måste du andas en stund, och antalet pauser per dag är begränsat.
- **Egen spärrskärm** på svenska med knapparna *Stäng* och *Ta en paus*.

Appen använder Apples Skärmtid-ramverk (FamilyControls, ManagedSettings och DeviceActivity). Blockeringen sköts alltså av iOS och fungerar även när Paus inte är öppen.

## Kom igång i Xcode

1. Klona repot i Xcode (*Integrate → Clone…* eller startfönstret):
   `https://github.com/aronleijon-wq/App-blockering.git`
2. Öppna `Paus.xcodeproj`.
3. Välj projektet **Paus** i listan till vänster. Gå till *Build Settings* och sök på `PAUS_BUNDLE_PREFIX`. Byt `se.aronleijon.paus` till ett eget id om Xcode säger att det är upptaget. App Group och alla bundle-id:n byggs från det värdet.
4. För var och en av de fyra targets (**Paus**, **PausMonitor**, **PausShieldConfiguration** och **PausShieldAction**) går du till *Signing & Capabilities* och väljer ditt Team.
5. Anslut din iPhone, välj den som mål och tryck på ▶︎.

**Viktigt:**
- Skärmtid-funktionerna fungerar inte i simulatorn. Testa på en riktig iPhone.
- Capability-en *Family Controls* kräver ett betalt Apple Developer-konto (99 USD/år). För att publicera i App Store måste du dessutom ansöka hos Apple om distributionsrätt för Family Controls, för appen och alla tre tillägg.

## Projektstruktur

| Mapp | Innehåll |
| --- | --- |
| `Paus/` | Själva appen: SwiftUI-vyer och `AppModel` |
| `Shared/` | Kod som både appen och tilläggen använder: lagring i App Group, sköld och schemaläggning |
| `PausCore/` | Ren logik för scheman, regler och pauser, med enhetstester (`swift test`) |
| `PausMonitor/` | DeviceActivity-tillägg som startar och stoppar blockeringen när ett schema, ett fokuspass eller en paus börjar eller slutar |
| `PausShieldConfiguration/` | Utseendet på spärrskärmen |
| `PausShieldAction/` | Vad knapparna på spärrskärmen gör |
| `Config/` | Info.plist och entitlements för varje target |

All logik som avgör *om* något ska blockeras finns i `BlockEngine`, som appen och tilläggen delar. Varje händelse (ett schema börjar, en paus tar slut, gränsen nås och så vidare) uppdaterar det delade tillståndet och anropar sedan `ShieldController.refresh()`.

## Tester och CI

GitHub Actions kör enhetstesterna för `PausCore` och bygger appen med alla tillägg, utan signering, på varje push (`.github/workflows/ios.yml`). Lokalt:

```sh
cd PausCore && swift test
```

## Kända begränsningar

- Om man avinstallerar appen försvinner blockeringen. Det kan iOS inte förhindra, men en Skärmtid-kod under Inställningar gör det svårare.
- Pausknappen på spärrskärmen kan inte öppna appen direkt, eftersom iOS inte tillåter det. Den skickar i stället en notis som öppnar Paus.
- På iOS före 17.4 kan en ändrad daglig gräns börja räkna om från noll för resten av dagen.
