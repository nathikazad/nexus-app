# Shared data policy and view cache

`AppDataPolicy` owns the browser/native decision. Web creates no persistent
library or background file hydration; authentication and UI preferences remain
separate. Native uses the app's durable repository and separate file queue.

`DataCache` coalesces requests, preserves a previous value when refresh fails,
and retries a request invalidated while in flight before acknowledging it.
Caches belong to an authenticated account and are discarded on account changes.
`nx_db.AppReads` supplies authenticated `/apps/{app}` requests and paged views.
Web retains completed views for the current session; native live reads only
coalesce in-flight work because its durable store is the source of cached data.
