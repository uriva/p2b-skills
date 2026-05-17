import { shopifyOrderStatus, shopifyGetTracking, shopifyQueryCatalog, trackingAccumulator } from "../scripts/shopify.ss"

mockHttpRequest = (host: string, method: string, path: string): { status: number, body: string } => {
  isOrder = stringIncludes({ haystack: path, needle: "/orders/3491.json" }).result
  isOrderSearch = stringIncludes({ haystack: path, needle: "/orders.json?name=%233491" }).result
  isFulfillments = stringIncludes({ haystack: path, needle: "/fulfillments.json" }).result
  isProducts = stringIncludes({ haystack: path, needle: "/products.json" }).result

  result = isOrder
    ? { status: 200, body: "{\"order\":{\"id\":3491,\"financial_status\":\"paid\",\"fulfillment_status\":\"fulfilled\",\"created_at\":\"2024-01-01T00:00:00Z\",\"total_price\":\"99.99\"}}" }
    : isOrderSearch
    ? { status: 200, body: "{\"orders\":[{\"id\":3491,\"name\":\"#3491\"}]}" }
    : isFulfillments
    ? { status: 200, body: "{\"fulfillments\":[{\"tracking_number\":\"12345\",\"tracking_numbers\":[\"12345\"],\"tracking_company\":\"FedEx\",\"tracking_url\":\"https://fedex.com/track/12345\",\"tracking_urls\":[\"https://fedex.com/track/12345\"]}]}" }
    : isProducts
    ? { status: 200, body: "{\"products\":[{\"id\":1,\"title\":\"Cool Shoes\",\"handle\":\"cool-shoes\",\"variants\":[{\"price\":\"49.99\",\"inventory_management\":\"shopify\",\"inventory_policy\":\"deny\",\"inventory_quantity\":5}],\"body_html\":\"<p>Nice shoes</p>\",\"image\":{\"src\":\"https://cdn.shopify.com/shoes.jpg\"},\"images\":[{\"src\":\"https://cdn.shopify.com/shoes.jpg\"}],\"status\":\"active\",\"published_at\":\"2024-01-01T00:00:00Z\",\"tags\":\"footwear\",\"vendor\":\"ShoeCo\",\"product_type\":\"shoes\"}]}" }
    : { status: 404, body: "{\"error\":\"not found\"}" }

  return result
}

testOrderStatus = () => {
  f = override(shopifyOrderStatus, { httpRequest: mockHttpRequest })
  result = f({ shopifyStoreDomain: "test.myshopify.com", shopifyAccessToken: "token", orderId: "3491" })
  hasPaid = stringIncludes({ haystack: result, needle: "paid" }).result
  assert({ condition: hasPaid, message: "order status should contain financial_status paid" })
  return true
}

testGetTracking = () => {
  f = override(shopifyGetTracking, { httpRequest: mockHttpRequest })
  result = f({ shopifyStoreDomain: "test.myshopify.com", shopifyAccessToken: "token", orderNumber: "3491" })
  hasTracking = stringIncludes({ haystack: result, needle: "12345" }).result
  assert({ condition: hasTracking, message: "tracking should contain tracking number 12345" })
  return true
}

testQueryCatalog = () => {
  f = override(shopifyQueryCatalog, { httpRequest: mockHttpRequest })
  result = f({ shopifyStoreDomain: "test.myshopify.com", shopifyAccessToken: "token", query: ["shoes"], limit: 10, min_price: 0, max_price: 0, price: 0 })
  hasTitle = stringIncludes({ haystack: result, needle: "Cool Shoes" }).result
  assert({ condition: hasTitle, message: "catalog should contain product title Cool Shoes" })
  return true
}
