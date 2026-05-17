---
name: shopify
description: Interact with a Shopify store through the Shopify Admin REST API using a bot's SHOPIFY_ACCESS_TOKEN.
---

# Shopify Skill

Use this skill to check order status, get tracking information, and query the
product catalog for a Shopify store.

Pass the configured Shopify access token secret as `shopifyAccessToken` through
`secretMapping`. Usually this should be:

```json
{ "shopifyAccessToken": "SHOPIFY_ACCESS_TOKEN" }
```

The token must have access to the store's Admin API and must allow requests to
`myshopify.com`.

Also pass `shopifyStoreDomain` (e.g. `mystore.myshopify.com`) as a regular
parameter.

## Tools

- `shopifyOrderStatus`: get the financial and fulfillment status of an order by
  its internal Shopify order ID.
- `shopifyGetTracking`: get tracking numbers, carriers, and tracking URLs for
  an order by its order number (e.g. `1001`). The `#` prefix is added
  automatically.
- `shopifyQueryCatalog`: query the product catalog with optional free-text
  search and price filters. Returns up to 250 visible products matching the
  criteria. Filters are applied client-side after fetching a single page from
  Shopify.
