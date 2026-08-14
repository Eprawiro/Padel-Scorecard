# FLPR Phase 5.6C — Mobile Header Hotfix

## Fix

- Uses a three-column mobile header grid for the community selector, centered
  logo, and menu button.
- Removes absolute positioning on phone widths so the controls cannot overlap.
- Scales the selector and logo responsively on very narrow screens.
- Keeps the community selector touch-friendly and uses ellipsis only when the
  available phone width is extremely small.
- Leaves the desktop header and all FLPR data behavior unchanged.

## Deployment

Upload `index.html` and `styles.css` to the GitHub repository root, wait for
Netlify, then reload the site on the phone.

This hotfix contains no SQL and performs no database writes.
