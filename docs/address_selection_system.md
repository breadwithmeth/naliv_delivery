# Address selection and local recovery

The active application enters through `lib/widgets/authentication_wrapper.dart`.
Reachable address management remains in `lib/pages/profile_addresses_page.dart`;
map selection uses `map_address_page.dart` and manual search uses
`address_search_page.dart`. Do not substitute the old `MainPage` integration.

## Selection ownership

- A new map gesture or search selection supersedes any pending location intent.
  Late location success, unavailable results and errors cannot replace that choice
  or open a stale permission dialog.
- Permission/provider checks are reused within one location intent. Disabled,
  denied and unavailable location leave manual map/search selection usable.
- Search and reverse-geocoding reads have a 10-second HTTP timeout. Failure exposes
  an explicit retry; the client does not silently send another request.

## Local persistence

`lib/utils/address_storage_service.dart` owns selected address, local address book,
hidden server-address identities and search history in SharedPreferences.

- `getBookSnapshot()` decodes records individually. Valid neighbors remain usable;
  unreadable original records survive unrelated save/remove operations.
- `saveBookAddress()` retains replacement identity and updates related local data
  through checked writes. `removeBookAddress()` keeps server hiding distinct from
  local removal. These operations do not invent a server address-write endpoint.
- Failed add/edit retains the exact draft for explicit retry or discard. The UI
  never claims the address was saved merely because a picker returned a value.
- Coordinate strings are normalized only when finite and in valid ranges.
- The canonical base address stays separate from apartment, entrance, floor and
  instructions. Checkout combines them for display without decorating the stored
  base label again.
- Account-derived address caches clear immediately on credential changes and reject
  late prior-account reads. Device-local addresses remain available if refresh fails.
- Checkout binds the delivery address to the **selected store's** city
  (`lib/services/store_city.dart`: `city_id` → city name, address text as fallback), not
  to the onboarding/location city. The picker receives that city and the store's
  coordinates; an already chosen address whose known city differs is shown as a
  mismatch and blocks order creation until an address in the store city is picked.
  An address without a known city is never treated as a mismatch.

## Verification and limits

`test/integration/address_location_test.dart` exercises superseded location intents
and manual fallback. `address_recovery_test.dart` exercises failed drafts, explicit
retry/discard, bounded reads and private-cache ownership. Storage boundaries live in
`test/regression/address_storage_service_test.dart`.

Fixtures use synthetic data and strict HTTP transports. They do not establish real
GPS/permission behavior on a handset or authorize production address mutations.
See [current integration evidence](redesign/STATUS.md) for executed release checks.
