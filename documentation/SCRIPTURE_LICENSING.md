# Scripture Licensing, Attribution, & Compliance Guide

This document defines the licensing constraints, quotation permissions, attribution language, and software integration requirements for all Bible translations used in **Parable Bloom** (mobile application and public website).

---

## 1. Licensing & Quotation Overview

Since all modern Bible translations (except those explicitly dedicated to the public domain) are protected by copyright, integrating them into digital software requires strict adherence to their publisher's terms.

There are three primary categories of licensing applicable to our project:

1. **Public Domain (No Restrictions):** Translations that can be stored offline locally, modified, and redistributed freely.
2. **Gratis Use (Standard Quotation Limits):** Permissions that allow displaying limited verses (usually up to 500) in publications or digital displays without a written agreement, provided they are not stored locally as a full database and are properly attributed.
3. **Custom Commercial/App License (Written Agreement Required):** Written licenses required to package translation texts offline inside a software bundle, or to display translations under commercial monetization models (e.g., ads, subscriptions).

### Translation Registry & Status

| Translation | Abbr. | Copyright Owner | License Category | Local Storage? | Network Required? | Status in Parable Bloom |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **World English Bible** | WEB | Public Domain | Public Domain | **Yes** | No | **Active** (Local & Offline Default) |
| **King James Version** | KJV | Public Domain (Crown Copyright in UK) | Public Domain | **Yes** (Non-comm. in UK) | No | **Active** (Local & Offline Fallback) |
| **NET Bible** | NET | Biblical Studies Press, L.L.C. | Gratis (Ministry First) | **Yes** (Free App Only) | No | **Active** (Local & Offline) |
| **English Standard Version** | ESV | Crossway | Gratis / Web API | No | **Yes** (Online API) | **Active** (API-driven Online) |
| **Christian Standard Bible** | CSB | Holman Bible Publishers | Gratis / Web API | No | **Yes** (Online API) | **Active** (API-driven Online) |
| **New Living Translation** | NLT | Tyndale House Publishers | App License Required | No | **Yes** (Online API) | **Pending Commercial License** |
| **New International Version** | NIV | Biblica / Zondervan / Hodder | App License Required | No | **Yes** (Online API) | **Pending Commercial License** |

---

## 2. Granular Translation Details

### A. World English Bible (WEB)

* **Licensing Terms:** Dedicated to the public domain. There are no copyright restrictions, and it may be copied, quoted, published, and distributed without limitation.
* **App Integration:** Fully permitted for offline local database storage (Hive, SQLite) and commercial distribution.
* **Required Notice:** None legally required, but good practice is:
    > "Scripture quotations marked (WEB) are from the World English Bible, which is in the public domain."

### B. King James Version (KJV)

* **Licensing Terms:** Public domain worldwide, with a unique exception in the United Kingdom where it is protected by Crown Copyright (perpetual prerogative administered by Cambridge University Press).
* **App Integration:** Safe for local offline storage. For commercial distribution inside the UK, a license agreement/royalty payment to Cambridge University Press is required.
* **Required Notice:**
    > "Scripture quotations are from the King James Version (KJV) Bible. Public domain (subject to Crown copyright in the United Kingdom)."

### C. NET Bible (NET)

* **Licensing Terms:** Governed by a "Ministry First" gratis license. Allows free use of the verse text (excluding translator notes) without written permission in non-commercial contexts.
* **App Integration:** Because Parable Bloom is currently non-commercial and free, we can bundle and display the NET text offline under these gratis guidelines. If the app is monetized in the future (ads, paid downloads, subscriptions), we must transition the NET Bible to online-only API fetch or secure a commercial license.
* **Required Notice:**
    > "Scripture quoted by permission. Quotations designated (NET) are from the NET Bible® copyright ©1996, 2019 by Biblical Studies Press, L.L.C. <http://netbible.com> All rights reserved."

### D. English Standard Version (ESV)

* **Licensing Terms:** Standard quotation allows up to 500 verses, but **explicitly prohibits** offline database packaging or Creative Commons redistribution.
* **App Integration:** Must not store the ESV text locally. The app will fetch ESV text on-demand using the official **ESV API** (`api.esv.org`) or **API.Bible**.
* **Required Notice:**
    > "Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®), © 2001 by Crossway, a publishing ministry of Good News Publishers. ESV Text Edition: 2025. Used by permission. All rights reserved."

### E. Christian Standard Bible (CSB)

* **Licensing Terms:** Standard quotation permits up to 1,000 verses, but local database bundling inside a digital app is restricted.
* **App Integration:** Must not store CSB text locally. Feeds must be dynamically loaded from a secure online API.
* **Required Notice:**
    > "Scripture quotations marked CSB have been taken from the Christian Standard Bible®, Copyright © 2017 by Holman Bible Publishers. Used by permission. Christian Standard Bible® and CSB® are federally registered trademarks of Holman Bible Publishers."

### F. New Living Translation (NLT) & New International Version (NIV)

* **Licensing Terms:** Both publishers require direct licensing agreements for digital applications. The NIV explicitly excludes digital mobile apps from gratis use.
* **App Integration:** Both translations are marked **Pending Commercial License** and are excluded from active builds to prevent compliance risks. When a commercial license is obtained, they will be fetched online-only via **API.Bible**.
* **Required Notices:**
  * **NLT:** `"Scripture quotations marked (NLT) are taken from the Holy Bible, New Living Translation, copyright © 1996, 2004, 2015 by Tyndale House Foundation. Used by permission of Tyndale House Publishers, Inc., Carol Stream, Illinois 60188. All rights reserved."`
  * **NIV:** `"Scripture quotations taken from The Holy Bible, New International Version®, NIV®. Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.™ Used by permission. All rights reserved worldwide."`

---

## 3. Approved Attribution Framework

To maintain ongoing compliance across both our Next.js website and Flutter mobile application, we implement a unified, multi-tiered attribution framework.

### A. In-Context References (Adjacent to Scripture)

* Every scripture citation displayed in the user interface (e.g., daily scripture banners, level complete rewards, journal pages) must include the book name, chapter, verse, and translation abbreviation:
  * *Example:* *"A joyful heart is good medicine, but a crushed spirit dries up the bones."* **Proverbs 17:22 (ESV)**
* The translation abbreviation (e.g., **(ESV)**) must act as a tap target/interactive label.
* Tapping the label triggers a bottom sheet (mobile) or popover (web) that displays the specific translation's full required copyright notice.

### B. Mobile App Settings / About Screen

* Under **Settings > About > Licenses**, a dedicated **Scripture Attributions** section must be available.
* This screen dynamically reads our `scripture_metadata.json` registry file and displays a clean, scrollable list of all active translations and their full legal copyright statements.

### C. Website Legal Credits

* The Next.js website must host a `/legal/attributions` or `/about/attributions` page.
* This page lists all third-party media, font, and scripture licenses.
* The scripture section displays a structured table of translations, copyright owners, and links to their official licensing sites.

---

## 4. Technical Compliance Safeguards

To prevent developer error from introducing copyright liabilities, the following guards are programmed into the build and runtime environments:

1. **Local Database Guard:**
    * The build/validation pipeline checks the asset directory for any local database files (JSON/SQLite) containing scripture texts.
    * If a text file is found for a translation marked `localDbAllowed: false` (e.g., ESV, CSB, NIV, NLT) in `scripture_metadata.json`, the build terminates with a compliance error.
2. **Static Verse Counter Guard:**
    * For pre-configured game levels or static lessons, a validator script scans the level assets and sums the total verses quoted from gratis-use translations (ESV, CSB).
    * If the sum exceeds the standard quotation limits (500 verses for ESV, 1000 for CSB), the validator outputs a warning to block release until the quote count is reduced.
3. **Network/Offline Fallback Router:**
    * The mobile app routes scripture fetches through a unified service provider:
        * If the requested version requires online access (e.g., ESV, CSB) and the device is connected, the app fetches the verse via the **API.Bible** client.
        * If the device is offline, the app dynamically displays a banner: *"This translation requires an internet connection for copyright compliance. Switch to World English Bible (WEB) to read offline."* Tapping the banner toggles the active version to **WEB** (or KJV) and loads the offline verse from local storage.
