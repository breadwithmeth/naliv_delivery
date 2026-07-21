**Page Refinement Principles**

Refinement is not primarily about colors, shadows, or prettier cards. It is about making the page easier to understand and complete.

1. **Question every element**

For each element, ask:

- What information or action does it provide?
- Why is it on this page?
- Is it needed at this moment?
- Is its function obvious without explanatory text?
- Can it be combined with related information?

Example: delivery price does not need its own clickable row when it is calculated automatically. Show it beside the delivery address or time instead.

2. **Design around the user’s journey**

Arrange information in the order the user naturally thinks about it:

- Where or how?
- What am I getting?
- Are there optional choices?
- How was the total calculated?
- Confirm.

Example: `delivery method → address and time → order items → tips → calculation → confirmation`.

3. **Group by meaning, not by widget**

Related information should stay together, but a group does not automatically need a card or container.

Example: store, destination address, delivery time, and delivery cost form one route. They should read as one journey instead of four independent settings blocks.

4. **Avoid blocks inside blocks**

Do not give every row a background, border, icon container, and surrounding card. Use whitespace, alignment, typography, and subtle dividers first.

Cards should be reserved for elements that genuinely need containment, such as modals, repeated products, or important tools.

5. **Create clear visual priority**

Not everything should attract equal attention.

- Primary: the information required to complete the page.
- Secondary: supporting details.
- Optional: bonuses, promo codes, tips, FAQ, and advanced choices.

Example: the selected address should be visually stronger than the store name or delivery price.

6. **Combine competing optional actions**

Do not expose several controls that solve the same general task.

Example: bonuses, promo codes, and certificates become one `Скидка` action. The detailed controls appear only after opening it.

7. **Use progressive disclosure**

Show the essential state first. Reveal controls only when the user needs them.

Examples:

- Show three order items, then `Ещё 4`.
- Show the applied discount amount, not the entire promo form.
- Hide bonus controls when the balance is zero.
- Open address details only when they are missing or edited.

8. **Make states meaningful**

Every component must handle realistic edge cases:

- Missing or incomplete address.
- Free, loading, unavailable, or failed delivery price.
- Zero bonuses.
- Many products.
- Long product names.
- Products with several bottle types or packaging options.
- Pickup instead of delivery.
- Scheduled instead of immediate fulfillment.

Do not leave placeholder values that look like errors. For example, calculated zero-cost delivery should show `Бесплатно`, while an unknown price can show `—`.

9. **Treat different flows as different experiences**

Pickup should not feel like delivery with several rows removed.

Example: for pickup, emphasize `Забрать из`, the store address, and `Когда забрать`. Dialogs and validation must also use pickup wording.

10. **Be creative within familiar patterns**

A page can feel distinctive through composition, hierarchy, and interaction without inventing unfamiliar controls.

Good refinement means fewer decisions, fewer competing surfaces, and a clearer path. It should feel noticeably calmer while remaining immediately understandable to an ordinary user.