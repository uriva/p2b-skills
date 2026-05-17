doc({ text: "### Shopify Order Status\n\nGet the status of a Shopify order by order ID.\n\n#### Parameters\n- `shopifyStoreDomain` — Shopify store domain (e.g. `mystore.myshopify.com`)\n- `shopifyAccessToken` — Shopify Admin API access token\n- `orderId` — Shopify Order ID\n\n#### Example\n```\nparams: { shopifyStoreDomain: \"mystore.myshopify.com\", orderId: \"12345\" }\nsecretMapping: { shopifyAccessToken: \"SHOPIFY_ACCESS_TOKEN\" }\n```" })

shopifyOrderStatus = (shopifyStoreDomain: string, shopifyAccessToken: string, orderId: string): string => {
  path = stringConcat({ parts: ["/admin/api/2025-10/orders/", orderId, ".json"] })
  res = httpRequest({ host: "myshopify.com", subdomain: shopifyStoreDomain, method: "GET", path: path.result, headers: { "X-Shopify-Access-Token": shopifyAccessToken } })
  isOk = res.status == 200
  parsed = isOk ? jsonParse({ text: res.body }) : { value: { order: { id: "", financial_status: "", fulfillment_status: "", created_at: "", total_price: "" } } }
  order = parsed.value.order
  resultObj = { id: order.id, status: order.financial_status, fulfillment_status: order.fulfillment_status, created_at: order.created_at, total_price: order.total_price }
  resultStr = jsonStringify({ value: resultObj })
  errorStr = stringConcat({ parts: ["Error: ", res.body] })
  return isOk ? resultStr.text : errorStr.result
}

doc({ text: "### Shopify Get Tracking\n\nGet tracking number(s) and tracking information for a Shopify order by order number (e.g. #1001).\n\n#### Parameters\n- `shopifyStoreDomain` — Shopify store domain\n- `shopifyAccessToken` — Shopify Admin API access token\n- `orderNumber` — Shopify Order Number (not the internal ID)\n\n#### Example\n```\nparams: { shopifyStoreDomain: \"mystore.myshopify.com\", orderNumber: \"1001\" }\nsecretMapping: { shopifyAccessToken: \"SHOPIFY_ACCESS_TOKEN\" }\n```" })

trackingAccumulator = (acc: { items: { tracking_number: string, tracking_company: string, tracking_url: string }[] }, f: { tracking_number: string, tracking_numbers: string[], tracking_company: string, tracking_url: string, tracking_urls: string[] }): { items: { tracking_number: string, tracking_company: string, tracking_url: string }[] } => {
  numbers = f.tracking_numbers.length > 0 ? f.tracking_numbers : (f.tracking_number != "" ? [f.tracking_number] : [])
  urls = f.tracking_urls.length > 0 ? f.tracking_urls : (f.tracking_url != "" ? [f.tracking_url] : [])
  firstUrl = urls.length > 0 ? urls[0] : ""
  firstNumber = numbers.length > 0 ? numbers[0] : ""
  entry = { tracking_number: firstNumber, tracking_company: f.tracking_company, tracking_url: firstUrl }
  newItems = firstNumber != "" ? arrayAppend({ array: acc.items, element: entry }).array : acc.items
  return { items: newItems }
}

shopifyGetTracking = (shopifyStoreDomain: string, shopifyAccessToken: string, orderNumber: string): string => {
  normalized = stringConcat({ parts: ["#", orderNumber] })
  encodedName = urlEncode({ text: normalized.result })
  searchPath = stringConcat({ parts: ["/admin/api/2025-10/orders.json?name=", encodedName.encoded, "&status=any&limit=1"] })
  searchRes = httpRequest({ host: "myshopify.com", subdomain: shopifyStoreDomain, method: "GET", path: searchPath.result, headers: { "X-Shopify-Access-Token": shopifyAccessToken } })
  searchOk = searchRes.status == 200
  searchParsed = searchOk ? jsonParse({ text: searchRes.body }) : { value: { orders: [] } }
  orders = searchParsed.value.orders
  hasOrder = orders.length > 0
  order = hasOrder ? orders[0] : { id: "", name: "" }
  orderId = order.id
  orderName = order.name

  fulfillPath = stringConcat({ parts: ["/admin/api/2025-10/orders/", orderId, "/fulfillments.json"] })
  fulfillRes = hasOrder ? httpRequest({ host: "myshopify.com", subdomain: shopifyStoreDomain, method: "GET", path: fulfillPath.result, headers: { "X-Shopify-Access-Token": shopifyAccessToken } }) : { status: 404, body: "{\"fulfillments\":[]}" }
  fulfillOk = fulfillRes.status == 200
  fulfillParsed = fulfillOk ? jsonParse({ text: fulfillRes.body }) : { value: { fulfillments: [] } }
  fulfillments = fulfillParsed.value.fulfillments

  trackingResult = reduce(trackingAccumulator, { items: [] }, fulfillments)
  trackingInfo = trackingResult.items

  resultObj = hasOrder ? { order_number: orderName, tracking: trackingInfo } : { error: "Order not found" }
  resultStr = jsonStringify({ value: resultObj })
  errorStr = stringConcat({ parts: ["Error: ", searchRes.body] })
  return searchOk ? resultStr.text : errorStr.result
}

doc({ text: "### Shopify Query Catalog\n\nQuery the Shopify product catalog with optional free-text and price filters. Returns up to 250 visible products matching the criteria.\n\n#### Parameters\n- `shopifyStoreDomain` — Shopify store domain\n- `shopifyAccessToken` — Shopify Admin API access token\n- `query` — Array of search terms to match against title, tags, vendor, type, and description. Pass `[]` to match all.\n- `limit` — Max number of products to return\n- `min_price` — Minimum variant price (pass `0` to disable)\n- `max_price` — Maximum variant price (pass `0` to disable)\n- `price` — Exact variant price (pass `0` to disable)\n\n#### Example\n```\nparams: { shopifyStoreDomain: \"mystore.myshopify.com\", query: [\"shoes\"], limit: 10, min_price: 0, max_price: 0, price: 0 }\nsecretMapping: { shopifyAccessToken: \"SHOPIFY_ACCESS_TOKEN\" }\n```" })

termMatchAccumulator = (termAcc: { found: boolean, searchText: string }, term: string): { found: boolean, searchText: string } => {
  lowerTerm = stringLower({ text: term })
  found = stringIncludes({ haystack: termAcc.searchText, needle: lowerTerm.result }).result
  return { found: termAcc.found ? true : found, searchText: termAcc.searchText }
}

exactPriceAccumulator = (priceAcc: { found: boolean, target: number }, v: { price: string }): { found: boolean, target: number } => {
  parsedPrice = jsonParse({ text: v.price })
  found = parsedPrice.value == priceAcc.target
  return { found: priceAcc.found ? true : found, target: priceAcc.target }
}

minPriceAccumulator = (priceAcc: { found: boolean, target: number }, v: { price: string }): { found: boolean, target: number } => {
  parsedPrice = jsonParse({ text: v.price })
  found = parsedPrice.value >= priceAcc.target
  return { found: priceAcc.found ? true : found, target: priceAcc.target }
}

maxPriceAccumulator = (priceAcc: { found: boolean, target: number }, v: { price: string }): { found: boolean, target: number } => {
  parsedPrice = jsonParse({ text: v.price })
  found = parsedPrice.value <= priceAcc.target
  return { found: priceAcc.found ? true : found, target: priceAcc.target }
}

filterAccumulator = (acc: { items: { title: string, handle: string, variants: { price: string, inventory_management: string, inventory_policy: string, inventory_quantity: number }[], body_html: string, image: { src: string }, images: { src: string }[] }[], queryTerms: string[], exactPrice: number, minPrice: number, maxPrice: number }, p: { title: string, handle: string, variants: { price: string, inventory_management: string, inventory_policy: string, inventory_quantity: number }[], body_html: string, image: { src: string }, images: { src: string }[], status: string, published_at: string }): { items: { title: string, handle: string, variants: { price: string, inventory_management: string, inventory_policy: string, inventory_quantity: number }[], body_html: string, image: { src: string }, images: { src: string }[] }[], queryTerms: string[], exactPrice: number, minPrice: number, maxPrice: number } => {
  visible = p.status == "active" ? p.published_at != "" : false

  searchParts = [p.title, p.tags, p.vendor, p.product_type, p.body_html]
  searchJoined = stringConcat({ parts: searchParts })
  searchLower = stringLower({ text: searchJoined.result })

  termResult = reduce(termMatchAccumulator, { found: false, searchText: searchLower.result }, acc.queryTerms)
  queryMatch = acc.queryTerms.length == 0 ? true : termResult.found

  exactPriceResult = reduce(exactPriceAccumulator, { found: false, target: acc.exactPrice }, p.variants)
  exactMatch = acc.exactPrice == 0 ? true : exactPriceResult.found

  minPriceResult = reduce(minPriceAccumulator, { found: false, target: acc.minPrice }, p.variants)
  minMatch = acc.minPrice == 0 ? true : minPriceResult.found

  maxPriceResult = reduce(maxPriceAccumulator, { found: false, target: acc.maxPrice }, p.variants)
  maxMatch = acc.maxPrice == 0 ? true : maxPriceResult.found

  matches = visible ? (queryMatch ? (exactMatch ? (minMatch ? maxMatch : false) : false) : false) : false
  newItems = matches ? arrayAppend({ array: acc.items, element: p }).array : acc.items
  return { items: newItems, queryTerms: acc.queryTerms, exactPrice: acc.exactPrice, minPrice: acc.minPrice, maxPrice: acc.maxPrice }
}

priceMinAccumulator = (priceAcc: { min: number }, v: { price: string }): { min: number } => {
  parsedPrice = jsonParse({ text: v.price })
  priceVal = parsedPrice.value
  newMin = priceVal < priceAcc.min ? priceVal : priceAcc.min
  return { min: newMin }
}

priceMaxAccumulator = (priceAcc: { max: number }, v: { price: string }): { max: number } => {
  parsedPrice = jsonParse({ text: v.price })
  priceVal = parsedPrice.value
  newMax = priceVal > priceAcc.max ? priceVal : priceAcc.max
  return { max: newMax }
}

availAccumulator = (availAcc: { available: boolean }, v: { inventory_management: string, inventory_policy: string, inventory_quantity: number }): { available: boolean } => {
  notTracked = v.inventory_management == ""
  oversell = v.inventory_policy == "continue"
  inStock = notTracked ? true : (oversell ? true : v.inventory_quantity > 0)
  return { available: availAcc.available ? true : inStock }
}

imgAccumulator = (imgAcc: { items: string[] }, img: { src: string }): { items: string[] } => {
  newItems = img.src != "" ? arrayAppend({ array: imgAcc.items, element: img.src }).array : imgAcc.items
  return { items: newItems }
}

nonEmptyAccumulator = (neAcc: { items: string[] }, part: string): { items: string[] } => {
  newItems = part != "" ? arrayAppend({ array: neAcc.items, element: part }).array : neAcc.items
  return { items: newItems }
}

joinAccumulator = (acc: string, line: string): string => {
  return acc == "" ? line : stringConcat({ parts: [acc, "\n\n", line] }).result
}

formatAccumulator = (acc: { lines: string[], storeDomain: string }, p: { title: string, handle: string, variants: { price: string, inventory_management: string, inventory_policy: string, inventory_quantity: number }[], body_html: string, image: { src: string }, images: { src: string }[] }): { lines: string[], storeDomain: string } => {
  url = stringConcat({ parts: ["https://", acc.storeDomain, "/products/", p.handle] })

  hasVariants = p.variants.length > 0
  priceMinResult = hasVariants ? reduce(priceMinAccumulator, { min: 999999 }, p.variants) : { min: 0 }
  priceMaxResult = hasVariants ? reduce(priceMaxAccumulator, { max: 0 }, p.variants) : { max: 0 }
  minStr = jsonStringify({ value: priceMinResult.min })
  maxStr = jsonStringify({ value: priceMaxResult.max })
  samePrice = priceMinResult.min == priceMaxResult.max
  rangeStr = stringConcat({ parts: [minStr.text, "–", maxStr.text] })
  priceStr = hasVariants ? (samePrice ? minStr.text : rangeStr.result) : ""

  availResult = hasVariants ? reduce(availAccumulator, { available: false }, p.variants) : { available: true }
  oos = !availResult.available

  safeImage = p.image ? p.image : { src: "" }
  imgSrc = safeImage.src
  safeImages = p.images ? p.images : []
  imgResult = reduce(imgAccumulator, { items: imgSrc != "" ? [imgSrc] : [] }, safeImages)
  firstImage = imgResult.items.length > 0 ? imgResult.items[0] : ""
  imageLine = firstImage != "" ? stringConcat({ parts: ["  Image: ", firstImage] }).result : ""

  descLine = p.body_html != "" ? stringConcat({ parts: ["  Description: ", p.body_html] }).result : ""
  availLine = oos ? "  Availability: Out of stock" : ""
  priceLine = priceStr != "" ? stringConcat({ parts: ["  Price: ", priceStr] }).result : ""
  urlLine = p.handle != "" ? stringConcat({ parts: ["  ", url.result] }).result : ""
  titleLine = stringConcat({ parts: ["• ", p.title] }).result

  lineParts = [titleLine, urlLine, priceLine, availLine, imageLine, descLine]
  nonEmptyResult = reduce(nonEmptyAccumulator, { items: [] }, lineParts)
  joinedLine = stringConcat({ parts: nonEmptyResult.items })

  newLines = acc.lines.length == 0 ? [joinedLine.result] : arrayAppend({ array: acc.lines, element: joinedLine.result }).array
  return { lines: newLines, storeDomain: acc.storeDomain }
}

shopifyQueryCatalog = (shopifyStoreDomain: string, shopifyAccessToken: string, query: string[], limit: number, min_price: number, max_price: number, price: number): string => {
  limitParam = limit > 0 ? limit : 10
  cappedLimit = limitParam > 250 ? 250 : limitParam
  limitStr = jsonStringify({ value: cappedLimit })
  path = stringConcat({ parts: ["/admin/api/2025-10/products.json?limit=", limitStr.text] })
  res = httpRequest({ host: "myshopify.com", subdomain: shopifyStoreDomain, method: "GET", path: path.result, headers: { "X-Shopify-Access-Token": shopifyAccessToken } })
  isOk = res.status == 200
  parsed = isOk ? jsonParse({ text: res.body }) : { value: { products: [] } }
  allProducts = parsed.value.products

  filterResult = reduce(filterAccumulator, { items: [], queryTerms: query, exactPrice: price, minPrice: min_price, maxPrice: max_price }, allProducts)
  matchedProducts = filterResult.items

  formatResult = reduce(formatAccumulator, { lines: [], storeDomain: shopifyStoreDomain }, matchedProducts)
  outputLines = formatResult.lines

  output = outputLines.length > 0 ? reduce(joinAccumulator, "", outputLines) : "No matching products found."

  errorStr = stringConcat({ parts: ["Error: ", res.body] })
  return isOk ? output : errorStr.result
}
