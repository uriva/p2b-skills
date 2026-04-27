import { patchTextForTest } from "../scripts/github.ss"

replaceSingleMatch = () => {
  patched = patchTextForTest({ content: "one two", searchText: "two", replaceText: "three", replaceAll: false })
  assert({ condition: patched.success, message: "expected single match patch to succeed" })
  assert({ condition: patched.result == "one three", message: "expected single match replacement" })
  assert({ condition: patched.count == 1, message: "expected one match" })
  return true
}

rejectsMissingSearchText = () => {
  patched = patchTextForTest({ content: "one two", searchText: "missing", replaceText: "three", replaceAll: false })
  assert({ condition: patched.success == false, message: "expected missing search text to fail" })
  assert({ condition: patched.error == "SEARCH_TEXT_NOT_FOUND", message: "expected missing search text error" })
  assert({ condition: patched.result == "one two", message: "expected original content on failure" })
  return true
}

rejectsAmbiguousSearchText = () => {
  patched = patchTextForTest({ content: "one two one", searchText: "one", replaceText: "three", replaceAll: false })
  assert({ condition: patched.success == false, message: "expected ambiguous search text to fail" })
  assert({ condition: patched.error == "SEARCH_TEXT_NOT_UNIQUE", message: "expected ambiguous search text error" })
  assert({ condition: patched.count == 2, message: "expected two matches" })
  return true
}

allowsReplaceAll = () => {
  patched = patchTextForTest({ content: "one two one", searchText: "one", replaceText: "three", replaceAll: true })
  assert({ condition: patched.success, message: "expected replaceAll patch to succeed" })
  assert({ condition: patched.result == "three two three", message: "expected all matches replaced" })
  assert({ condition: patched.count == 2, message: "expected two matches" })
  return true
}
