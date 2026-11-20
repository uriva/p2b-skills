headingRank = (style: string): number => {
  return style == "TITLE" ? 0 : (style == "HEADING_1" ? 1 : (style == "HEADING_2" ? 2 : (style == "HEADING_3" ? 3 : (style == "HEADING_4" ? 4 : (style == "HEADING_5" ? 5 : (style == "HEADING_6" ? 6 : 99))))))
}

paragraphTextReducer = (acc: string, el: { textRun: { content: string } }): string => {
  hasText = el.textRun ? (el.textRun.content ? true : false) : false
  return hasText ? stringConcat({ parts: [acc, el.textRun.content] }).result : acc
}

outlineContentReducer = (acc: { items: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }[] }, block: { startIndex: number, endIndex: number, paragraph: { elements: { textRun: { content: string } }[], paragraphStyle: { namedStyleType: string }, bullet: { listId: string, nestingLevel: number } } }): { items: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }[] } => {
  hasParagraph = block.paragraph ? true : false
  elements = hasParagraph ? (block.paragraph.elements ? block.paragraph.elements : []) : []
  rawText = hasParagraph ? reduce(paragraphTextReducer, "", elements) : ""
  trimmed = stringTrim({ text: rawText }).result
  keep = hasParagraph ? (trimmed != "") : false
  style = hasParagraph ? (block.paragraph.paragraphStyle ? (block.paragraph.paragraphStyle.namedStyleType ? block.paragraph.paragraphStyle.namedStyleType : "NORMAL_TEXT") : "NORMAL_TEXT") : "NORMAL_TEXT"
  hasBullet = hasParagraph ? (block.paragraph.bullet ? true : false) : false
  nestingLevel = hasBullet ? (block.paragraph.bullet.nestingLevel ? block.paragraph.bullet.nestingLevel : 0) : -1
  listId = hasBullet ? (block.paragraph.bullet.listId ? block.paragraph.bullet.listId : "") : ""
  startIndex = block.startIndex ? block.startIndex : 0
  endIndex = block.endIndex ? block.endIndex : 0
  entry = { text: trimmed, style: style, isBullet: hasBullet, nestingLevel: nestingLevel, listId: listId, startIndex: startIndex, endIndex: endIndex }
  nextItems = keep ? arrayAppend({ array: acc.items, element: entry }).array : acc.items
  return { items: nextItems }
}

extractOutlineFromDocJson = (docJson: string): { documentId: string, title: string, itemCount: number, items: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }[] } => {
  parsed = jsonParse({ text: docJson })
  docObj = parsed.value
  docId = docObj.documentId ? docObj.documentId : ""
  title = docObj.title ? docObj.title : ""
  content = docObj.body ? (docObj.body.content ? docObj.body.content : []) : []
  reduced = reduce(outlineContentReducer, { items: [] }, content)
  return { documentId: docId, title: title, itemCount: reduced.items.length, items: reduced.items }
}

sectionSearchReducer = (acc: { queryLower: string, found: boolean, stopped: boolean, matchIsBullet: boolean, matchRank: number, matchNesting: number, matchedItem: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }, items: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }[] }, item: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }): { queryLower: string, found: boolean, stopped: boolean, matchIsBullet: boolean, matchRank: number, matchNesting: number, matchedItem: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }, items: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }[] } => {
  itemLower = stringLower({ text: item.text }).result
  isMatch = acc.found ? false : stringIncludes({ haystack: itemLower, needle: acc.queryLower }).result
  itemRank = headingRank(item.style)

  shouldStopForHeading = acc.matchRank < 99 ? (itemRank <= acc.matchRank) : false
  shouldStopForBullet = acc.matchRank >= 99 ? (acc.matchIsBullet ? (item.isBullet ? (item.nestingLevel <= acc.matchNesting) : true) : true) : false
  shouldStopNow = acc.found ? (acc.stopped ? true : (shouldStopForHeading ? true : shouldStopForBullet)) : false

  nextFound = acc.found ? true : isMatch
  nextStopped = acc.found ? shouldStopNow : false
  nextMatchIsBullet = isMatch ? item.isBullet : acc.matchIsBullet
  nextMatchRank = isMatch ? itemRank : acc.matchRank
  nextMatchNesting = isMatch ? item.nestingLevel : acc.matchNesting
  nextMatchedItem = isMatch ? item : acc.matchedItem
  shouldAppend = isMatch ? true : (acc.found ? (shouldStopNow ? false : true) : false)
  nextItems = shouldAppend ? arrayAppend({ array: acc.items, element: item }).array : acc.items

  return { queryLower: acc.queryLower, found: nextFound, stopped: nextStopped, matchIsBullet: nextMatchIsBullet, matchRank: nextMatchRank, matchNesting: nextMatchNesting, matchedItem: nextMatchedItem, items: nextItems }
}

findSectionFromDocJson = (docJson: string, headingQuery: string): { found: boolean, documentId: string, title: string, matchedItem: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }, insertAfterHeadingIndex: number, appendAtSectionEndIndex: number, items: { text: string, style: string, isBullet: boolean, nestingLevel: number, listId: string, startIndex: number, endIndex: number }[] } => {
  outline = extractOutlineFromDocJson(docJson)
  emptyItem = { text: "", style: "NORMAL_TEXT", isBullet: false, nestingLevel: -1, listId: "", startIndex: 0, endIndex: 0 }
  initAcc = { queryLower: stringLower({ text: stringTrim({ text: headingQuery }).result }).result, found: false, stopped: false, matchIsBullet: false, matchRank: 99, matchNesting: -1, matchedItem: emptyItem, items: [] }
  searched = reduce(sectionSearchReducer, initAcc, outline.items)
  lastIdx = searched.items.length > 0 ? searched.items.length - 1 : 0
  lastItem = searched.items.length > 0 ? searched.items[lastIdx] : emptyItem
  return { found: searched.found, documentId: outline.documentId, title: outline.title, matchedItem: searched.matchedItem, insertAfterHeadingIndex: searched.found ? searched.matchedItem.endIndex : 0, appendAtSectionEndIndex: searched.found ? lastItem.endIndex : 0, items: searched.items }
}

normalizeBatchUpdateBody = (requestsBody: string): string => {
  trimmed = stringTrim({ text: requestsBody }).result
  isBareArray = stringStartsWith({ text: trimmed, prefix: "[" })
  return isBareArray ? stringConcat({ parts: ["{\"requests\":", trimmed, "}"] }).result : trimmed
}

buildInsertUnderHeadingPayload = (docJson: string, headingQuery: string, text: string, asBullet: boolean, position: string): { success: boolean, targetIndex: number, requestsBody: string, error: string } => {
  section = findSectionFromDocJson(docJson, headingQuery)
  lastIdx = section.items.length > 0 ? section.items.length - 1 : 0
  anchor = position == "top" ? section.matchedItem : (section.items.length > 0 ? section.items[lastIdx] : section.matchedItem)
  inheritBullet = asBullet ? anchor.isBullet : false
  targetIndex = inheritBullet ? (anchor.endIndex > 1 ? anchor.endIndex - 1 : 1) : anchor.endIndex
  insertTextValue = inheritBullet ? stringConcat({ parts: ["\n", text] }).result : stringConcat({ parts: [text, "\n"] }).result
  textLen = text.length
  requests = inheritBullet ? [{ insertText: { location: { index: targetIndex }, text: insertTextValue } }] : (asBullet ? [{ insertText: { location: { index: targetIndex }, text: insertTextValue } }, { createParagraphBullets: { range: { startIndex: targetIndex, endIndex: targetIndex + textLen }, bulletPreset: "BULLET_DISC_CIRCLE_SQUARE" } }] : [{ insertText: { location: { index: targetIndex }, text: insertTextValue } }])
  body = jsonStringify({ value: { requests: requests } }).text
  notFoundErr = stringConcat({ parts: ["HEADING_NOT_FOUND: No heading or list item matching '", headingQuery, "' in document."] }).result
  return section.found ? { success: true, targetIndex: targetIndex, requestsBody: body, error: "" } : { success: false, targetIndex: 0, requestsBody: "", error: notFoundErr }
}

buildInsertInlineImageRequest = (index: number, imageUrl: string, widthPt: number, heightPt: number): {} => {
  hasBoth = widthPt > 0 ? (heightPt > 0) : false
  hasWidth = widthPt > 0
  hasHeight = heightPt > 0
  return hasBoth ? { insertInlineImage: { location: { index: index }, uri: imageUrl, objectSize: { width: { magnitude: widthPt, unit: "PT" }, height: { magnitude: heightPt, unit: "PT" } } } } : (hasWidth ? { insertInlineImage: { location: { index: index }, uri: imageUrl, objectSize: { width: { magnitude: widthPt, unit: "PT" } } } } : (hasHeight ? { insertInlineImage: { location: { index: index }, uri: imageUrl, objectSize: { height: { magnitude: heightPt, unit: "PT" } } } } : { insertInlineImage: { location: { index: index }, uri: imageUrl } }))
}

fetchCompactDocumentJson = (googleToken: string, documentId: string): { success: boolean, result: string, error: string } => {
  fields = "documentId,title,body.content(startIndex,endIndex,paragraph(elements(startIndex,endIndex,textRun/content),paragraphStyle/namedStyleType,bullet(listId,nestingLevel)))"
  encodedFields = urlEncode({ text: fields })
  path = stringConcat({ parts: ["/v1/documents/", documentId, "?fields=", encodedFields.encoded] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = httpRequest({ host: "docs.googleapis.com", method: "GET", path: path.result, headers: { "Authorization": auth.result } })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_DOCS_API_ERROR: Received non-JSON response. Check token secret name and Docs scopes." : stringConcat({ parts: ["GOOGLE_DOCS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

doc({ text: "### Read Document Outline (Recommended)\n\nFetches a compact outline of a Google Doc (headings, paragraphs, bullet items, nesting levels, and UTF-16 `startIndex`/`endIndex`) without transferring hundreds of kilobytes of raw formatting metadata. Use this instead of `fetchDocument` for reading or locating edit positions." })

readDocumentOutline = (googleToken: string, documentId: string): { success: boolean, result: string, error: string } => {
  fetched = fetchCompactDocumentJson(googleToken, documentId)
  outline = fetched.success ? extractOutlineFromDocJson(fetched.result) : { documentId: "", title: "", itemCount: 0, items: [] }
  serialized = fetched.success ? jsonStringify({ value: outline }).text : ""
  return fetched.success ? { success: true, result: serialized, error: "" } : { success: false, result: "", error: fetched.error }
}

doc({ text: "### Read Document Section\n\nFinds a heading or bullet section matching `headingQuery` (case-insensitive substring) and returns only the items in that section along with `insertAfterHeadingIndex` and `appendAtSectionEndIndex`." })

readDocumentSection = (googleToken: string, documentId: string, headingQuery: string): { success: boolean, result: string, error: string } => {
  fetched = fetchCompactDocumentJson(googleToken, documentId)
  section = fetched.success ? findSectionFromDocJson(fetched.result, headingQuery) : { found: false, documentId: "", title: "", matchedItem: { text: "", style: "NORMAL_TEXT", isBullet: false, nestingLevel: -1, listId: "", startIndex: 0, endIndex: 0 }, insertAfterHeadingIndex: 0, appendAtSectionEndIndex: 0, items: [] }
  serialized = fetched.success ? jsonStringify({ value: section }).text : ""
  return fetched.success ? { success: true, result: serialized, error: "" } : { success: false, result: "", error: fetched.error }
}

doc({ text: "### Batch Update Document (Typed Array)\n\nExecutes a Google Docs `batchUpdate` with an array of request objects (e.g. `[{ insertText: { location: { index: 1 }, text: \"Hello\\n\" } }]`). Automatically wraps requests in `{ \"requests\": [...] }`." })

batchUpdateDocument = (googleToken: string, documentId: string, requests: {}[]): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v1/documents/", documentId, ":batchUpdate"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { requests: requests } })
  res = httpRequest({ host: "docs.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_DOCS_API_ERROR: Received non-JSON response. Check token secret name and Docs scopes." : stringConcat({ parts: ["GOOGLE_DOCS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

doc({ text: "### Insert Under Heading\n\nHigh-level helper to insert a new item or paragraph under a matching heading or bullet section without manually computing UTF-16 indices. Set `asBullet` to `true` (default) to insert/inherit a bullet item, and `position` to `\"bottom\"` (default, end of section) or `\"top\"` (right after the heading)." })

insertUnderHeading = (googleToken: string, documentId: string, headingQuery: string, text: string, asBullet: boolean = true, position: string = "bottom"): { success: boolean, result: string, error: string } => {
  fetched = fetchCompactDocumentJson(googleToken, documentId)
  plan = fetched.success ? buildInsertUnderHeadingPayload(fetched.result, headingQuery, text, asBullet, position) : { success: false, targetIndex: 0, requestsBody: "", error: fetched.error }
  path = stringConcat({ parts: ["/v1/documents/", documentId, ":batchUpdate"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = plan.success ? httpRequest({ host: "docs.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: plan.requestsBody }) : { status: 400, body: "" }
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = plan.success ? (res.status == 200) : false
  errorBody = plan.success ? (isHtml.result ? "GOOGLE_DOCS_API_ERROR: Received non-JSON response. Check token secret name and Docs scopes." : stringConcat({ parts: ["GOOGLE_DOCS_API_ERROR: ", res.body] }).result) : plan.error
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

doc({ text: "### Insert Inline Image\n\nInserts an inline image from a publicly accessible `imageUrl` at UTF-16 `index` in a Google Doc. Pass `widthPt` and/or `heightPt` (> 0) to set image dimensions in points, or `0` to use the image's default size." })

insertInlineImage = (googleToken: string, documentId: string, index: number, imageUrl: string, widthPt: number = 0, heightPt: number = 0): { success: boolean, result: string, error: string } => {
  reqObj = buildInsertInlineImageRequest(index, imageUrl, widthPt, heightPt)
  return batchUpdateDocument(googleToken, documentId, [reqObj])
}

doc({ text: "### Fetch Raw Document JSON\n\nReturns the full raw Google Docs API JSON AST. Prefer `readDocumentOutline` or `readDocumentSection` for normal reading and editing to avoid large context payloads." })

fetchDocument = (googleToken: string, documentId: string): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v1/documents/", documentId] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = httpRequest({ host: "docs.googleapis.com", method: "GET", path: path.result, headers: { "Authorization": auth.result } })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_DOCS_API_ERROR: Received non-JSON response. Check token secret name and Docs scopes." : stringConcat({ parts: ["GOOGLE_DOCS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

doc({ text: "### Create Document\n\nCreates a new empty Google Doc with the given `title` and returns the created document JSON (including `documentId`)." })

createDocument = (googleToken: string, title: string): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v1/documents"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { title: title } })
  res = httpRequest({ host: "docs.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_DOCS_API_ERROR: Received non-JSON response. Check token secret name and Docs scopes." : stringConcat({ parts: ["GOOGLE_DOCS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

doc({ text: "### Execute Raw Batch Update (JSON String)\n\nExecutes a Google Docs `batchUpdate` from a JSON string `requestsBody`. Accepts either `{\"requests\":[...]}` or a bare `[...]` array (automatically wrapped). Prefer `batchUpdateDocument` or `insertUnderHeading` for typed calls." })

executeBatchUpdate = (googleToken: string, documentId: string, requestsBody: string): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v1/documents/", documentId, ":batchUpdate"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  normalizedBody = normalizeBatchUpdateBody(requestsBody)
  res = httpRequest({ host: "docs.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: normalizedBody })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_DOCS_API_ERROR: Received non-JSON response. Check token secret name and Docs scopes." : stringConcat({ parts: ["GOOGLE_DOCS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}
