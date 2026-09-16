# Cross-platform login callback audit

Audited 2026-09-16 against mobile `fd6dd58b`, servers `ece95c6`, and the
connected Bigme B7 Pro (Android 14). The sections below record the pre-fix audit; the implementation update immediately below supersedes Android launch details.
The initial source audit made no authentication changes. The subsequent live
tests below exercised sign-out/sign-in and browser sessions with user
authorization. No account credentials or authentication policy were changed.

## Implemented and installed after the audit (2026-09-16)

Cards and Docs release build **20260927** were installed with data preserved on
Bigme Android 14; package manager confirmed both version codes. Both now use
ComponentActivity-compatible Flutter hosts and the shared vendored Android OIDC
plugin. NX Auth explicitly selects Chrome (137 or newer), enables a five-minute
native timeout, and preserves Apple/web defaults. Missing/outdated Chrome fails
with an update/install message. The fallback receiver validates path and state
as well as scheme/host, resolves once, and returns the app to the foreground.
The Cards-only receiver was removed in favor of the shared implementation.

Live checks on this build:

- Docs: closing Chrome authentication returned immediately to a usable sign-in
  form with a cancellation message. Retrying reused valid browser SSO and
  automatically returned to the native domain picker, then the Docs workspace.
- Cards: valid browser SSO automatically returned to the native domain picker,
  then the Nathik library. Neither successful return needed manual dismissal.
- The user confirmed the preceding Chrome QR passkey flow completed using the
  iPhone. This verifies cross-device signing in Chrome web; a fresh QR ceremony
  inside the updated native app was not repeated.
- 15 Android plugin regression tests and 16 shared Flutter auth tests passed.
  Both release APKs compiled. Native tests cover callback identity, once-only
  completion, flow supersession, and missing requested browser behavior.

Hosted login now runs `nexus-zitadel-login:4.16.2-session-recovery`. On the
specific ZITADEL rejected-session error COMMAND-sGr42 it removes only the bad
saved session and starts authentication for the same person/request. It retains
valid SSO and other accounts. All 19 login image tests passed, including recovery,
valid callback, unrelated server failure, and password visibility tests. The
previous image and compose file remain available for rollback. The invalid-token
case is regression-tested; the original stale cookie was not recreated on-device.

Apple code and web callback files are unchanged. Earlier Mac/native and Chrome
web success remains the baseline; fresh iPhone biometric completion and Safari
web success remain unverified. Android process death still requires restarting
sign-in because pending PKCE state is in memory. Do not interpret successful SSO
as verification of every credential type or every device/browser combination.

## Three different things called a session

1. **Identity-provider browser session:** ZITADEL remembers a signed-in person
   in that browser context. The login page may show a verified account even if
   its stored session token cannot complete a new authorization request.
2. **Pending authorization transaction:** one app owns an in-flight request,
   state/nonce and PKCE verifier. A browser account alone cannot complete it.
3. **Installed app session:** each app stores its own OIDC credentials under
   `nexus-{backend}-{clientAppId}` and its own platform storage. `/v1/me` supplies
   the actual Nexus user; `/v1/domains` establishes data access. Data is then
   partitioned by server, user, domain and app.

Cross-app browser SSO can avoid another password, but does not eliminate the
need for each app to finish its own callback and token exchange. A green
account indicator or a page saying to return is not proof of app authentication.
Shared source code does not mean shared token storage between installed apps.

## Expected sequence and failure boundaries

`app starts request -> browser authenticates/selects account -> ZITADEL creates
callback -> OS/browser delivers callback -> OIDC validates state and exchanges
code -> /v1/me -> /v1/domains -> app workspace`

Instrument these boundaries separately. In particular, an error creating the
callback is upstream of Android intent handling. Bringing an activity forward
cannot fix a callback URL that was never issued.

## Platform comparison

| Platform | Current launch/capture mechanism | Callback destination | Return/close behavior |
| --- | --- | --- | --- |
| Android Cards | `FlutterActivity`; plugin uses Custom Tabs intent, which the Bigme browser handles as an ordinary browser activity | `nx-cards://oauth/callback`, resolved to `CardsAuthRedirectActivity` | Custom receiver calls `OidcPlugin.handleRedirect`; only an accepted pending redirect starts MainActivity with CLEAR_TOP/SINGLE_TOP. |
| Android Docs | `AudioServiceActivity` extends `FlutterActivity`; same plugin fallback | `nx-docs://oauth/callback`, resolved to plugin `OidcRedirectActivity` | Plugin receiver delivers to pending callback and finishes itself; it does not explicitly bring Docs forward. |
| Native macOS | `oidc_darwin` defaults to `ASWebAuthenticationSession` | App-specific custom scheme, e.g. `nx-docs://oauth/callback` | Apple authentication session completion returns URL/error to Dart and dismisses the authentication UI. Ordinary browser tab-close workarounds are not this path. |
| iOS | Same Darwin plugin, Apple authentication session | App-specific custom scheme | Same completion model; presenting window and OS consent/session behavior matter. |
| Web on Mac or other OS | `oidc_web`, default `newPage` navigation | Same-origin HTTPS `/docs/auth.html`, `/flashcards/auth.html` (other apps have their own paths) | Callback HTML broadcasts the URL, waits for app ACK, attempts to close; same-page mode instead restores stored state and navigates back. No Android activity or Apple session completion is involved. |

Defaults inspected: `oidc` 3.0.1, `oidc_core` 2.1.0,
`oidc_android` 2.0.1, `oidc_darwin` 1.1.1. This describes checked-out package
sources, not proof that every older installed Apple build uses identical code.

The Android plugin has an Auth Tab / ActivityResultLauncher branch for a
ComponentActivity, but the inspected Cards/Docs host activities use the other
branch. It matches callback scheme and host in native code; the OIDC core must
still validate the complete authorization response. The fallback relies on a
live, in-memory pending callback. Process death or a stale browser tab can leave
nothing to receive a later redirect. Never treat an unsolicited deep link as
proof of login.

Both Apple defaults and Android defaults are non-ephemeral. macOS also has an
optional loopback-system-browser mode in the dependency, but NX Auth does not
select it. A generic “close tab / go back” solution must not be applied to the
Apple system-session path.

## Current shared NX Auth behavior

- Fetches validated per-app OIDC configuration from `/v1/auth/config`.
- Hosted person selection supplies a login hint. The forced `prompt=login`
  was removed in `fd6dd58b`; normal provider session reuse is allowed.
- `/v1/me` remains authoritative. A selected-person mismatch is rejected and
  the newly acquired OIDC user is forgotten rather than silently logging in
  as the other person.
- App credentials are saved after identity resolution. Domain loading follows.
- Hosted `AuthController.logout()` invokes provider logout before clearing local
  preferences. Thus the current Log out operation is not purely local and can
  affect later browser SSO. This is separate from requesting fresh authentication.
- There is no configured native `flowTimeoutSeconds` for the interactive browser
  flow. Config and `/v1/me` have HTTP timeouts, but those do not bound waiting
  for a browser callback. Cards displays a generic `/loading` spinner during
  auth loading, without a cancel/retry explanation.

## Observations and tests

| Check | Result and limit |
| --- | --- |
| Android foreground app | Cards was on an empty/loading UI; no successful-login event was available in the retained log buffer. |
| Restart Cards without clearing data | Logged `No saved credentials found`, then a new hosted login began. The earlier attempt had not reached persisted app credentials. This does not prove why the earlier callback failed. |
| Bigme browser | Foreground package was `com.b300.xrz.web`, activity `com.tbs.web.main.MainAt`; screenshot showed ZITADEL Accounts with Yareni marked verified. It was an ordinary browser window. |
| Server log correlated with retry | ZITADEL reported HTTP 403 `Session Token is invalid (COMMAND-sGr42)` during `createCallback`, including 21:09:27 UTC. Source `flow-initiation.ts` catches this and routes back to Accounts. This establishes a server-side callback-creation failure, not its underlying token-staleness cause. |
| Android intent registration | Read-only `cmd package resolve-activity` returned the expected Cards custom receiver and Docs plugin receiver. Registration works; this is not an end-to-end callback delivery test. |
| Native macOS Docs | Inspected running app: signed-in document workspace visible. Installed build 0.1.0+7, bundle `io.kgql.docs`. Did not sign out or perform a new account switch. Existing workspace is not proof of current fresh-login success. |
| iPhone inventory | Paired iPhone available. Cards 1.0.0+23; Docs 0.1.0+6. No interactive iPhone callback test performed; no install or credential changes. |
| Browser callback error | Served unmodified Docs `auth.html` on isolated localhost origin. Synthetic `error=access_denied` showed “Something went wrong” and the test error description. No live identity/token used. |
| Browser callback without app listener | Synthetic state and no listener initially showed “Completing your request...”; after 10 seconds showed “You can now close this tab and return to the app.” No authentication occurred. The fallback text is neutral, not an app success ACK. |
| Docs/Cards web helper parity | Their `auth.html` files are byte-identical (SHA-256 `5a830aea4bd88490624fe85a82165c0e8fa6ad8afe774d736bc0c1848ae349f8`). |
| Existing automated coverage | The 16 shared NX Auth tests passed in the preceding session-reuse change. They cover storage/domain/selector/transport behavior, not full browser-to-native callbacks. Do not use this count as cross-platform end-to-end evidence. |

No native callback was fabricated with a real authorization code. No password,
access token, session cookie/token, full callback URL or PKCE verifier is stored
in this audit. Android device clock was offset from server UTC; use server
timestamps and request correlation when comparing logs.

## Findings, with confidence

1. **Confirmed:** the observed saved-session attempt can fail at ZITADEL callback
   creation and return to Accounts. A still-visible verified account does not
   prove its cookie token is usable for creating a callback. Token rotation,
   multiple tabs, and stale cookies are hypotheses requiring further evidence.
2. **Confirmed code difference:** Cards and Docs handle Android foregrounding
   differently. Standardize this only after reproducing a successfully issued
   callback that fails to return; it is not a substitute for fixing finding 1.
3. **Confirmed recovery gap:** no interactive-flow deadline and a generic loading
   route allow a missing callback to look like an indefinite app hang.
4. **Confirmed web UX ambiguity:** the web helper's no-ACK timeout can look like
   success. It should distinguish completion from “no app responded.”
5. **Unproven:** whether the specific failed Android attempt also lost its in-memory
   plugin callback or had its custom scheme blocked by the Bigme browser. The
   captured evidence is insufficient to attribute the whole issue to Android.
6. **Unproven:** current fresh-login/account-switch behavior on native Mac/iPhone
   and full web OAuth. These need an explicit end-to-end test matrix before
   changing a shared callback contract.

## Proposed solution, not implemented

First add redacted transaction tracing in NX Auth using the plugin's native
browser events (opening/opened/redirectReceived/cancelled/failed/timeout) and
stage markers for code exchange, identity and domain readiness. Log a local
correlation ID, platform, client ID, capture mode, app lifecycle and error class;
never log authorization URLs or credential contents.

Then address each failure at its owner:

- **ZITADEL:** recover from an invalid saved-session token by invalidating only
  that stale browser-session entry and routing to an explicit retry/re-auth
  choice. Preserve other valid accounts; do not globally clear everyone’s SSO.
  Establish why the token became stale before implementing automatic refresh.
- **Android:** centralize the accepted-callback foreground return for supported
  Android hosts in a shared native adapter/plugin. Test stock Bigme browser and
  a Custom Tabs-capable browser separately. Handle process death with an explicit
  restart-login outcome; do not accept a redirect without matching pending state.
- **Shared app UX:** bounded interactive flow, cancel/retry, and a distinct
  waiting-for-browser state. Cancel the native request as well as the Dart wait
  and ignore late completions, rather than adding only `Future.timeout`.
- **Apple:** retain ASWebAuthenticationSession unless a separate verified Apple
  defect warrants change. Do not replace it with ordinary-browser closing logic.
- **Web:** retain same-origin state/ACK protections; show “app did not respond”
  on missing ACK, with a safe return option instead of implying completion.
- **Logout:** explicitly separate local sign-out/account switching from ending
  the identity-provider browser session if product behavior should preserve SSO.

## Required acceptance matrix for a fix

Run Docs and Cards against each supported platform/browser combination:

1. Fresh password sign-in and fresh passkey sign-in.
2. Reuse same-person browser session; switch Nathik -> Yareni -> Nathik.
3. Cancel/back; background/resume; network loss; provider session rejection.
4. Android process death while browser is open; duplicate/late callback;
   registered custom scheme accepted or browser refuses external-app navigation.
5. Web app tab closed, popup blocked, no ACK and same-page restoration.
6. Apple cancel/presentation and successful system-session completion.
7. Confirm `/v1/me` user, correct domain picker/membership, workspace ready,
   and durable reopening. Returning to the app alone is not a pass.

Record installed app versions, browser/version, OS, identity-provider image,
selected person and redacted stage timestamps for every run. Do not infer that
an Android APK change updated iOS or macOS; those are separate installed builds.

## Passkeys: local biometrics versus another-device QR

Extended audit on 2026-09-16. Read-only ZITADEL v2 passkey searches found:

| Selected identity | Registered passkeys |
| --- | --- |
| Nathik | One ready credential, named `Nathik Iphone` |
| Yareni | None |

The credential name is a label, not evidence of its current physical location.
It may be synchronized through Apple Passwords/iCloud Keychain. No Mac keychain
contents were inspected. Nathik's credential cannot authenticate Yareni; Yareni
must enroll her own passkey before passkey sign-in can succeed. Enrollment
(`navigator.credentials.create`) and sign-in (`navigator.credentials.get`) are
different operations. No credentials were enrolled, removed or changed here.

The deployed ZITADEL v4.16.2 `login-passkey.tsx` passes the server challenge and
allowed credential list to `navigator.credentials.get({ publicKey })`. It does
not itself force QR or Touch ID. The browser, OS and credential provider present
the available methods. The actual challenge's RP ID and transport hints were
not captured during the reported failure, so a server-side filtering issue has
not been ruled out.

| Environment | Expected behavior and audit limit |
| --- | --- |
| Native macOS app | Uses ASWebAuthenticationSession. An eligible passkey available to its provider can use Touch ID. The installed app was seen signed in, but a fresh passkey ceremony was not reproduced. |
| Mac browser | Local passkey availability depends on browser/profile/provider and selected account. QR can appear when choosing another device or when the local credential is unavailable. The reported intermittent QR prompt was not reproduced. |
| Bigme Android | Observed browser `com.b300.xrz.web` 5.2.6, loading WebView 126.0.6478.71; Google Play services installed. This is not proof of full WebAuthn or cross-device support. No successful passkey or QR ceremony was observed. |
| iPhone | Apple can use a matching local/synchronized passkey with device verification. No fresh interactive passkey test was performed. |

For cross-device sign-in, the device being signed into displays the QR code;
the phone holding the passkey scans it. A supported Android flow can therefore
display a QR for an iPhone to scan. QR is an alternative method, not an automatic
requirement on every Android login. See Google's
[supported environments](https://developers.google.com/identity/passkeys/supported-environments).

Apple documents Touch ID and a nearby-device option, with passkeys synchronized
through iCloud Keychain. A fingerprint unlocks the matching credential; it does
not make every selected account eligible. See
[Mac passkey sign-in](https://support.apple.com/en-ph/guide/passwords/mchl4af65d1a/mac).

The Bigme browser is a compatibility hypothesis, not a confirmed root cause.
Android's WebView documentation requires feature support and host integration;
Android 14 and installed Play services alone do not establish that the vendor
browser exposes this flow. See
[WebView authentication](https://developer.android.com/identity/sign-in/credential-manager-webview).

### Next diagnostic comparison and proposed direction

1. Use the same selected identity with a known enrolled passkey for every
   comparison. Separate Yareni's missing enrollment from browser compatibility.
2. On Bigme, compare the stock browser with a current Chrome Custom Tab using
   Nathik's existing passkey on his phone. Record whether the chooser appears,
   whether another-device QR is offered, and the precise failing stage. Do not
   change the default browser or install software as part of this audit.
3. On Mac, compare the native system session and the user's browser with the
   same account/provider. Check matching credential availability with the user;
   do not infer it from the registration label or inspect private key material.
4. Capture only redacted WebAuthn diagnostics: API availability, RP ID,
   credential count/transport types, DOMException name and flow stage. Do not
   log credential IDs, assertions, challenge values, passwords or tokens. A
   platform-authenticator capability probe alone does not prove QR support.
5. Keep platform choices in the system chooser. If the stock browser proves
   incompatible, use a supported Android browser path with a clear fallback;
   preserve Apple's system session. Offer passkey enrollment for an already
   authenticated user who has no passkey, rather than promising QR will work.

Successful passkey verification still goes through the callback sequence above.
It does not resolve the observed invalid saved-session token or guarantee that
Android returns to the app. Test both boundaries independently before fixing.

## Live device verification, 2026-09-16

These observations supersede the earlier "not tested" entries only for the
specific installation and scenario named. Real provider requests were launched
from apps; no authorization responses were fabricated.

| Installation / scenario | Observed result |
| --- | --- |
| Mac Chrome 152.0.7977.83, hosted Docs web | Entered `nathikazad`; system sheet said "Touch ID to Use Passkey", named `auth.kgql.io` and `nathikazad`, and identified Apple Passwords. The provider tab subsequently closed, Docs showed Home/Nathik domain choices, and selecting Nathik opened the workspace. Local passkey discovery and complete web return confirmed. |
| Mac Cards build 15 | Started with library visible, signed out, observed login screen, launched login, then observed library again. Native return succeeded. The intermediate authenticator ceremony was not captured, so this run does not establish whether it reused SSO or performed fresh passkey verification. |
| iPhone Cards 1.0.0+23 | Restored its library. Sign-out presented Apple's site-use consent and returned to login. Fresh sign-in opened an Apple system browser sheet and Nathik's passkey sheet with "Use Passkey" and "More Options". |
| iPhone Cards passkey options | "More Options" explicitly offered "Scan QR Code" and "Use Security key". Local passkey use through Mirroring required Mac Touch ID/Safari authorization; that attempt ended with "Passkey verification was cancelled". Successful iPhone passkey completion is still unverified. |
| iPhone Cards cancellation | Cancelling the authenticator displayed the provider's cancellation message. Closing the system browser returned to Cards login; no indefinite spinner remained. |
| iPhone Docs `io.kgql.docs`, 0.1.0+12 | Opened an existing document workspace. Installed app URL matched the running executable through `devicectl`. This is session restoration, not a fresh-login test. |
| iPhone Docs `com.nexus.nxNotes`, 0.1.0+6 | A second app with the same visible name exists. It opened a login screen with backend "Pi (WAN)". Different bundle IDs mean separate storage and potentially different installed auth code/configuration. Do not combine results from these two copies. |
| Bigme stock browser, Nathik passkey | Using the existing native authorization request, selected another account and entered `nathikazad`. The passkey page immediately displayed "An error occurred during passkey verification" without an observed system chooser/QR. A retry was attempted. This verifies a failure before successful WebAuthn completion, but the underlying DOMException/capability cause is not yet captured. |
| Bigme stock browser, fresh Cards request / saved Yareni | Restarted Cards without clearing data, selected Yareni, launched a new request and tapped the verified account. Returned to Accounts again; server logged HTTP 403 `Session Token is invalid (COMMAND-sGr42)` at 21:41:37 UTC. Reproduces the separate saved-session/callback-creation failure. |
| Bigme Chrome 152.0.7977.82, Docs web / Nathik | Installed from Google Play and completed first-run after explicit user approval. Same tablet and identity reached the system passkey chooser, unlike the stock browser. The chooser reported "Set up screen lock to use passkeys" and offered "Use a different device". No screen lock was configured by the audit. |
| Bigme Chrome cross-device choice | "Use a different device" initially showed NFC/USB security key; "More options" revealed "Use another device". Selecting it opened "Scan this QR code" with explanatory text naming `auth.kgql.io` (verified through accessibility). The secure dialog was black in the mirror. User must scan the physical tablet to verify completion; no attempt was made to bypass capture protection. |

Android Mirror remote clicks were unreliable during this run. Address/reload
controls sometimes responded while page activation did not; direct ADB input
then advanced the page immediately. Do not classify those failed mirror clicks
as an application or browser defect. The mirrored screen was used to verify
the resulting UI. Read-only logs did not expose a WebAuthn exception.

The default Android browser remains `com.b300.xrz.web`; Chrome was launched
explicitly for comparison. Its successful chooser/QR presentation does not
yet verify Chrome's native-app callback or completion of cross-device signing.
The stock-browser versus Chrome comparison establishes a browser-path
difference on this tablet; it does not establish the precise failing API in
the stock browser. Screen-lock setup is a separate prerequisite reported by
Chrome for local passkey use, not evidence that remote QR use is unavailable.

`com.google.android.gms/.fido.hybrid.HybridAuthenticateActivity` was the resumed
Android activity while the QR dialog was waiting. This corroborates the system
cross-device flow; it is not a website-drawn QR. The user was asked to scan the
physical display because the mirrored secure dialog cannot supply the QR.

The shared `nx_auth` Flutter suite was rerun after these checks: 16 tests passed.
These tests remain unit/widget coverage, not a substitute for device results.

### Verification outstanding at the end of the original audit

- Complete the Bigme Chrome QR using the user's phone, then verify web callback
  and domain/workspace readiness. QR presentation alone is not a full pass.
- Verify a fresh native Android callback after successful credentials, in both
  Cards and Docs. The stock-browser saved-session run currently stops upstream
  at the server error. Chrome comparison must preserve the app's pending PKCE
  transaction when switching browsers.
- Complete iPhone Cards local passkey verification through the human biometric
  step, then verify the app workspace. Local key discovery and cancellation
  have been tested; successful completion has not.
- Safari web attempt reached the Docs login URL, but tool screenshot/AX output
  did not expose a usable rendered login after reload. No Safari web success or
  product rendering defect is claimed from that inconclusive observation.

Do not introduce a universal browser-close workaround based on these results.
First recover the rejected provider session, use a demonstrated Android WebAuthn
browser path, and add stage-specific diagnostics/cancel recovery. Preserve the
working Mac native and Chrome web return mechanisms. These fixes were not made during the audit itself; see the implementation update above.

Server logs confirmed a completed valid OIDC flow after the Chrome test around
21:27 UTC and another around 21:31 UTC. A server success alone is not proof of
an app return; the workspace/library observations above supply that evidence.

## Source map

- `lib/src/oidc_service.dart`: OIDC launch, configuration, identity resolution.
- `lib/src/auth_controller.dart`: restore, persistence, domain selection, logout.
- `lib/src/domain_session.dart`: domain loader and gate.
- `../../../nx_cards/android/app/src/main/kotlin/com/nexus/nx_cards/CardsAuthRedirectActivity.kt`.
- Cards/Docs Android manifests and MainActivity classes.
- Cards/Docs `web/auth.html`: BroadcastChannel + state storage + ACK timeout.
- Dependency sources: `oidc_android/OidcPlugin.kt`, `OidcRedirectActivity.kt`,
  `oidc_darwin/OidcPlugin.swift`, `oidc_core/.../platform_options.dart`.
- ZITADEL v4.16.2 `apps/login/src/lib/server/flow-initiation.ts`:
  saved-session selection and callback-creation error handling.
