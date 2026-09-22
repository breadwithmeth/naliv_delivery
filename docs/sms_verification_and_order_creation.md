# SMS Verification and Order Creation

This is the current client-side contract used by the Flutter app.

## Files

- `lib/pages/login_page.dart` - phone input, SMS code UI, cooldown, navigation after login.
- `lib/utils/api.dart` - auth, order, delivery, promo, certificate, and payment API calls.
- `lib/pages/checkout_page.dart` - validates checkout data and builds the order payload.
- `lib/models/cart_item.dart` - converts cart items to order items.
- `lib/pages/payment_method_page.dart` - pays an already-created order.

## Base URL

```text
https://njt25.naliv.kz/api
```

## SMS Verification

### Phone format

The login page normalizes user input before sending it:

- removes all non-digits;
- converts a leading `8` to `7`;
- prepends `7` if the number does not start with `7`;
- limits to 11 digits;
- sends the API value with `+`, for example `+77001234567`.

### Send code

```http
POST /auth/send-code
Content-Type: application/json
```

```json
{
  "phone_number": "+77001234567"
}
```

Expected success: HTTP `200` with `success: true`.

If the response is HTTP `429`, the app starts a resend cooldown. Cooldown seconds are read from `Retry-After`, then from the response message, then fall back to `60`.

### Verify code

```http
POST /auth/verify-code
Content-Type: application/json
```

```json
{
  "phone_number": "+77001234567",
  "onetime_code": "123456"
}
```

Expected success: HTTP `202` with `success: true`.

On success the app expects `data.token`, saves it to `SharedPreferences` as `auth_token`, decodes JWT `exp` into `token_expiry`, syncs the OneSignal token, and opens the authenticated app shell.

Auth-required API calls use:

```http
Authorization: Bearer <auth_token>
```

Expired tokens are removed from local storage.

## Order Creation

Order creation happens before payment.

### Preconditions

The checkout submit flow requires:

- logged-in user;
- selected business;
- cart items;
- for `DELIVERY`: selected address with `lat`, `lon`, `entrance`, `floor`, and `apartment`;
- for `PICKUP`: address fields are sent empty and coordinates are sent as `0.0`.

For delivery, the app calculates delivery data before checkout with:

```http
GET /delivery/calculate-by-address?business_id=<id>&lat=<lat>&lon=<lon>
```

### Cart item payload

Each cart item is converted to:

```json
{
  "item_id": 123,
  "amount": 2,
  "options": [
    {
      "option_item_relation_id": 456,
      "amount": 1
    }
  ]
}
```

`amount` includes free quantity from subtract promotions. If the business has a configured bag item and the cart does not already contain it, checkout adds one bag item automatically:

```json
{
  "item_id": 48044,
  "amount": 1,
  "options": []
}
```

### Create order

```http
POST /orders/create-order-no-payment
Content-Type: application/json
Accept: application/json
Authorization: Bearer <auth_token>
```

Required payload shape:

```json
{
  "business_id": 1,
  "street": "Street name",
  "house": "10",
  "lat": 43.238293,
  "lon": 76.945465,
  "apartment": "12",
  "entrance": "1",
  "floor": "3",
  "extra": "Comment",
  "items": [],
  "delivery_type": "DELIVERY",
  "delivery_time": "NOW",
  "total_amount": 5000,
  "courier_tips": 100,
  "use_bonuses": false,
  "saved_card_id": 1
}
```

Optional fields:

```json
{
  "bonus_amount": 300,
  "scheduled_time": "2026-09-07T18:30:00.000",
  "promo_code": "PROMO",
  "certificate_id": 10,
  "certificate_code": "CERTCODE",
  "certificate_amount": 1000
}
```

Notes:

- `delivery_type` is `DELIVERY` or `PICKUP`.
- `delivery_time` is `NOW` unless a scheduled time is selected.
- Bonuses cover at most 30% of the item total and do not cover delivery.
- Promo code and certificate are mutually exclusive in checkout.
- Total is calculated client-side from items, auto bag, discounts, bonuses/certificate, delivery, service fee, and courier tips.

Expected success: HTTP `201` with `success: true` and created order data in `data`.

On success the app clears the cart and opens `PaymentMethodPage` with the returned order data.

## Payment After Creation

The payment page reads the order id from `order_id`, `order_uuid`, or `id`.

Card payment:

```http
POST /orders/<orderId>/pay
Authorization: Bearer <auth_token>
```

```json
{
  "payment_type": "card",
  "card_id": "<selected_card_id>"
}
```

Kaspi payment:

```http
POST /orders/<orderId>/kaspi-qr/pay
Authorization: Bearer <auth_token>
```

```json
{
  "method": "link"
}
```

The app opens `data.paymentLink`, then polls:

```http
GET /orders/<orderId>/kaspi-qr/status
Authorization: Bearer <auth_token>
```

Polling uses `data.behaviorOptions.StatusPollingInterval` and `PaymentConfirmationTimeout` when present; otherwise it falls back to 5 seconds and 65 seconds.
