// Encodes non-ASCII subject lines using RFC 1342 format (=?utf-8?B?...?=)
encodeRfc1342Subject = (subject: string): string => {
  subjectB64 = base64urlEncode({ text: subject })
  b64_1 = stringReplace({ haystack: subjectB64.encoded, needle: "-", replacement: "+", all: true })
  b64_2 = stringReplace({ haystack: b64_1.result, needle: "_", replacement: "/", all: true })
  rfcSubject = stringConcat({ parts: ["=?utf-8?B?", b64_2.result, "?="] })
  return rfcSubject.result
}

// Generates an RFC-compliant Base64url encoded MIME message
buildMimeMessage = (to: string, subject: string, htmlBody: string): string => {
  rfcSubject = encodeRfc1342Subject(subject)
  mimeText = stringConcat({ parts: [
    "To: ", to, "\n",
    "Subject: ", rfcSubject, "\n",
    "MIME-Version: 1.0\n",
    "Content-Type: text/html; charset=utf-8\n\n",
    htmlBody
  ] })
  encoded = base64urlEncode({ text: mimeText.result })
  return encoded.encoded
}

// Tool to send an email directly using Gmail API
sendGmailEmail = (googleToken: string, to: string, subject: string, htmlBody: string): { success: boolean, result: string, error: string } => {
  rawMime = buildMimeMessage(to, subject, htmlBody)
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { raw: rawMime } })
  res = httpRequest({ 
    host: "gmail.googleapis.com", 
    method: "POST", 
    path: "/gmail/v1/users/me/messages/send", 
    headers: { "Authorization": auth.result, "content-type": "application/json" }, 
    body: body.text 
  })
  isSuccess = res.status == 200 ? true : false
  errorBody = stringConcat({ parts: ["GMAIL_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

// Tool to create a draft in Gmail
createGmailDraft = (googleToken: string, to: string, subject: string, htmlBody: string): { success: boolean, result: string, error: string } => {
  rawMime = buildMimeMessage(to, subject, htmlBody)
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { message: { raw: rawMime } } })
  res = httpRequest({ 
    host: "gmail.googleapis.com", 
    method: "POST", 
    path: "/gmail/v1/users/me/drafts", 
    headers: { "Authorization": auth.result, "content-type": "application/json" }, 
    body: body.text 
  })
  isSuccess = res.status == 200 ? true : false
  errorBody = stringConcat({ parts: ["GMAIL_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}
