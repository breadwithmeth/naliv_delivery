# Address search API

The active client uses the existing `ApiService.baseUrl` API, not a local example
server. Current implementation: `lib/utils/api.dart`.

| Operation | Dart entry point | HTTP contract | Successful result |
|---|---|---|---|
| Text search | `searchAddressByText(query, {city, country})` | `GET /addresses/search?query=...` | Normalized maps from `data.features`, filtered to the requested country/city |
| Reverse lookup | `searchAddressByCoordinates(lat, lon)` | `GET /addresses/reverse?lat=...&lon=...` | `data` map or list normalized to a list of maps |

Both methods return `Future<List<Map<String, dynamic>>?>`. An empty successful list
means no matches; `null` reports a failed request/response. Text search builds the
query from the supplied city/country context. Reverse lookup checks coordinate
ranges before sending the request.

Both GETs send `Accept: application/json` without an unnecessary JSON Content-Type
header and time out after 10 seconds. Timeout/network/server failure does not trigger
an automatic retry. The active search/map UI retains manual selection and offers an
explicit retry. A late response does not take ownership from a newer selection.

Address-book persistence and canonical delivery labels are separate from HTTP
lookup. See [address selection and recovery](address_selection_system.md).
Retired typed/demo wrappers are not part of the current API; use the two existing
entry points above instead of reviving obsolete examples.

Verification is fixture-only for mutations. Do not send real address changes or
use a production account to test retries. Handset geolocation and deployed upstream
geocoder acceptance remain separate from host regression evidence.
