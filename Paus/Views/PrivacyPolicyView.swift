import SwiftUI

/// The privacy policy, kept in the app so it is always reachable. `PRIVACY.md` holds the same text for the web.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Senast uppdaterad 22 oktober 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                PolicySection(title: "Kort sagt") {
                    "Paus fungerar utan konto. Det mesta stannar på din telefon. Om du går med i ligan syns ditt smeknamn och dina poäng för andra spelare. Vi säljer aldrig data och använder ingen reklam eller spårning."
                }
                PolicySection(title: "Personuppgiftsansvarig") {
                    "\(AppInfo.developerName). Kontakt: \(AppInfo.supportEmail)."
                }
                PolicySection(title: "Det som bara finns på din telefon") {
                    "Dina regler, scheman, fokuspass, XP, nivå, streak, troféer, Pips hälsa, skälen du anger när du tar en paus och dina svar i introduktionen (förnamn, åldersgrupp, ungefärlig skärmtid, appar och mål) sparas bara lokalt på telefonen. Vilka appar du blockerar och hur länge du använder dem hanteras av Apples Skärmtid. Paus ser bara anonyma symboler för apparna, och den informationen lämnar aldrig telefonen. Skärmtidsrapporten räknas ut i ett tillägg som iOS stänger in, så siffrorna kan bara visas för dig och sparas eller skickas aldrig."
                }
                PolicySection(title: "Konto") {
                    "Du kan skapa ett konto med Logga in med Apple, men allt fungerar även utan. Apple ger då Paus en anonym identifierare och, om du väljer det, ditt namn och din e-post (som kan vara en dold vidarebefordringsadress). Paus har ingen server, så kontot sparas bara på din telefon och används för att Pip ska kunna hälsa på dig. Du loggar ut under Regler > Konto, och Radera all min data tar bort kontot. Du kan också sluta använda Logga in med Apple för Paus under Inställningar > [ditt namn] > Logga in med Apple."
                }
                PolicySection(title: "Ligan") {
                    "Om du väljer ett smeknamn och går med i ligan sparas följande i Apples iCloud-tjänst CloudKit: smeknamn, veckopoäng, nivå, division, ligagrupp, land och en anonym identifierare som iCloud skapar för appen. Uppgifterna syns för andra spelare i topplistorna. Ditt Apple-ID, namn eller e-post delas aldrig. Rättslig grund är att du själv valt att gå med (avtal). Uppgifterna finns kvar tills du lämnar ligan."
                }
                PolicySection(title: "Anmälningar") {
                    "Om någon anmäler ett smeknamn sparas smeknamnet och en anonym identifierare så att vi kan granska det. Olämpliga namn tas bort."
                }
                PolicySection(title: "Köp") {
                    "Prenumerationer hanteras helt av Apple. Vi får aldrig dina kortuppgifter. Du säger upp prenumerationen under Inställningar > [ditt namn] > Prenumerationer."
                }
                PolicySection(title: "Notiser") {
                    "Paus skickar påminnelser och pausnotiser lokalt från telefonen. Ingen notisdata skickas till oss."
                }
                PolicySection(title: "Dina rättigheter") {
                    "Du kan när som helst lämna ligan och radera ditt smeknamn under Liga, eller radera all din data under Regler > Radera all min data. Du har rätt att få veta vilka uppgifter vi har om dig, få dem rättade eller raderade, och att klaga hos Integritetsskyddsmyndigheten (IMY). Kontakta \(AppInfo.supportEmail) med frågor."
                }
                PolicySection(title: "Barn") {
                    "Paus riktar sig till dig som är 13 år eller äldre. Är du yngre, gå inte med i ligan utan att prata med en vuxen."
                }
                PolicySection(title: "Ändringar") {
                    "Om policyn ändras uppdaterar vi datumet ovan och berättar om viktiga ändringar i appen."
                }
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle("Integritetspolicy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PolicySection: View {
    let title: String
    let text: () -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
