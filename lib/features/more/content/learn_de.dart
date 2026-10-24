import 'learn_content.dart';

/// German text of the Learn, About and Help pages.
const learnDe = LearnContent(
  glossary: [
    Article(
      'Download',
      'Wie schnell Daten bei dir ankommen: Webseiten, Videos, Dateien. Gemessen in Megabit pro Sekunde (Mbit/s).',
    ),
    Article(
      'Upload',
      'Wie schnell du Daten sendest: Videoanrufe, Cloud-Backups, Fotos und Dateien hochladen.',
    ),
    Article(
      'Ping',
      'Die Zeit, die eine kleine Nachricht zum Server und zurück braucht, in Millisekunden. Je niedriger, desto reaktionsschneller fühlen sich Spiele und Anrufe an.',
    ),
    Article(
      'Jitter',
      'Wie stark der Ping von Moment zu Moment schwankt. Hoher Jitter macht Anrufe abgehackt, selbst wenn der durchschnittliche Ping gut ist.',
    ),
    Article(
      'Latenz unter Last',
      'Wie stark der Ping steigt, während die Leitung ausgelastet ist. Ein starker Anstieg – „Bufferbloat“ – ist der Grund, warum ein Spiel ruckelt, sobald jemand einen Download startet.',
    ),
    Article(
      'Mbit/s',
      'Megabit pro Sekunde. Acht Megabit ergeben ein Megabyte, 100 Mbit/s übertragen also etwa 12,5 Megabyte pro Sekunde.',
    ),
    Article(
      'Paketverlust',
      'Der Anteil der Datenpakete, die nie ankommen. Schon 1–2 % führen zu Aussetzern bei Anrufen und Spielen.',
    ),
    Article(
      'Anbieter (ISP)',
      'Das Unternehmen, das dich mit dem Internet verbindet.',
    ),
    Article(
      'Drosselung',
      'Wenn ein Anbieter bestimmten Datenverkehr, etwa Videos, absichtlich verlangsamt, während alles andere schnell bleibt.',
    ),
  ],
  guides: [
    Article(
      'Ein genaues Ergebnis erzielen',
      'Pausiere Downloads und Streaming auf allen Geräten im Haus, nutze wenn möglich ein Kabel oder setz dich nah an den Router und führe den Test zwei- oder dreimal aus. Das typische Ergebnis sagt mehr als ein einzelner Glückstreffer.',
    ),
    Article(
      'WLAN oder Leitung?',
      'Teste einmal per Kabel und einmal per WLAN am selben Ort. Ist das Kabel deutlich schneller, liegt der Engpass im Funk: Geh näher an den Router, wechsle ins 5-GHz-Netz oder prüfe das Signal in der Nova-App.',
    ),
    Article(
      'Wie viel Geschwindigkeit brauche ich?',
      'Web und Social Media brauchen etwa 5 Mbit/s, HD-Video 5–8, 4K-Video 25 und ein Videoanruf 3–4 in jede Richtung. Bei Online-Spielen zählt der Ping mehr als die Geschwindigkeit – unter 50 ms fühlt sich gut an. Zu Hause addiert sich der Bedarf: Drei Personen, die gleichzeitig streamen, brauchen das Dreifache.',
    ),
    Article(
      'Die Note für Latenz unter Last lesen',
      'A oder B: Die Verbindung bleibt auch unter Last reaktionsschnell. C oder D: Die Verzögerung springt, sobald jemand etwas herunterlädt. Oft hilft es, „SQM“ oder „Smart Queue“ in den Router-Einstellungen einzuschalten.',
    ),
  ],
  faq: [
    Article(
      'Warum ist mein Ergebnis niedriger als mein Tarif?',
      'Tarife nennen den Höchstwert. WLAN, andere Geräte, die Entfernung zum Server und abendliche Auslastung nehmen sich ihren Anteil. Ein Test per Kabel zeigt, was die Leitung selbst liefert.',
    ),
    Article(
      'Warum zeigen Speedtests unterschiedliche Werte?',
      'Jeder nutzt eigene Server und eine eigene Methode. Nova misst gegen Cloudflare über vier parallele Verbindungen – das kommt dem Verhalten großer Downloads nahe.',
    ),
    Article(
      'Wie viel Datenvolumen verbraucht ein Test?',
      'Ungefähr die Geschwindigkeit mal sechzehn Sekunden: etwa 200 MB bei einer 100-Mbit/s-Leitung, bei schnelleren mehr. Denk daran bei mobilen Daten.',
    ),
    Article(
      'Werden meine Ergebnisse irgendwohin gesendet?',
      'Nein. Verlauf und Einstellungen bleiben auf deinem Gerät. Die Seite „Datenschutz“ listet genau auf, mit wem Nova kommuniziert.',
    ),
    Article(
      'Warum kann die Browser-Version weniger?',
      'Ein Browser kann keine systemweiten Datenzähler lesen, das lokale Netzwerk nicht scannen und keine WLAN-Details sehen. Die App kann das – unter Windows, macOS und Android.',
    ),
    Article(
      'Ist Nova kostenlos?',
      'Ja, vollständig. Nova ist Open Source unter der MIT-Lizenz.',
    ),
  ],
  about: 'Nova ist ein kostenloser Open-Source-Begleiter für dein Netzwerk: ein genauer Speedtest und ein Live-Datenmonitor in einer App. Neben der reinen Geschwindigkeit misst Nova, was darüber entscheidet, wie sich eine Verbindung anfühlt – Latenz unter Last, Jitter und Stabilität. Läuft unter Windows, macOS und Android, und der Speedtest funktioniert auch direkt im Browser.',
  privacy: [
    Article(
      'Bleibt auf deinem Gerät',
      'Testergebnisse, Verlauf, Einstellungen und Datenstatistiken werden nur auf deinem Gerät gespeichert. Nova hat keinen eigenen Server, der sie sammelt.',
    ),
    Article(
      'Mit wem Nova kommuniziert',
      'Der Speedtest tauscht Daten mit den Speedtest-Servern von Cloudflare aus. Um Anbieter und Stadt anzuzeigen, fragt Nova den Dienst ipwho.is, der deine IP-Adresse sieht. Die Drosselungsprüfung nutzt fast.com von Netflix, der Ping zu Diensten kontaktiert YouTube, Google, Discord, Steam, Cloudflare und Telegram. Der Netzwerkscan spricht nur mit Geräten in deinem lokalen Netzwerk. Die Browser-Version liegt auf GitHub Pages und lädt ihre Grafik-Engine von Googles gstatic.com.',
    ),
    Article(
      'Die Rangliste',
      'Vorerst läuft sie mit Beispieldaten innerhalb der App, und nichts wird veröffentlicht. Sobald die Online-Rangliste startet, werden nur dein Spitzname, dein Land, dein Anbieter und dein Bestergebnis geteilt – niemals dein Name oder deine E-Mail.',
    ),
    Article(
      'Kein Tracking',
      'Keine Werbung, keine Analyse, keine Tracker.',
    ),
  ],
  help: [
    Article(
      'Einen Test starten',
      'Tippe auf „Test starten“. Nova misst zuerst den Ping, dann Download und Upload – insgesamt etwa zwanzig Sekunden.',
    ),
    Article(
      'Der Test schlägt fehl',
      'Prüfe deine Verbindung und versuche es erneut. Ein VPN oder eine Firewall, die Cloudflare blockiert, verhindert, dass der Test seinen Server erreicht.',
    ),
    Article(
      'Warnung beim ersten Start',
      'Nova ist mit einem eigenen Schlüssel signiert statt mit einem kostenpflichtigen Apple- oder Microsoft-Zertifikat. Windows: „Weitere Informationen“ → „Trotzdem ausführen“. macOS: Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen“. Android: „Trotzdem installieren“.',
    ),
    Article(
      'Etwas stimmt nicht',
      'Melde es auf GitHub – der Button unten öffnet die Seite für Problemmeldungen.',
    ),
  ],
  reportButton: 'Problem melden',
);
