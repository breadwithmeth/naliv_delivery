/// Where the user wants to go. The redesigned home screen emits intent; the app layer maps it
/// onto routes.
///
/// This is deliberate: the not-yet-rebuilt screens all demand constructor arguments
/// (`businessId`, `userInfo`, chat `entryPoint`) that the home screen has no business knowing.
/// Keeping navigation here as data means the feature can be rendered and tested without the
/// rest of the app, and the eventual router has one place to change.
enum AppDestination {
  home,
  favorites,
  notifications,
  profile,
  orders,
  bonuses,
  certificates,
  addresses,
  cards,
  faq,
  support,
}
