# NX Auth

NX Docs and NX Cards share `AuthLoginFields` for backend and person selection.
The profiles in `src/user.dart` contain display names, local user IDs, and
hosted ZITADEL login hints. Update these shared definitions instead of adding
separate lists to each app.

For hosted sign-in, the selected profile is passed to `AuthController.login`.
OIDC uses its login hint and requests fresh authentication. `/v1/me` remains
the authority for the user ID; if it differs from the selected profile, the
new token session is forgotten and sign-in fails before saving app credentials.
Local development backends continue using their direct user IDs.

Creating a hosted login for an existing Nexus user requires creating the
ZITADEL identity, granting Nexus project roles, and administratively binding
the exact issuer/subject to the existing user. Do not bootstrap another Nexus
user when preserving an existing personal domain and shared memberships.
Passwords and verification codes must not be placed in these profiles.
