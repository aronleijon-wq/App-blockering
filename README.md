# Paus

En iPhone-app som blockerar sociala medier och andra appar som stjäl tid. "Paus" är ett arbetsnamn.

## Funktioner

- **Pip**: en animerad maskot vars humör följer vad du gör. Den är zen under fokus, sömnig sent på kvällen, peppad när streaken lever och lite ledsen när gränsen är slut. Pip får nya prylar på nivå 3, 6 och 8.
- **XP och nivåer**: från *Scrollzombie* till *Legend*. Du får XP för fokuspass (1 per minut + bonus), för att stänga en blockerad app, för att tacka nej till en paus och för att hålla dig under den dagliga gränsen.
- **Dagens belöning och streak**: en belöning per dag som växer med streaken. En påminnelse kl. 18.30 ser till att streaken inte bryts.
- **Dagliga uppdrag**: tre nya uppdrag varje dag.
- **Troféer**: elva troféer att låsa upp.
- **Fokuspass, scheman, daglig gräns och medvetna pauser** som blockerar via iOS Skärmtid, även när appen är stängd.
- **Paus Pro (19 kr/mån, 7 dagar gratis)**: obegränsade scheman, daglig gräns, strikt fokus och en AI-coach. Pip skriver då personliga meddelanden med Apple Intelligence direkt i telefonen, där det finns. Gratisversionen har fokuspass, ett schema, pauser och hela spelsystemet.
- **Egen spärrskärm** på svenska: "Pip säger nej till TikTok", där *Stäng* ger XP.

Appen använder Apples Skärmtid-ramverk (FamilyControls, ManagedSettings och DeviceActivity), StoreKit 2 och, på iOS 26, Foundation Models.

## Kom igång i Xcode

1. Klona repot i Xcode (*Integrate → Clone…* eller startfönstret):
   `https://github.com/aronleijon-wq/App-blockering.git`
2. Öppna `Paus.xcodeproj`.
3. Välj projektet **Paus** i listan till vänster. Gå till *Build Settings* och sök på `PAUS_BUNDLE_PREFIX`. Byt `se.aronleijon.paus` till ett eget id om Xcode säger att det är upptaget. App Group och alla bundle-id:n byggs från det värdet.
4. För var och en av de fyra targets (**Paus**, **PausMonitor**, **PausShieldConfiguration** och **PausShieldAction**) går du till *Signing & Capabilities* och väljer ditt Team.
5. Anslut din iPhone, välj den som mål och tryck på ▶︎.
6. Testa prenumerationen utan riktiga pengar: gå till *Product → Scheme → Edit Scheme… → Run → Options* och välj `Paus.storekit` under *StoreKit Configuration*.

**Inför App Store:** skapa en automatiskt förnyad prenumeration med produkt-id `paus.pro.monthly` i App Store Connect. Sätt priset till 19 kr/mån och lägg till ett introduktionserbjudande med 7 dagar gratis.

**Viktigt:**
- Skärmtid-funktionerna fungerar inte i simulatorn. Testa på en riktig iPhone.
- Capability-en *Family Controls* kräver ett betalt Apple Developer-konto (99 USD/år). För att publicera i App Store måste du dessutom ansöka hos Apple om distributionsrätt för Family Controls, för appen och alla tre tillägg.

## Projektstruktur

| Mapp | Innehåll |
| --- | --- |
| `Paus/` | Själva appen: SwiftUI-vyer och `AppModel` |
| `Shared/` | Kod som både appen och tilläggen använder: lagring i App Group, sköld och schemaläggning |
| `Paus/Design/` | Färger, knappstilar, maskoten Pip och konfetti |
| `PausCore/` | Ren logik för scheman, regler, pauser, XP, nivåer, uppdrag och troféer, med enhetstester (`swift test`) |
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
