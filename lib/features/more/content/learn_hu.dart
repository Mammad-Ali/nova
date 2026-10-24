import 'learn_content.dart';

/// Hungarian text of the Learn, About and Help pages.
const learnHu = LearnContent(
  glossary: [
    Article(
      'Letöltés',
      'Milyen gyorsan érkeznek hozzád az adatok: weboldalak, videók, fájlok. Megabit per másodpercben (Mbit/s) mérjük.',
    ),
    Article(
      'Feltöltés',
      'Milyen gyorsan küldesz adatot: videohívások, felhőmentések, fotók és fájlok feltöltése.',
    ),
    Article(
      'Ping',
      'Az idő, amíg egy apró üzenet eljut a szerverig és vissza, ezredmásodpercben. Minél kisebb, annál gördülékenyebb a játék és a hívás.',
    ),
    Article(
      'Jitter',
      'Mennyire ingadozik a ping pillanatról pillanatra. A magas jitter akadozóvá teszi a hívásokat, még ha az átlagos ping rendben is van.',
    ),
    Article(
      'Késleltetés terhelés alatt',
      'Mennyivel nő a ping, amíg a vonal terhelt. A nagy növekedés – „bufferbloat” – az oka annak, hogy a játék akadozni kezd, amint valaki letöltésbe kezd.',
    ),
    Article(
      'Mbit/s',
      'Megabit per másodperc. Nyolc megabit egy megabájt, így 100 Mbit/s nagyjából 12,5 megabájtot visz át másodpercenként.',
    ),
    Article(
      'Csomagvesztés',
      'Azoknak az adatcsomagoknak az aránya, amelyek sosem érkeznek meg. Már 1–2% is akadozást okoz hívásokban és játékokban.',
    ),
    Article(
      'Szolgáltató (ISP)',
      'A cég, amely az internetre kapcsol.',
    ),
    Article(
      'Lassítás (throttling)',
      'Amikor a szolgáltató szándékosan lassít bizonyos forgalmat, például a videót, miközben minden más gyors marad.',
    ),
  ],
  guides: [
    Article(
      'Pontos eredmény elérése',
      'Állítsd le a letöltéseket és a streamelést minden otthoni eszközön, ha lehet, használj kábelt vagy ülj közel a routerhez, majd futtasd le a tesztet két-háromszor. A jellemző eredmény többet mond egyetlen szerencsés mérésnél.',
    ),
    Article(
      'A Wi-Fi vagy a vonal?',
      'Tesztelj egyszer kábellel és egyszer Wi-Fi-n ugyanott. Ha kábellel sokkal gyorsabb, a szűk keresztmetszet a vezeték nélküli kapcsolat: menj közelebb a routerhez, válts az 5 GHz-es hálózatra, vagy nézd meg a jelet a Nova alkalmazásban.',
    ),
    Article(
      'Mekkora sebesség kell?',
      'Weboldalakhoz és közösségi médiához kb. 5 Mbit/s elég, HD videóhoz 5–8, 4K videóhoz 25, videohíváshoz irányonként 3–4. Az online játékoknál a ping fontosabb a sebességnél – 50 ms alatt kellemes. Otthon az igények összeadódnak: ha hárman streamelnek egyszerre, háromszor annyi kell.',
    ),
    Article(
      'A terhelés alatti késleltetés értékelése',
      'A vagy B: a kapcsolat terhelés alatt is gyorsan reagál. C vagy D: a késleltetés megugrik, amint valaki letölt valamit. Gyakran segít, ha a router beállításaiban bekapcsolod az „SQM” vagy „Smart Queue” funkciót.',
    ),
  ],
  faq: [
    Article(
      'Miért kisebb az eredmény, mint az előfizetésem?',
      'Az előfizetés a maximumot adja meg. A Wi-Fi, a többi eszköz, a szerver távolsága és az esti csúcsidő mind elvesz belőle. A kábeles teszt mutatja meg, mit tud maga a vonal.',
    ),
    Article(
      'Miért mutatnak mást a különböző sebességmérők?',
      'Mindegyik saját szervereket és módszert használ. A Nova a Cloudflare-hez mér négy párhuzamos kapcsolaton – ez közel áll ahhoz, ahogy a nagy letöltések viselkednek.',
    ),
    Article(
      'Mennyi adatot fogyaszt egy teszt?',
      'Nagyjából a sebesség szorozva tizenhat másodperccel: 100 Mbit/s-os vonalon kb. 200 MB, gyorsabbon több. Mobilneten érdemes erre figyelni.',
    ),
    Article(
      'Elküldik valahová az eredményeimet?',
      'Nem. Az előzmények és a beállítások az eszközödön maradnak. Az Adatvédelem oldal pontosan felsorolja, kivel kommunikál a Nova.',
    ),
    Article(
      'Miért tud kevesebbet a böngészős változat?',
      'A böngésző nem olvashatja a rendszer forgalomszámlálóit, nem vizsgálhatja át a helyi hálózatot, és nem látja a Wi-Fi adatait. Az alkalmazás igen – Windowson, macOS-en és Androidon.',
    ),
    Article(
      'Ingyenes a Nova?',
      'Igen, teljesen. A Nova nyílt forráskódú, MIT-licenc alatt.',
    ),
  ],
  about: 'A Nova ingyenes, nyílt forráskódú hálózati segéd: pontos sebességmérő és élő forgalomfigyelő egy alkalmazásban. A puszta sebességen túl azt is méri, ami eldönti, milyennek érezzük a kapcsolatot – a terhelés alatti késleltetést, a jittert és a stabilitást. Windowson, macOS-en és Androidon fut, a sebességmérés pedig közvetlenül a böngészőben is működik.',
  privacy: [
    Article(
      'Az eszközödön marad',
      'A teszteredmények, az előzmények, a beállítások és a forgalmi statisztikák csak az eszközödön tárolódnak. A Novának nincs saját szervere, amely gyűjtené őket.',
    ),
    Article(
      'Kivel kommunikál a Nova',
      'A sebességmérés a Cloudflare sebességmérő szervereivel cserél adatot. A szolgáltató és a város megjelenítéséhez a Nova az ipwho.is szolgáltatást kérdezi meg, amely látja az IP-címedet. A lassítás-ellenőrzés a Netflix fast.com szolgáltatását használja, a szolgáltatások pingje pedig a YouTube-ot, a Google-t, a Discordot, a Steamet, a Cloudflare-t és a Telegramot éri el. A hálózatkeresés csak a helyi hálózatod eszközeivel kommunikál. A böngészős változatot a GitHub Pages szolgálja ki, a grafikus motor pedig a Google gstatic.com oldaláról töltődik be.',
    ),
    Article(
      'A ranglista',
      'Egyelőre mintaadatokkal működik az alkalmazáson belül, és semmi sem kerül nyilvánosságra. Amikor elindul az online ranglista, csak a beceneved, az országod, a szolgáltatód és a legjobb eredményed lesz látható – a neved és az e-mail-címed soha.',
    ),
    Article(
      'Nincs követés',
      'Nincs reklám, nincs analitika, nincsenek nyomkövetők.',
    ),
  ],
  help: [
    Article(
      'Teszt indítása',
      'Nyomd meg a „Teszt indítása” gombot. A Nova először a pinget méri, aztán a letöltést és a feltöltést – összesen kb. húsz másodperc.',
    ),
    Article(
      'Nem sikerül a teszt',
      'Ellenőrizd a kapcsolatot, és próbáld újra. Ha VPN vagy tűzfal blokkolja a Cloudflare-t, a teszt nem éri el a szerverét.',
    ),
    Article(
      'Figyelmeztetés az első indításkor',
      'A Nova saját kulccsal van aláírva, nem fizetős Apple- vagy Microsoft-tanúsítvánnyal. Windows: „További információ” → „Futtatás mindenképp”. macOS: Rendszerbeállítások → Adatvédelem és biztonság → „Megnyitás mindenképp”. Android: „Telepítés mindenképp”.',
    ),
    Article(
      'Valami nem működik',
      'Jelezd a GitHubon – az alábbi gomb megnyitja a hibabejelentő oldalt.',
    ),
  ],
  reportButton: 'Hiba bejelentése',
);
