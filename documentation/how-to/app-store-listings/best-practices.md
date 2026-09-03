# App Store Optimization (ASO) Best Practices

To maximize organic downloads, both the App Store and Google Play require continuous optimization.

## Review Periodically

Store optimization is not a "set and forget" process. The following should be reviewed every 3-6 months:

1. **Keywords**: Are you ranking for the keywords you targeted? If not, swap them out for less competitive long-tail keywords.
2. **Competitor Updates**: Are competitors using new screenshot styles or targeting new features?
3. **Platform Guidelines**: Apple and Google frequently update their guidelines (e.g., Google's strict policies on icon/screenshot spam, Apple's evolving privacy rules).

## A/B Testing

Never guess what works best. Test it.

- **Google Play**: Use "Store Listing Experiments" to test icons, screenshots, short descriptions, and long descriptions. Test one variable at a time (e.g., just the icon).
- **Apple App Store**: Use "Product Page Optimization" to test up to 3 variants of your app icon, screenshots, or app previews.

## Custom Product Pages (Apple) / Custom Store Listings (Google)

If you are running specific marketing campaigns (e.g., a social media ad focusing on a specific feature), create a Custom Product Page.

- This gives you a unique URL to a store listing that highlights that specific feature in the screenshots and promotional text, rather than your generic main page. This drastically improves conversion rates for targeted ads.

## Reviews and Ratings

- Prompt users for a review natively in the app using the official `SKStoreReviewController` (iOS) and `ReviewManager` (Android) APIs.
- **Timing is critical**: Ask for a review immediately after the user has experienced a "win" or positive moment in the app.
- Reply to negative reviews constructively. On Google Play, developers who reply to reviews often see the user update their rating positively.
