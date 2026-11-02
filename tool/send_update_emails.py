#!/usr/bin/env python3
"""Emails Nova's update subscribers that a new version is out.

Run by .github/workflows/update-emails.yml after each release. Reads the
Firestore collection `subscribers` (people who switched on "Email me when a
new version is out" in Nova) over REST, using the workflow's short-lived
Google access token, and sends each one a plain email in their language
through Gmail's SMTP server. The log only ever counts: no address is
printed.

Environment:
  VERSION           the release, "v1.4.0" or "1.4.0"
  ACCESS_TOKEN      Google OAuth token allowed to read Firestore
  FIREBASE_PROJECT  the Firebase project id
  SMTP_USER         the Gmail address the emails come from
  SMTP_PASSWORD     an app password for that address
  TEST_ADDRESS      optional: send one email there instead of to subscribers
  TEST_LANG         optional: its language (default en)
  DRY_RUN           optional: "1" prints the emails instead of sending them
"""

import json
import os
import smtplib
import ssl
import sys
import time
import urllib.parse
import urllib.request
from email.message import EmailMessage
from email.utils import formataddr, make_msgid

REPO = "https://github.com/Mammad-Ali/nova"
WEB = "https://mammad-ali.github.io/nova/"

# Gmail stops an ordinary account at 500 messages a day; stay well under it.
DAILY_LIMIT = 450

TEXT = {
    "en": (
        "Nova {version} is out",
        """Hi,

Nova {version} is ready to download:

  Windows  {windows}
  macOS    {macos}
  Android  {android}

What's new: {notes}
Or use it right in your browser: {web}

Installing over the version you have keeps your history and settings.

You're getting this because you asked for it in Nova. To stop, open Nova,
click or tap your name at the top right and switch off "Email me when a
new version is out".

— Nova
""",
    ),
    "az": (
        "Nova {version} çıxdı",
        """Salam,

Nova {version} yükləməyə hazırdır:

  Windows  {windows}
  macOS    {macos}
  Android  {android}

Nə yenidir: {notes}
Və ya birbaşa brauzerdə istifadə edin: {web}

Mövcud versiyanın üzərinə quraşdırsanız, tarixçə və ayarlar qalacaq.

Bu məktubu Nova-da özünüz istədiyiniz üçün alırsınız. Dayandırmaq üçün
Nova-nı açın, yuxarı sağda adınıza klikləyin və "Yeni versiya çıxanda
mənə e-poçt göndər" seçimini söndürün.

— Nova
""",
    ),
    "ru": (
        "Вышла Nova {version}",
        """Здравствуйте!

Nova {version} готова к загрузке:

  Windows  {windows}
  macOS    {macos}
  Android  {android}

Что нового: {notes}
Или пользуйтесь прямо в браузере: {web}

Если установить поверх текущей версии, история и настройки сохранятся.

Вы получили это письмо, потому что попросили об этом в Nova. Чтобы
отписаться, откройте Nova, нажмите на своё имя вверху справа и выключите
«Сообщать на почту о новых версиях».

— Nova
""",
    ),
    "de": (
        "Nova {version} ist da",
        """Hallo,

Nova {version} steht zum Download bereit:

  Windows  {windows}
  macOS    {macos}
  Android  {android}

Was ist neu: {notes}
Oder nutze Nova direkt im Browser: {web}

Wenn du über deine jetzige Version installierst, bleiben Verlauf und
Einstellungen erhalten.

Du bekommst diese E-Mail, weil du sie in Nova angefordert hast. Zum
Abbestellen öffne Nova, klicke oder tippe oben rechts auf deinen Namen und
schalte „Mir eine E-Mail schicken, wenn eine neue Version da ist" aus.

— Nova
""",
    ),
    "hu": (
        "Megjelent a Nova {version}",
        """Szia!

A Nova {version} letölthető:

  Windows  {windows}
  macOS    {macos}
  Android  {android}

Újdonságok: {notes}
Vagy használd közvetlenül a böngészőben: {web}

Ha a meglévő verzió fölé telepíted, az előzmények és a beállítások
megmaradnak.

Azért kaptad ezt a levelet, mert a Novában kérted. A leiratkozáshoz nyisd
meg a Novát, kattints vagy koppints jobb felül a nevedre, és kapcsold ki a
„Küldj e-mailt, ha új verzió jelenik meg" beállítást.

— Nova
""",
    ),
}


def compose(sender: str, to: str, lang: str, version: str) -> EmailMessage:
    subject, body = TEXT.get(lang, TEXT["en"])
    links = {
        "windows": f"{REPO}/releases/latest/download/Nova-Windows-Setup.exe",
        "macos": f"{REPO}/releases/latest/download/Nova-macOS.dmg",
        "android": f"{REPO}/releases/latest/download/Nova-Android.apk",
        "notes": f"{REPO}/releases/tag/v{version}",
        "web": WEB,
    }
    msg = EmailMessage()
    msg["From"] = formataddr(("Nova", sender))
    msg["To"] = to
    msg["Subject"] = subject.format(version=version)
    msg["Message-ID"] = make_msgid(domain=sender.split("@")[-1])
    msg.set_content(body.format(version=version, **links))
    return msg


def subscribers(project: str, token: str) -> list[tuple[str, str]]:
    """(address, language) of everyone on the list, every page of it."""
    base = (
        f"https://firestore.googleapis.com/v1/projects/{project}"
        "/databases/(default)/documents/subscribers"
    )
    found, page = [], None
    while True:
        query = {"pageSize": "300"}
        if page:
            query["pageToken"] = page
        request = urllib.request.Request(
            f"{base}?{urllib.parse.urlencode(query)}",
            headers={"Authorization": f"Bearer {token}"},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.load(response)
        for doc in data.get("documents", []):
            fields = doc.get("fields", {})
            address = fields.get("email", {}).get("stringValue")
            lang = fields.get("lang", {}).get("stringValue", "en")
            if address:
                found.append((address, lang))
        page = data.get("nextPageToken")
        if not page:
            return found


def main() -> int:
    version = os.environ["VERSION"].removeprefix("v")
    sender = os.environ.get("SMTP_USER", "nova@example.com")
    dry_run = os.environ.get("DRY_RUN") == "1"
    test_address = os.environ.get("TEST_ADDRESS", "").strip()

    if test_address:
        recipients = [(test_address, os.environ.get("TEST_LANG", "en"))]
    else:
        recipients = subscribers(os.environ["FIREBASE_PROJECT"], os.environ["ACCESS_TOKEN"])
    print(f"Nova {version}: {len(recipients)} recipient(s)")
    if len(recipients) > DAILY_LIMIT:
        print(f"Only the first {DAILY_LIMIT} are sent today (Gmail's daily limit).")
        recipients = recipients[:DAILY_LIMIT]

    if dry_run:
        for address, lang in recipients:
            print("-" * 60)
            print(compose(sender, "<recipient>", lang, version))
        return 0

    sent = failed = 0
    with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=ssl.create_default_context()) as smtp:
        smtp.login(sender, os.environ["SMTP_PASSWORD"])
        for address, lang in recipients:
            try:
                smtp.send_message(compose(sender, address, lang, version))
                sent += 1
            except smtplib.SMTPException as error:
                failed += 1
                print(f"one email failed: {type(error).__name__}")
            time.sleep(1)  # an even pace keeps Gmail's spam checks calm
    print(f"sent {sent}, failed {failed}")
    return 1 if failed and not sent else 0


if __name__ == "__main__":
    sys.exit(main())
