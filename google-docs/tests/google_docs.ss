import { extractOutlineFromDocJson, findSectionFromDocJson, buildInsertUnderHeadingPayload, normalizeBatchUpdateBody, buildInsertInlineImageRequest, readDocumentOutline, readDocumentSection, insertUnderHeading, insertInlineImage, batchUpdateDocument, executeBatchUpdate } from "../scripts/google-docs.ss"

sampleDocJson = (): string => {
  return jsonStringify({
    value: {
      documentId: "doc-sample-1",
      title: "Recommendations",
      body: {
        content: [
          { sectionBreak: { sectionStyle: {} }, startIndex: 0, endIndex: 1 },
          {
            startIndex: 1,
            endIndex: 16,
            paragraph: {
              paragraphStyle: { namedStyleType: "HEADING_1" },
              elements: [{ startIndex: 1, endIndex: 16, textRun: { content: "Seen and loved\n" } }]
            }
          },
          {
            startIndex: 16,
            endIndex: 23,
            paragraph: {
              paragraphStyle: { namedStyleType: "HEADING_2" },
              elements: [{ startIndex: 16, endIndex: 23, textRun: { content: "Series\n" } }]
            }
          },
          {
            startIndex: 23,
            endIndex: 30,
            paragraph: {
              paragraphStyle: { namedStyleType: "NORMAL_TEXT" },
              bullet: { listId: "list-1", nestingLevel: 0 },
              elements: [{ startIndex: 23, endIndex: 30, textRun: { content: "Sci-fi\n" } }]
            }
          },
          {
            startIndex: 30,
            endIndex: 42,
            paragraph: {
              paragraphStyle: { namedStyleType: "NORMAL_TEXT" },
              bullet: { listId: "list-1", nestingLevel: 1 },
              elements: [{ startIndex: 30, endIndex: 42, textRun: { content: "The Expanse\n" } }]
            }
          },
          {
            startIndex: 42,
            endIndex: 52,
            paragraph: {
              paragraphStyle: { namedStyleType: "NORMAL_TEXT" },
              bullet: { listId: "list-1", nestingLevel: 1 },
              elements: [{ startIndex: 42, endIndex: 52, textRun: { content: "Severance\n" } }]
            }
          },
          {
            startIndex: 52,
            endIndex: 59,
            paragraph: {
              paragraphStyle: { namedStyleType: "NORMAL_TEXT" },
              bullet: { listId: "list-1", nestingLevel: 0 },
              elements: [{ startIndex: 52, endIndex: 59, textRun: { content: "Comedy\n" } }]
            }
          },
          {
            startIndex: 59,
            endIndex: 66,
            paragraph: {
              paragraphStyle: { namedStyleType: "HEADING_2" },
              elements: [{ startIndex: 59, endIndex: 66, textRun: { content: "Movies\n" } }]
            }
          }
        ]
      }
    }
  }).text
}

mockDocsHttp = (host: string, method: string, path: string, body: string = ""): { status: number, body: string } => {
  isBatch = stringIncludes({ haystack: path, needle: ":batchUpdate" }).result
  isCompactGet = stringIncludes({ haystack: path, needle: "fields=" }).result
  isValidBatch = stringStartsWith({ text: stringTrim({ text: body }).result, prefix: "{\"requests\":" })
  return isBatch
    ? (isValidBatch ? { status: 200, body: body } : { status: 400, body: "{\"error\":{\"code\":400,\"message\":\"Root element must be a message.\"}}" })
    : (isCompactGet ? { status: 200, body: sampleDocJson() } : { status: 404, body: "{\"error\":\"not found\"}" })
}

extractsCompactOutlineWithIndicesAndBullets = () => {
  outline = extractOutlineFromDocJson({ docJson: sampleDocJson() })
  assert({ condition: outline.documentId == "doc-sample-1", message: "expected documentId" })
  assert({ condition: outline.title == "Recommendations", message: "expected title" })
  assert({ condition: outline.itemCount == 7, message: "expected 7 non-empty outline items" })
  assert({ condition: outline.items[0].text == "Seen and loved", message: "expected first heading text" })
  assert({ condition: outline.items[0].style == "HEADING_1", message: "expected HEADING_1 style" })
  assert({ condition: outline.items[2].isBullet == true, message: "expected Sci-fi to be bullet" })
  assert({ condition: outline.items[2].nestingLevel == 0, message: "expected Sci-fi nesting 0" })
  assert({ condition: outline.items[3].nestingLevel == 1, message: "expected The Expanse nesting 1" })
  assert({ condition: outline.items[4].endIndex == 52, message: "expected Severance endIndex 52" })
  return true
}

findsNestedBulletSectionAndIndices = () => {
  section = findSectionFromDocJson({ docJson: sampleDocJson(), headingQuery: "sci-fi" })
  assert({ condition: section.found == true, message: "expected to find Sci-fi section" })
  assert({ condition: section.items.length == 3, message: "expected Sci-fi + 2 nested bullets only (stopping before Comedy)" })
  assert({ condition: section.insertAfterHeadingIndex == 30, message: "expected insertAfterHeadingIndex 30" })
  assert({ condition: section.appendAtSectionEndIndex == 52, message: "expected appendAtSectionEndIndex 52" })
  return true
}

findsHeadingSectionStoppingAtSiblingHeading = () => {
  section = findSectionFromDocJson({ docJson: sampleDocJson(), headingQuery: "Series" })
  assert({ condition: section.found == true, message: "expected to find Series section" })
  assert({ condition: section.items.length == 5, message: "expected Series + 4 bullets (stopping before Movies HEADING_2)" })
  assert({ condition: section.appendAtSectionEndIndex == 59, message: "expected Series section endIndex 59" })
  return true
}

buildsInsertUnderBulletSectionAppendingAtBottom = () => {
  plan = buildInsertUnderHeadingPayload({ docJson: sampleDocJson(), headingQuery: "Sci-fi", text: "Andor", asBullet: true, position: "bottom" })
  assert({ condition: plan.success == true, message: "expected plan success" })
  assert({ condition: plan.targetIndex == 51, message: "expected targetIndex 51 (before Severance trailing newline)" })
  assert({ condition: stringIncludes({ haystack: plan.requestsBody, needle: "\"requests\"" }).result, message: "expected requests wrapper" })
  assert({ condition: stringIncludes({ haystack: plan.requestsBody, needle: "\\nAndor" }).result, message: "expected newline-prefixed bullet text" })
  return true
}

buildsInsertUnderEmptyHeadingWithBullets = () => {
  plan = buildInsertUnderHeadingPayload({ docJson: sampleDocJson(), headingQuery: "Movies", text: "Arrival", asBullet: true, position: "bottom" })
  assert({ condition: plan.success == true, message: "expected Movies plan success" })
  assert({ condition: plan.targetIndex == 66, message: "expected targetIndex 66 after Movies heading" })
  assert({ condition: stringIncludes({ haystack: plan.requestsBody, needle: "createParagraphBullets" }).result, message: "expected createParagraphBullets for non-bullet anchor" })
  return true
}

returnsClearErrorWhenHeadingMissing = () => {
  plan = buildInsertUnderHeadingPayload({ docJson: sampleDocJson(), headingQuery: "Nonexistent Section", text: "Andor", asBullet: true, position: "bottom" })
  assert({ condition: plan.success == false, message: "expected missing heading failure" })
  assert({ condition: stringIncludes({ haystack: plan.error, needle: "HEADING_NOT_FOUND" }).result, message: "expected HEADING_NOT_FOUND error" })
  return true
}

normalizesBareArrayInExecuteBatchUpdate = () => {
  wrapped = normalizeBatchUpdateBody({ requestsBody: "  [{\"insertText\":{\"location\":{\"index\":1},\"text\":\"Hi\"}}]  " })
  assert({ condition: wrapped == "{\"requests\":[{\"insertText\":{\"location\":{\"index\":1},\"text\":\"Hi\"}}]}", message: "expected bare array wrapped in requests object" })
  alreadyWrapped = normalizeBatchUpdateBody({ requestsBody: "{\"requests\":[{\"insertText\":{\"location\":{\"index\":1},\"text\":\"Hi\"}}]}" })
  assert({ condition: alreadyWrapped == "{\"requests\":[{\"insertText\":{\"location\":{\"index\":1},\"text\":\"Hi\"}}]}", message: "expected wrapped payload preserved" })
  return true
}

buildsInlineImageRequestWithOptionalSize = () => {
  sized = jsonStringify({ value: buildInsertInlineImageRequest({ index: 42, imageUrl: "https://example.com/poster.png", widthPt: 180, heightPt: 270 }) }).text
  assert({ condition: stringIncludes({ haystack: sized, needle: "\"insertInlineImage\"" }).result, message: "expected insertInlineImage op" })
  assert({ condition: stringIncludes({ haystack: sized, needle: "\"magnitude\":180" }).result, message: "expected widthPt 180" })
  assert({ condition: stringIncludes({ haystack: sized, needle: "\"magnitude\":270" }).result, message: "expected heightPt 270" })
  unsized = jsonStringify({ value: buildInsertInlineImageRequest({ index: 42, imageUrl: "https://example.com/poster.png", widthPt: 0, heightPt: 0 }) }).text
  assert({ condition: stringIncludes({ haystack: unsized, needle: "objectSize" }).result == false, message: "expected no objectSize when dimensions are 0" })
  return true
}

testReadDocumentOutlineEndToEnd = () => {
  f = override(readDocumentOutline, { httpRequest: mockDocsHttp })
  res = f({ googleToken: "tok", documentId: "doc-sample-1" })
  assert({ condition: res.success == true, message: "expected readDocumentOutline success" })
  assert({ condition: stringIncludes({ haystack: res.result, needle: "Seen and loved" }).result, message: "expected outline heading" })
  return true
}

testReadDocumentSectionEndToEnd = () => {
  f = override(readDocumentSection, { httpRequest: mockDocsHttp })
  res = f({ googleToken: "tok", documentId: "doc-sample-1", headingQuery: "Sci-fi" })
  assert({ condition: res.success == true, message: "expected readDocumentSection success" })
  assert({ condition: stringIncludes({ haystack: res.result, needle: "Severance" }).result, message: "expected Severance in section" })
  assert({ condition: stringIncludes({ haystack: res.result, needle: "Comedy" }).result == false, message: "expected Comedy excluded from Sci-fi section" })
  return true
}

testInsertUnderHeadingEndToEnd = () => {
  f = override(insertUnderHeading, { httpRequest: mockDocsHttp })
  res = f({ googleToken: "tok", documentId: "doc-sample-1", headingQuery: "Sci-fi", text: "Andor", asBullet: true, position: "bottom" })
  assert({ condition: res.success == true, message: "expected insertUnderHeading success" })
  assert({ condition: stringIncludes({ haystack: res.result, needle: "Andor" }).result, message: "expected batchUpdate payload to contain Andor" })
  return true
}

testExecuteBatchUpdateWrapsBareArray = () => {
  f = override(executeBatchUpdate, { httpRequest: mockDocsHttp })
  res = f({ googleToken: "tok", documentId: "doc-sample-1", requestsBody: "[{\"insertText\":{\"location\":{\"index\":1},\"text\":\"Hello\"}}]" })
  assert({ condition: res.success == true, message: "expected executeBatchUpdate to auto-wrap bare array" })
  return true
}

testBatchUpdateDocumentAndInsertInlineImage = () => {
  fb = override(batchUpdateDocument, { httpRequest: mockDocsHttp })
  resB = fb({ googleToken: "tok", documentId: "doc-sample-1", requests: [{ insertText: { location: { index: 1 }, text: "Hi\n" } }] })
  assert({ condition: resB.success == true, message: "expected batchUpdateDocument success" })
  fi = override(insertInlineImage, { httpRequest: mockDocsHttp })
  resI = fi({ googleToken: "tok", documentId: "doc-sample-1", index: 10, imageUrl: "https://example.com/banner.png", widthPt: 200, heightPt: 100 })
  assert({ condition: resI.success == true, message: "expected insertInlineImage success" })
  assert({ condition: stringIncludes({ haystack: resI.result, needle: "insertInlineImage" }).result, message: "expected insertInlineImage payload" })
  return true
}
