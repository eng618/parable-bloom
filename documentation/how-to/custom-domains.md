# Attach the public hosts

Put the marketing site and the game on `gventureshq.com` without merging the two deploys.

| Surface | Where it keeps deploying | Public URL |
| --- | --- | --- |
| Marketing, privacy, support, terms, account deletion | Cloudflare Pages (`parable-bloom.pages.dev`) | `https://parablebloom.gventureshq.com` |
| Game | Firebase Hosting site `parable-bloom` (`parable-bloom.web.app`) | `https://play.parablebloom.gventureshq.com/#/game` |

`gventureshq.com` is already a Cloudflare zone. Both names are subdomains, so each one is a single DNS record. Do the marketing name first, then the game name. Leave `parable-bloom.pages.dev` and `parable-bloom.web.app` in place. Store listings can stay on `pages.dev` until the new URLs answer.

Firebase prints the exact record values in the connect-domain wizard. Those values win over any sample below.

## 1. Marketing site on Cloudflare Pages

1. Open the [Cloudflare dashboard](https://dash.cloudflare.com) → **Workers & Pages**.
2. Open the Pages project that serves `parable-bloom.pages.dev`.
3. Open **Custom domains** → **Set up a domain**.
4. Enter `parablebloom.gventureshq.com`. Continue.
5. Because `gventureshq.com` is a zone on this account, Pages adds the DNS record itself. Confirm it under **DNS** → **Records** for `gventureshq.com`:

   | Type | Name | Target | Proxy |
   | --- | --- | --- | --- |
   | CNAME | `parablebloom` | `parable-bloom.pages.dev` | Proxied (orange cloud) |

   The Name field is the label under the zone. `parablebloom` is the full host `parablebloom.gventureshq.com`. Do not type the zone name again.

6. If Pages did not create the row, add that CNAME yourself. Orange cloud is correct here. Pages is a Cloudflare product.
7. Return to the Pages project. Wait until the domain status is **Active**. A redirect rule on `gventureshq.com` that catches this host will leave it on **Verifying**. Disable that rule, then use **Check DNS records**.
8. Confirm both of these load the marketing site, including the footer and the privacy page:

   - `https://parablebloom.gventureshq.com`
   - `https://parablebloom.gventureshq.com/privacy`

`https://parable-bloom.pages.dev` keeps working. Nothing in the Next.js project has to change for Pages to serve the new host.

## 2. Game on Firebase Hosting

Use Quick Setup. This hostname has no traffic yet, so the zero-downtime Advanced path is unnecessary.

1. Open [Firebase Hosting](https://console.firebase.google.com/project/parable-bloom/hosting/sites) for project `parable-bloom`.
2. Open the site whose default domain is `parable-bloom.web.app` (site id `parable-bloom`).
3. **Add custom domain**.
4. Enter `play.parablebloom.gventureshq.com`.
5. Leave the redirect checkbox off. Checking it would send the game host somewhere else.
6. Continue. In the domain dialog, open **Advanced**, not Quick Setup. Quick Setup asks only for a CNAME to `parable-bloom.web.app`. That CNAME can already be visible to public DNS while Firebase still reports **Records not yet detected**, and it cannot sit beside the ownership TXT. Advanced proves ownership first, mints the certificate, then directs traffic with address records.

   Do not add any record on `@`. `@` is `gventureshq.com`, the company zone. Cloudflare will also refuse it when a Workers record already owns that name.

7. Delete the `play.parablebloom` CNAME if it exists. Then add the Advanced step 1 record. In Cloudflare's Name field, enter `play.parablebloom`, which is the full host `play.parablebloom.gventureshq.com`:

   | Type | Name | Content |
   | --- | --- | --- |
   | TXT | `play.parablebloom` | `hosting-site=parable-bloom` |

   Copy the value from the wizard if it differs. A TXT record has no proxy switch. Confirm it before clicking **Verify**:

   ```bash
   dig +short TXT play.parablebloom.gventureshq.com
   ```

   The output must be `"hosting-site=parable-bloom"` and must not be a CNAME.

8. After step 1 verifies, finish **Mint SSL certificate**, then **Direct to Hosting**. Add every A and AAAA record that step shows, on the same name `play.parablebloom`, and leave the TXT in place. A and TXT records may share a name. Do not put the CNAME back. Set every address record to **DNS only**. An orange cloud sends traffic through Cloudflare. Firebase then cannot finish its certificate check, and TLS can fail with a cipher or hostname mismatch.

   Cloudflare's free Universal certificate only covers `gventureshq.com` and one label under it (`*.gventureshq.com`). `parablebloom.gventureshq.com` is covered, which is why the marketing site can stay proxied. `play.parablebloom.gventureshq.com` is two labels deep, so it is not covered. If the new record is proxied, Cloudflare shows [This hostname is not covered by a certificate](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/total-tls/error-messages/) and points at Total TLS.

   Do not buy Total TLS or an Advanced Certificate for this hostname. Those products exist so Cloudflare can terminate HTTPS. This record must stay grey so Firebase terminates HTTPS instead. If the add form defaults to Proxied and then errors, switch the cloud to grey and save again. If an orange-cloud row is already there, edit it to **DNS only**, or delete it and recreate it grey. The warning applies to proxied records. A grey-cloud record does not use Cloudflare's certificate.
9. Remove any other A, AAAA, or CNAME already named `play.parablebloom` besides the records in the current Advanced step. Do not add a wildcard such as `*.parablebloom`. A wildcard would steal this name from Firebase.
10. If the zone has CAA records, they must allow `letsencrypt.org` and `pki.goog`. With no CAA records, leave DNS alone.
11. Wait until the Firebase domain status is **Connected**. **Needs setup** means the record for the current step is missing. **Pending** or **Minting Certificate** means DNS is right and the certificate is still being issued. That can take a few hours and sometimes up to 24 hours. A certificate warning in the browser during minting is expected.

    While the CNAME to `parable-bloom.web.app` is the only record, the browser reaches Firebase and shows **Site Not Found**, and the certificate stays `firebaseapp.com`. Firebase is not treating that CNAME as proof for this hostname. The Advanced TXT has to exist on `play.parablebloom` itself, which means the CNAME has to be removed first.
12. When the status is **Connected**, open `https://play.parablebloom.gventureshq.com/#/game`. You should get the same garden as `https://parable-bloom.web.app/#/game`.

`parable-bloom.web.app` stays attached to the same Hosting site. Deploys from `task firebase:hosting:deploy` publish to both names. No `firebase.json` change and no `--base-href` change.

## 3. Let the game host sign in

The Flutter web app's Auth domain stays `parable-bloom.firebaseapp.com`. Firebase still refuses sign-in from an origin that is not on the allowlist.

1. In the same Firebase project, open **Authentication** → **Settings** → **Authorized domains**.
2. Add `play.parablebloom.gventureshq.com`.
3. Leave `localhost`, `parable-bloom.firebaseapp.com`, and `parable-bloom.web.app` in the list.

Then, on the new game URL, open Settings → Sign In and confirm an email/password account can sign in. Guest play does not need this step. Cloud sync does.

## 4. Check DNS from your machine

```bash
dig +short CNAME parablebloom.gventureshq.com
dig +short TXT play.parablebloom.gventureshq.com
dig +short A play.parablebloom.gventureshq.com
curl -fsSI https://parablebloom.gventureshq.com/privacy
curl -fsSI https://play.parablebloom.gventureshq.com/
```

The marketing CNAME should end at `parable-bloom.pages.dev`. After Advanced step 1, the game TXT should be `"hosting-site=parable-bloom"`. After step 3, the game A record should be the address Firebase shows, with no CNAME left on that name. An orange-cloud record hides its target behind Cloudflare addresses, which is what you want only for `parablebloom`.

Both `curl` calls should return `HTTP/2 200` (or a redirect that lands on `200`). `/privacy` must be the marketing policy, not the Flutter app.

## After both hosts answer

Hardcoded links still say `pages.dev` and `web.app`. Update them in a follow-up change, then point Play Console and App Store Connect at the new legal URLs only after each one returns 200:

- `https://parablebloom.gventureshq.com/privacy`
- `https://parablebloom.gventureshq.com/support`
- `https://parablebloom.gventureshq.com/delete-account`

Play buttons on the marketing site should then target `https://play.parablebloom.gventureshq.com/`. Keep the old hosts serving until those consoles and the in-app copy have moved. Neither old host needs a redirect for the new names to work.
