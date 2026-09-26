# NX Auth

See the [cross-platform callback audit](docs/callback-audit.md) for Android,
iOS, native macOS and web return paths, observed failures, test coverage and
the proposed recovery plan.

NX Docs and NX Cards share `AuthLoginFields` for backend and person selection.
The profiles in `src/user.dart` contain display names, local user IDs, and
hosted ZITADEL login hints. Update these shared definitions instead of adding
separate lists to each app.

For hosted sign-in, the selected profile is passed to `AuthController.login`.
OIDC uses its login hint without forcing fresh authentication, allowing the
provider to reuse a matching browser session. `/v1/me` remains
the authority for the user ID; if it differs from the selected profile, the
new token session is forgotten and sign-in fails before saving app credentials.
Local development backends continue using their direct user IDs.

Creating a hosted login for an existing Nexus user requires creating the
ZITADEL identity, granting Nexus project roles, and administratively binding
the exact issuer/subject to the existing user. Do not bootstrap another Nexus
user when preserving an existing personal domain and shared memberships.
Passwords and verification codes must not be placed in these profiles.

## Remembered account

Each installed app persists the last successfully authenticated user separately
from its active session. A valid session still restores automatically. After
logout or session expiry, the login form preselects that person; logout retains
this preference. Selecting a different person only changes the preference after
successful sign-in. Existing active-session preferences are migrated before an
expired session is cleared.

All app login screens use `RememberedLoginProfile`. With no recognized saved
person, the field says “Select person” and sign-in requires an explicit choice.
Hosted login passes that person's hint and checks the verified identity. This
preference contains only a user ID, grants no access, and is local to the app's
installation; it is not guaranteed to survive uninstalling the app.
