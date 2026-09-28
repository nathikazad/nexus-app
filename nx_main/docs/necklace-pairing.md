# Add Necklace

Open Hardware → Devices → Add Necklace, select the physical BLE unit, and wait
for identity verification. The page reports connecting, linking and verifying.
It succeeds only after the server lists the device as Active. Existing SleepBot
Assistant/Radar entries use the same account-owned registry; their setup delivery
remains USB. Necklace provisioning is performed over BLE without displaying a
pairing secret to the user.

The selected Necklace must run firmware with the identity characteristic. Older
firmware fails with a connection/firmware error; there is no user-token socket
fallback. An already-active device owned by this account can be linked again;
a pending device can have its pairing secret renewed. Another account's device
and revoked identities cannot be reassigned. Device reset/ownership transfer is
a separate maintenance operation, not part of this flow.

The background service owns BLE and serializes identity transactions. Foreground
pairing pauses automatic device authentication to prevent two clients consuming
the same challenge. It resumes afterward, including cancellation/error paths.
The app persists a non-secret backend/account/peripheral/UUID binding. Device
access tokens remain in RAM. Private keys remain on the nRF. Account or BLE
changes retire the old socket and its queues.

Necklace uses `X-Client-Id: necklace` and a device bearer token. NX Main and Watch
use their own client IDs. `X-Device-Source` is removed. Phone telemetry and GPS
retain user authentication; their availability does not gate the device socket.
Image and audio framing are unchanged.

Release this with the matching server and nRF worktrees. Follow AGENTS.md for
Shorebird installation. Hardware verification still needs a selected Necklace
and phone: first bond/provision, app backgrounding, reboot/reconnect, network
loss during enrollment, account/device switching, and server revocation.
